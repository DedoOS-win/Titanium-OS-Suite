# ============================================================
# TITANIUM V8 - FULL CONTROLLED SCRIPT (IoT 24H2 LTSC)
# ============================================================
Write-Host "=== TITANIUM V8 FULL CONTROLLED ENVIRONMENT ===" -ForegroundColor Cyan

# ------------------------------------------------------------
# 0. GATEKEEPER
# ------------------------------------------------------------
if ([Security.Principal.WindowsIdentity]::GetCurrent().Name -ne "NT AUTHORITY\SYSTEM") {
    Write-Host "ERRORE: Esegui come SYSTEM tramite PowerRun!" -ForegroundColor Red
    Pause; exit
}

# ------------------------------------------------------------
# FUNZIONE GLOBALE: Abilita privilegi token
# Necessaria per Blocco 4 e Blocco 10 (ACL su chiavi protette)
# ------------------------------------------------------------
function Enable-Privileges {
    $code = @'
using System;
using System.Runtime.InteropServices;
public class TokenPriv {
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
        ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
    [DllImport("advapi32.dll", ExactSpelling=true, SetLastError=true)]
    internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
    [DllImport("advapi32.dll", SetLastError=true)]
    internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    internal struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }
    internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
    internal const int TOKEN_QUERY          = 0x00000008;
    internal const int TOKEN_ADJUST_PRIVS   = 0x00000020;
    public static void Enable(string privilege) {
        IntPtr hproc = System.Diagnostics.Process.GetCurrentProcess().Handle;
        IntPtr htok  = IntPtr.Zero;
        OpenProcessToken(hproc, TOKEN_ADJUST_PRIVS | TOKEN_QUERY, ref htok);
        TokPriv1Luid tp = new TokPriv1Luid();
        tp.Count = 1; tp.Luid = 0; tp.Attr = SE_PRIVILEGE_ENABLED;
        LookupPrivilegeValue(null, privilege, ref tp.Luid);
        AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
'@
    Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
    [TokenPriv]::Enable("SeTakeOwnershipPrivilege")
    [TokenPriv]::Enable("SeRestorePrivilege")
    [TokenPriv]::Enable("SeBackupPrivilege")
}

# ------------------------------------------------------------
# FUNZIONE GLOBALE: Applica ACL Deny SetValue su chiave servizio
# Metodo diretto Microsoft.Win32.Registry (bypass Set-Acl)
# ------------------------------------------------------------
function Set-SvcDenyAcl {
    param([string]$SvcName)
    $regPath = "SYSTEM\CurrentControlSet\Services\$SvcName"
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $regPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions -bor
            [System.Security.AccessControl.RegistryRights]::ReadPermissions   -bor
            [System.Security.AccessControl.RegistryRights]::TakeOwnership
        )
        if ($null -eq $key) { Write-Host "   WARN: impossibile aprire $SvcName" -ForegroundColor Yellow; return }
        $acl       = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::All)
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")
        $acl.SetOwner($systemSid)
        $everyone  = New-Object System.Security.Principal.SecurityIdentifier("S-1-1-0")
        $denyRule  = New-Object System.Security.AccessControl.RegistryAccessRule(
            $everyone,
            [System.Security.AccessControl.RegistryRights]::SetValue,
            [System.Security.AccessControl.InheritanceFlags]::None,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Deny
        )
        $acl.SetAccessRule($denyRule)
        $key.SetAccessControl($acl)
        $key.Close()
        Write-Host "   ACL Deny applicato su $SvcName" -ForegroundColor Gray
    } catch {
        Write-Host "   WARN: $SvcName - $_" -ForegroundColor Yellow
    }
}

# Abilita privilegi subito (servono da Blocco 4 in poi)
Enable-Privileges

# ------------------------------------------------------------
# BLOCCO 1: GESTIONE LINGUE
# ------------------------------------------------------------
& {
    Write-Host "`n[MODULO] Gestione Lingue di Sistema..." -ForegroundColor Cyan

    Stop-Service -Name "W32Time"         -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "FontCache"       -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "LanmanWorkstation" -Force -ErrorAction SilentlyContinue

    $KeepLangs = @("it-IT","en-US","en-GB")
    Set-WinUserLanguageList -LanguageList $KeepLangs -Force
    Set-WinSystemLocale     -SystemLocale "it-IT"
    Set-WinUILanguageOverride -Language   "it-IT"

    Start-Service -Name "W32Time"          -ErrorAction SilentlyContinue
    Start-Service -Name "FontCache"        -ErrorAction SilentlyContinue
    Start-Service -Name "LanmanWorkstation" -ErrorAction SilentlyContinue

    Write-Host "-> Modulo Lingue Completato." -ForegroundColor Green
}

# ------------------------------------------------------------
# BLOCCO 2: ADAPTIVE MEMORY ENGINE & KERNEL TIMER OPTIMIZER
# ------------------------------------------------------------
& {
    Write-Host "`n[MODULO] Hardware Adaptive Memory & Timer Engine..." -ForegroundColor Cyan

    # 1. RILEVAMENTO HARDWARE PROFONDO
    $CS_Obj       = Get-CimInstance Win32_ComputerSystem | Select-Object -First 1
    $Proc_Obj     = Get-CimInstance Win32_Processor | Select-Object -First 1
    $RAM_Data     = Get-CimInstance Win32_PhysicalMemory
    
    $TotalRAM_MB  = [math]::Round($CS_Obj.TotalPhysicalMemory / 1MB)
    $RAM_GB       = [math]::Round($TotalRAM_MB / 1024)
    $CpuCores     = $Proc_Obj.NumberOfCores
    $RAMSpeed     = if ($RAM_Data) { ($RAM_Data | Measure-Object -Property Speed -Maximum).Maximum } else { 2400 }

    Write-Host "   Hardware: $CpuCores Core Fisici | $RAM_GB GB RAM @ $RAMSpeed MHz" -ForegroundColor Gray

    # 2. OTTIMIZZAZIONE TIMER (HPET & TICK)
    # Strategia sicura per bare metal con VirtualBox/Supremo/USB audio
    Write-Host "   Ottimizzazione Timer di Sistema (Low Latency)..." -ForegroundColor Gray

    # Rileva se Hyper-V è attivo (VirtualBox non coesiste con Hyper-V)
    $HyperVActive = $false
    try {
        $hvStatus = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue).State
        if ($hvStatus -eq "Enabled") { $HyperVActive = $true }
    } catch { $HyperVActive = $false }

    # Rileva dispositivi audio USB - sensibili ai timer
    $UsbAudioPresent = $false
    try {
        $usbAudio = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
            $_.Class -eq "Media" -and $_.InstanceId -match "USB"
        }
        if ($usbAudio) { $UsbAudioPresent = $true }
    } catch { $UsbAudioPresent = $false }

    # Rileva CPU generation per TSC invariante
    $CpuName = $Proc_Obj.Name
    $TscInvariant = $CpuName -match "i[3579]-[0-9]{4,}|Ryzen|Xeon|Core.Ultra|i[3579]-1[0-9]{4}"

    if ($HyperVActive) {
        # Hyper-V attivo: NON toccare useplatformclock - VirtualBox ne dipende
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformclock 2>$null
        & bcdedit.exe /deletevalue useplatformtick  2>$null
        Write-Host "   Timer: Hyper-V rilevato - modalita' sicura per VirtualBox." -ForegroundColor Yellow
    } elseif ($UsbAudioPresent) {
        # Audio USB presente (soundbar, DAC, interfacce): NON disabilitare dynamic tick
        # disabledynamictick altera gli interrupt USB audio causando distorsione
        & bcdedit.exe /set useplatformclock no   2>$null
        & bcdedit.exe /deletevalue disabledynamictick 2>$null  # Ripristina default
        & bcdedit.exe /deletevalue useplatformtick    2>$null
        Write-Host "   Timer: Audio USB rilevato - dynamic tick preservato per stabilita' audio." -ForegroundColor Yellow
        if ($usbAudio) { Write-Host ("   Dispositivo protetto: {0}" -f $usbAudio.FriendlyName) -ForegroundColor Gray }
    } elseif ($TscInvariant) {
        # CPU moderna, no USB audio, no Hyper-V: ottimizzazione completa
        & bcdedit.exe /set useplatformclock  no  2>$null
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformtick   2>$null
        Write-Host "   Timer: TSC invariante - HPET disabilitato, latenza minima." -ForegroundColor Gray
    } else {
        # CPU vecchia o non riconosciuta: configurazione conservativa
        & bcdedit.exe /set useplatformclock  yes 2>$null
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformtick   2>$null
        Write-Host "   Timer: CPU legacy - HPET preservato per stabilita'." -ForegroundColor Yellow
    }
    Write-Host ("   CPU: {0} | Hyper-V: {1} | TSC: {2} | USB Audio: {3}" -f $CpuName, $HyperVActive, $TscInvariant, $UsbAudioPresent) -ForegroundColor Gray

    # NOTA: GlobalTimerResolutionRequests rimosso - causa distorsione su audio USB/jack
    # Ripristina se presente da versioni precedenti dello script
    $KernelTimerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
    Remove-ItemProperty -Path $KernelTimerPath -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue

    # Ripristina driver audio USB generici se rimossi accidentalmente
    & pnputil.exe /add-driver "$env:SystemRoot\INF\wdmaudio.inf" /install /force 2>$null | Out-Null
    & pnputil.exe /add-driver "$env:SystemRoot\INF\usbaudio.inf"  /install /force 2>$null | Out-Null
    Write-Host "   Driver audio USB generici: verificati e ripristinati." -ForegroundColor Gray

    Stop-Service -Name "SysMain","WSearch","Spooler" -Force -ErrorAction SilentlyContinue

    # 3. LOGICA PAGEFILE ADATTIVO
    if ($RAM_GB -le 4) {
        $MinP = 2048; $MaxP = 4096; $Profile = "LOW RAM"
    } elseif ($RAM_GB -le 8) {
        $MinP = 2048; $MaxP = 8192; $Profile = "MEDIUM RAM"
    } elseif ($RAM_GB -ge 16 -and $RAMSpeed -ge 3000) {
        $MinP = 1024; $MaxP = 16384; $Profile = "HIGH-END"
    } else {
        $MinP = 1024; $MaxP = 8192; $Profile = "BALANCED"
    }

    $RegMM = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $RegMM -Name "PagingFiles" -Value "C:\pagefile.sys $MinP $MaxP" -Force

    # 4. LOGICA SVCHOST SPLIT - tabella granulare per RAM
    $thresholdMap = @{
        4  = 400000
        6  = 600000
        8  = 800000
        12 = 1200000
        16 = 1600000
        24 = 2400000
        32 = 3200000
        64 = 6400000
    }
    $availableKeys = $thresholdMap.Keys | Where-Object { $_ -le $RAM_GB } | Sort-Object -Descending
    if ($availableKeys.Count -gt 0) {
        $svcValue = $thresholdMap[$availableKeys[0]]
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $svcValue -Force
        Write-Host "   SvcHostSplitThreshold: $svcValue KB (RAM: $RAM_GB GB)." -ForegroundColor Gray
    } else {
        Write-Host "   WARN: RAM non mappata ($RAM_GB GB), SvcHostSplitThreshold non modificato." -ForegroundColor Yellow
    }

    # 5. COMPRESSIONE MEMORIA (MMAgent)
    if (Get-Command Disable-MMAgent -ErrorAction SilentlyContinue) {
        if ($RAM_GB -ge 16 -or $CpuCores -le 4) {
            Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            $CompStatus = "OFF"
        } else {
            Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            $CompStatus = "ON"
        }
    } else { $CompStatus = "N/D" }

    Start-Service -Name "SysMain","WSearch","Spooler" -ErrorAction SilentlyContinue

    Write-Host ("-> Profilo {0}: Timer Ottimizzati | SvcHost {1} {2} KB | Compressione {3}" -f $Profile, $(if($RAM_GB -ge 4){"Split"}else{"Unified"}), $svcValue, $CompStatus) -ForegroundColor Green
}

# ============================================================
# BLOCCO 3: CPU MITIGATIONS & VBS KILL
# ============================================================
& {
    Write-Host "`n[MODULO] Disabilitazione Mitigazioni CPU & VBS..." -ForegroundColor Red

    $MMPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $MMPath -Name "FeatureSettingsOverride"     -Value 3 -Force
    Set-ItemProperty -Path $MMPath -Name "FeatureSettingsOverrideMask" -Value 3 -Force

    $DGPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    if (!(Test-Path $DGPath)) { New-Item -Path $DGPath -Force | Out-Null }
    Set-ItemProperty -Path $DGPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DmaGuard" -Name "Enabled" -Value 0 -Force -ErrorAction SilentlyContinue

    Write-Host "-> CPU Mitigations & VBS Disabilitati." -ForegroundColor Green
}

# ============================================================
# BLOCCO 4: FTH & DPS - CHECK & HARD LOCK
# Corretto: usa Microsoft.Win32.Registry invece di Set-Acl
# ============================================================
& {
    Write-Host "`n[MODULO] Verificando stato FTH e DPS..." -ForegroundColor Cyan

    $FTH_Enabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\FTH" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
    $DPS_Start   = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dps" -Name "Start" -ErrorAction SilentlyContinue).Start

    if ($FTH_Enabled -eq 0 -and $DPS_Start -eq 4) {
        Write-Host "-> FTH e DPS gia' disabilitati. Procedo al Lock." -ForegroundColor Green
    } else {
        Write-Host "-> FTH o DPS attivi. Disabilitazione forzata..." -ForegroundColor Yellow
        Stop-Service -Name "dps" -Force -ErrorAction SilentlyContinue
        if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\FTH")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\FTH" -Force | Out-Null }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\FTH"                        -Name "Enabled" -Value 0 -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dps"         -Name "Start"   -Value 4 -Force
    }

    Write-Host "[SYS] Applicazione Hard Lock DPS..." -ForegroundColor Cyan
    Set-SvcDenyAcl -SvcName "dps"
    Write-Host "-> Hard Lock DPS applicato." -ForegroundColor Green
}

# ============================================================
# BLOCCO 5: NETWORK & DNS UNIFICATION
# ============================================================
& {
    Write-Host "`n[MODULO] Unificazione Rete & DNS (Adobe/Autodesk AI Ready)..." -ForegroundColor Cyan

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "NameServer" -Value "8.8.8.8 8.8.4.4" -Force

    $DNS_Pol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
    if (!(Test-Path $DNS_Pol)) { New-Item -Path $DNS_Pol -Force | Out-Null }
    Set-ItemProperty -Path $DNS_Pol -Name "NameServer" -Value "8.8.8.8,8.8.4.4" -Force

    $FW_Rules = "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
    $RuleOS   = "v2.30|Action=Block|Active=TRUE|Dir=Out|Protocol=6|RPort=443|RA4=13.107.4.52|RA4=52.114.128.21|Name=Titanium_OS_Silent_Only|"
    Set-ItemProperty -Path $FW_Rules -Name "BlockWinOS_Telemetry" -Value $RuleOS -Force

    $WPAD = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad"
    if (!(Test-Path $WPAD)) { New-Item -Path $WPAD -Force | Out-Null }
    Set-ItemProperty -Path $WPAD -Name "WpadDecision" -Value 0 -Force

    & ipconfig /flushdns | Out-Null
    Write-Host "-> Rete configurata. Server AI (Adobe/CAD) sbloccati via Google DNS." -ForegroundColor Green
}

# ============================================================
# BLOCCO 5b: NETWORK ADVANCED TWEAKS & WiFi OPTIMIZER
# Testato standalone - integrato dopo verifica
# ============================================================
& {
    Write-Host "`n[MODULO] Network Advanced Tweaks & WiFi Optimizer..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # LANMANSERVER - SMB Optimization
    # --------------------------------------------------------
    $SmbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
    Set-ItemProperty -Path $SmbPath -Name "SharingViolationDelay"   -Value 0          -Force
    Set-ItemProperty -Path $SmbPath -Name "SharingViolationRetries" -Value 0          -Force
    Set-ItemProperty -Path $SmbPath -Name "IRPStackSize"            -Value 32         -Force
    Set-ItemProperty -Path $SmbPath -Name "autodisconnect"          -Value 0xFFFFFFFF -Force
    Set-ItemProperty -Path $SmbPath -Name "Size"                    -Value 3          -Force
    Set-ItemProperty -Path $SmbPath -Name "TCP1323Opts"             -Value 1          -Force
    Write-Host "   SMB: ottimizzato (IRPStack 32, no SharingViolation, autodisconnect OFF)." -ForegroundColor Gray

    # --------------------------------------------------------
    # DNS CACHE - azzera cache errori
    # --------------------------------------------------------
    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "NegativeCacheTime"    -Value 0    -Force
    Set-ItemProperty -Path $DnsPath -Name "NegativeSOACacheTime" -Value 0    -Force
    Set-ItemProperty -Path $DnsPath -Name "NetFailureCacheTime"  -Value 0    -Force
    Set-ItemProperty -Path $DnsPath -Name "MaximumUdpPacketSize" -Value 4864 -Force
    Write-Host "   DNS: cache errori azzerata, UDP packet size 4864." -ForegroundColor Gray

    # --------------------------------------------------------
    # TCP/IP PARAMETERS - ottimizzazione connessioni
    # --------------------------------------------------------
    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-ItemProperty -Path $TcpPath -Name "TcpTimedWaitDelay"                    -Value 30      -Force
    Set-ItemProperty -Path $TcpPath -Name "MaxUserPort"                           -Value 65534   -Force
    Set-ItemProperty -Path $TcpPath -Name "TcpMaxDataRetransmissions"             -Value 5       -Force
    Set-ItemProperty -Path $TcpPath -Name "TcpCreateAndConnectTcbRateLimitDepth" -Value 0       -Force
    Set-ItemProperty -Path $TcpPath -Name "StrictTimeWaitSeqCheck"               -Value 1       -Force
    Set-ItemProperty -Path $TcpPath -Name "GlobalMaxTcpWindowSize"               -Value 65535   -Force
    Set-ItemProperty -Path $TcpPath -Name "TcpWindowSize"                        -Value 65535   -Force
    Set-ItemProperty -Path $TcpPath -Name "MaxFreeTcbs"                          -Value 65536   -Force
    Set-ItemProperty -Path $TcpPath -Name "MaxHashTableSize"                     -Value 65535   -Force
    Set-ItemProperty -Path $TcpPath -Name "Tcp1323Opts"                          -Value 3       -Force
    Set-ItemProperty -Path $TcpPath -Name "EnablePMTUDiscovery"                  -Value 1       -Force
    Set-ItemProperty -Path $TcpPath -Name "EnablePMTUBHDetect"                   -Value 0       -Force
    Set-ItemProperty -Path $TcpPath -Name "DefaultTTL"                           -Value 64      -Force
    Set-ItemProperty -Path $TcpPath -Name "EnableDynamicBacklog"                 -Value 1       -Force
    Set-ItemProperty -Path $TcpPath -Name "MinimumDynamicBacklog"                -Value 50      -Force
    Set-ItemProperty -Path $TcpPath -Name "MaximumDynamicBacklog"                -Value 1003    -Force
    Set-ItemProperty -Path $TcpPath -Name "DynamicBacklogGrowthDelta"            -Value 10      -Force
    Set-ItemProperty -Path $TcpPath -Name "KeepAliveTime"                        -Value 7200000 -Force
    Set-ItemProperty -Path $TcpPath -Name "QualifyingDestinationThreshold"       -Value 3       -Force
    Write-Host "   TCP/IP: finestra 65535, TTL 64, dynamic backlog ON, port max 65534." -ForegroundColor Gray

    # --------------------------------------------------------
    # TcpAckFrequency su tutte le interfacce
    # --------------------------------------------------------
    $InterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $interfaces = Get-ChildItem -Path $InterfacesPath -ErrorAction SilentlyContinue
    $count = 0
    foreach ($iface in $interfaces) {
        Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $iface.PSPath -Name "TcpNoDelay"      -Value 1 -Force -ErrorAction SilentlyContinue
        $count++
    }
    Write-Host ("   TcpAckFrequency/NoDelay: applicati su {0} interfacce." -f $count) -ForegroundColor Gray

    # --------------------------------------------------------
    # NDIS RSS
    # --------------------------------------------------------
    $NdisPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Ndis\Parameters"
    if (!(Test-Path $NdisPath)) { New-Item -Path $NdisPath -Force | Out-Null }
    Set-ItemProperty -Path $NdisPath -Name "MaxNumRssThreads" -Value 18 -Force
    Set-ItemProperty -Path $NdisPath -Name "MaxNumRssCpus"    -Value 6  -Force
    Write-Host "   NDIS RSS: 18 thread, 6 CPU." -ForegroundColor Gray

    # --------------------------------------------------------
    # AFD KeepAlive
    # --------------------------------------------------------
    $AfdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
    if (!(Test-Path $AfdPath)) { New-Item -Path $AfdPath -Force | Out-Null }
    Set-ItemProperty -Path $AfdPath -Name "KeepAliveInterval" -Value 1 -Force
    Write-Host "   AFD KeepAliveInterval: 1." -ForegroundColor Gray

    # --------------------------------------------------------
    # PSCHED QoS - nessuna riserva banda
    # --------------------------------------------------------
    $PschedPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    if (!(Test-Path $PschedPath)) { New-Item -Path $PschedPath -Force | Out-Null }
    Set-ItemProperty -Path $PschedPath -Name "NonBestEffortLimit" -Value 0 -Force
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "Psched" -ErrorAction SilentlyContinue
    Write-Host "   Psched QoS: riserva banda azzerata." -ForegroundColor Gray

    # --------------------------------------------------------
    # WiFi OPTIMIZER
    # --------------------------------------------------------
    $wifiAdapter = Get-NetAdapter -ErrorAction SilentlyContinue |
                   Where-Object { $_.PhysicalMediaType -eq "802.11" -and $_.Status -ne "Not Present" } |
                   Select-Object -First 1

    if ($wifiAdapter) {
        Write-Host ("   WiFi rilevato: {0}" -f $wifiAdapter.InterfaceDescription) -ForegroundColor Gray

        Disable-NetAdapterPowerManagement -Name $wifiAdapter.Name -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $wifiAdapter.Name -RegistryKeyword "PowerSavingMode"      -RegistryValue 0 -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $wifiAdapter.Name -RegistryKeyword "Band"                 -RegistryValue 2 -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $wifiAdapter.Name -RegistryKeyword "RoamingAggressiveness" -RegistryValue 1 -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $wifiAdapter.Name -RegistryKeyword "*ReceiveBuffers"       -RegistryValue 512 -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $wifiAdapter.Name -RegistryKeyword "*TransmitBuffers"      -RegistryValue 512 -ErrorAction SilentlyContinue
        Set-NetAdapterAdvancedProperty -Name $wifiAdapter.Name -RegistryKeyword "TransmitPower"         -RegistryValue 5 -ErrorAction SilentlyContinue
        & powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 2>$null
        & powercfg /setactive SCHEME_CURRENT 2>$null
        & netsh wlan set autoconfig enabled=yes interface=$wifiAdapter.Name 2>$null | Out-Null
        Write-Host "   WiFi: 5GHz preferito, risparmio energia OFF, roaming minimo, buffer 512." -ForegroundColor Gray
    } else {
        Write-Host "   WiFi: nessuna scheda rilevata - ottimizzazione saltata." -ForegroundColor Yellow
    }

    Write-Host "-> Network Advanced Tweaks & WiFi Optimizer completati." -ForegroundColor Green
}

# ============================================================
# BLOCCO 6: NETWORK OPTIMIZATION & KERNEL TUNING
# ============================================================
& {
    Write-Host "`n[MODULO] Network Optimization & Kernel Tuning..." -ForegroundColor Cyan

    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency"    -Value 1 -Force
    Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay"         -Value 1 -Force
    Set-ItemProperty -Path $TcpPath -Name "EnableRSS"          -Value 1 -Force
    Set-ItemProperty -Path $TcpPath -Name "DisableTaskOffload" -Value 0 -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "NoNameReleaseOnDemand" -Value 1 -Force

    & bcdedit.exe /set "{current}" nx OptOut            2>$null
    & bcdedit.exe /set "{current}" hypervisorlaunchtype off 2>$null
    & bcdedit.exe /set "{current}" bootmenupolicy       legacy 2>$null

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Force
    & ipconfig /flushdns | Out-Null

    Write-Host "-> Tuning applicato. Connettivita' Dispositivi & Internet PRESERVATA." -ForegroundColor Green
}

# ============================================================
# BLOCCO 7: EDGE/COPILOT PURGE & WEBVIEW2 READINESS
# ============================================================
& {
    Write-Host "`n[MODULO] Blindatura Edge & Rimozione Copilot (Post-Revo)..." -ForegroundColor Yellow

    # Rimozione Copilot
    Write-Host "-> Eliminazione pacchetti Copilot..." -ForegroundColor Gray
    dism.exe /online /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Windows.Ai.Copilot.App_1.0.3.0_neutral_~_8wekyb3d8bbwe 2>$null | Out-Null

    $CopilotPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotPol)) { New-Item -Path $CopilotPol -Force | Out-Null }
    Set-ItemProperty -Path $CopilotPol -Name "TurnOffWindowsCopilot" -Value 1 -Force

    # Blocco reinstallazione Edge
    $EdgeUpdate = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate"
    if (!(Test-Path $EdgeUpdate)) { New-Item -Path $EdgeUpdate -Force | Out-Null }
    Set-ItemProperty -Path $EdgeUpdate -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Force

    $EdgePol = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
    if (!(Test-Path $EdgePol)) { New-Item -Path $EdgePol -Force | Out-Null }
    Set-ItemProperty -Path $EdgePol -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Force

    # Servizi Edge disabilitati (WebView2 rimane funzionante)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate"  -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue

    # Pulizia task Edge
    & schtasks.exe /Delete /TN "MicrosoftEdgeUpdateTaskMachineCore" /F 2>$null
    & schtasks.exe /Delete /TN "MicrosoftEdgeUpdateTaskMachineUA"   /F 2>$null

    Write-Host "-> Edge/Copilot rimossi e blindati. WebView2 integro." -ForegroundColor Green
}

# ============================================================
# BLOCCO 8: TELEMETRY & DATA COLLECTION
# ============================================================
& {
    Write-Host "`n[MODULO] Disabilitazione Telemetria & WerSvc..." -ForegroundColor Yellow

    Stop-Service -Name "DiagTrack"       -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "WerSvc"          -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack"        -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"           -Name "Start" -Value 4 -Force

    $WerPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
    if (!(Test-Path $WerPol)) { New-Item -Path $WerPol -Force | Out-Null }
    Set-ItemProperty -Path $WerPol -Name "Disabled" -Value 1 -Force

    Write-Host "-> Telemetria e Segnalazione Errori eliminate." -ForegroundColor Green
}

# ============================================================
# BLOCCO 9: TELEMETRY GHOST TRIGGERS
# ============================================================
& {
    Write-Host "`n[MODULO] Bonifica Totale Telemetria & Ghost Triggers..." -ForegroundColor Red

    $TelPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $TelPolicy)) { New-Item -Path $TelPolicy -Force | Out-Null }
    Set-ItemProperty -Path $TelPolicy -Name "AllowTelemetry" -Value 0 -Force

    & sc.exe triggerinfo DiagTrack        delete | Out-Null
    & sc.exe triggerinfo WerSvc           delete | Out-Null
    & sc.exe triggerinfo dmwappushservice delete | Out-Null

    Stop-Service -Name "DiagTrack"        -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "WerSvc"           -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack"        -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"           -Name "Start" -Value 4 -Force

    Write-Host "-> Telemetria tombata e trigger eliminati." -ForegroundColor Green
}

# ============================================================
# BLOCCO 10: WINDOWS UPDATE & DRIVER BLOCK
# Corretto:
# - DriverSearching creata se assente (non esiste su IoT LTSC)
# - ACL Deny via Microsoft.Win32.Registry invece di Set-Acl
# - wuauserv: solo Start=4 senza ACL (compatibile con WU-Control)
# ============================================================
& {
    Write-Host "`n[MODULO] Blocco Driver & Hard Lock Windows Update..." -ForegroundColor Yellow

    # 1. BLOCCO DRIVER - crea la chiave se non esiste
    $DriverSearchPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
    if (!(Test-Path $DriverSearchPath)) { New-Item -Path $DriverSearchPath -Force | Out-Null }
    Set-ItemProperty -Path $DriverSearchPath -Name "SearchOrderConfig" -Value 0 -Force

    $DevInstall = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (!(Test-Path $DevInstall)) { New-Item -Path $DevInstall -Force | Out-Null }
    Set-ItemProperty -Path $DevInstall -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Force

    # 2. CONFIGURAZIONE WU (Target 24H2 & No Auto Update)
    $WU_AU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (!(Test-Path $WU_AU)) { New-Item -Path $WU_AU -Force | Out-Null }
    Set-ItemProperty -Path $WU_AU    -Name "AUOptions"              -Value 2      -Force
    Set-ItemProperty -Path $WU_AU    -Name "NoAutoUpdate"           -Value 1      -Force
    Set-ItemProperty -Path $DevInstall -Name "TargetReleaseVersion"     -Value 1      -Force
    Set-ItemProperty -Path $DevInstall -Name "TargetReleaseVersionInfo" -Value "24H2" -Force

    # 3. HARD LOCK: UsoSvc e WaaSMedicSvc
    # Start=4 + ACL Deny via Microsoft.Win32.Registry
    foreach ($s in @("UsoSvc", "WaaSMedicSvc")) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$s" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        Set-SvcDenyAcl -SvcName $s
    }

    # 4. SOFT LOCK: wuauserv (Start=4 senza ACL Deny)
    # WU-Control usa sc.exe per riabilitarlo temporaneamente
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv" -Name "Start" -Value 4 -Force

    Write-Host "-> UsoSvc/WaaSMedicSvc: Hard Lock ACL applicato." -ForegroundColor Green
    Write-Host "-> wuauserv: Soft Lock (Start=4, WU-Control compatibile)." -ForegroundColor Green
    Write-Host "-> Windows Update SIGILLATO. Driver protetti." -ForegroundColor Green
}

# ============================================================
# BLOCCO 11: ERROR REPORTING & GAMING
# ============================================================
& {
    Write-Host "`n[MODULO] Applicazione Esclusioni WER & Gaming..." -ForegroundColor Cyan

    $WERPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    Set-ItemProperty -Path $WERPath -Name "Disabled" -Value 1 -Force

    $AeDebug = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug"
    Set-ItemProperty -Path $AeDebug -Name "Auto" -Value 0 -Force -ErrorAction SilentlyContinue

    $GameConfig = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $GameConfig)) { New-Item -Path $GameConfig -Force | Out-Null }
    Set-ItemProperty -Path $GameConfig -Name "GameDVR_Enabled" -Value 0 -Force

    Write-Host "-> Esclusioni WER applicate. GameDVR disabilitato." -ForegroundColor Green
}

# ============================================================
# BLOCCO 12: SEARCH, BING & CONTENT DELIVERY
# ============================================================
& {
    Write-Host "`n[MODULO] Ottimizzazione Ricerca e Content Delivery..." -ForegroundColor Yellow

    $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $SSettings  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
    $CDMan      = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $CDP        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP"

    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarMode" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled"    -Value 0 -Force -ErrorAction SilentlyContinue

    if (!(Test-Path $SSettings)) { New-Item -Path $SSettings -Force | Out-Null }
    Set-ItemProperty -Path $SSettings -Name "IsDynamicSearchBoxEnabled" -Value 0 -Force -ErrorAction SilentlyContinue

    if (!(Test-Path $CDMan)) { New-Item -Path $CDMan -Force | Out-Null }
    Set-ItemProperty -Path $CDMan -Name "SilentInstalledAppsEnabled" -Value 0 -Force -ErrorAction SilentlyContinue

    if (!(Test-Path $CDP)) { New-Item -Path $CDP -Force | Out-Null }
    Set-ItemProperty -Path $CDP -Name "CdpSessionUserOverride" -Value 0 -Force -ErrorAction SilentlyContinue

    Write-Host "-> Ricerca, Content Delivery e CDP blindati." -ForegroundColor Green
}

# ============================================================
# BLOCCO 13: UI CLASSIC & PERFORMANCE TWEAKS
# ============================================================
& {
    Write-Host "`n[MODULO] Configurazione Shell & Menu Contestuale..." -ForegroundColor Cyan

    $ClassicMenu = "HKLM:\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    if (!(Test-Path $ClassicMenu)) { New-Item -Path $ClassicMenu -Force | Out-Null }
    Set-ItemProperty -Path $ClassicMenu -Name "(Default)" -Value "" -Force

    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Force

    $HkcuDesktop = "HKCU:\Control Panel\Desktop"
    if (!(Test-Path $HkcuDesktop)) { New-Item -Path $HkcuDesktop -Force | Out-Null }
    Set-ItemProperty -Path $HkcuDesktop -Name "MenuShowDelay" -Value "0" -Force

    $ExpAdv = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (!(Test-Path $ExpAdv)) { New-Item -Path $ExpAdv -Force | Out-Null }
    Set-ItemProperty -Path $ExpAdv -Name "ClassicShell" -Value 1 -Force

    Write-Host "-> Modifiche UI registrate (Attive al riavvio)." -ForegroundColor Green
}

# ============================================================
# BLOCCO 14: GAMING, INPUT LAG & UI OPTIMIZATION
# ============================================================
& {
    Write-Host "`n[MODULO] Gaming, Input Lag & UI Enhancements..." -ForegroundColor Yellow

    $GCS = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $GCS)) { New-Item -Path $GCS -Force | Out-Null }
    Set-ItemProperty -Path $GCS -Name "GameDVR_FSEBehaviorMode"          -Value 2 -Force
    Set-ItemProperty -Path $GCS -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Force

    $DVR = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    if (!(Test-Path $DVR)) { New-Item -Path $DVR -Force | Out-Null }
    Set-ItemProperty -Path $DVR -Name "AppCaptureEnabled" -Value 0 -Force

    $MousePath = "HKCU:\Control Panel\Mouse"
    if (!(Test-Path $MousePath)) { New-Item -Path $MousePath -Force | Out-Null }
    Set-ItemProperty -Path $MousePath -Name "MouseSpeed"      -Value "0" -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold1" -Value "0" -Force
    Set-ItemProperty -Path $MousePath -Name "MouseThreshold2" -Value "0" -Force

    $KbPath = "HKCU:\Control Panel\Keyboard"
    if (!(Test-Path $KbPath)) { New-Item -Path $KbPath -Force | Out-Null }
    Set-ItemProperty -Path $KbPath -Name "KeyboardDelay" -Value "0"  -Force
    Set-ItemProperty -Path $KbPath -Name "KeyboardSpeed" -Value "31" -Force

    $BGApp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $BGApp)) { New-Item -Path $BGApp -Force | Out-Null }
    Set-ItemProperty -Path $BGApp -Name "GlobalUserDisabled" -Value 1 -Force

    $Adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (!(Test-Path $Adv)) { New-Item -Path $Adv -Force | Out-Null }
    Set-ItemProperty -Path $Adv -Name "LaunchTo"          -Value 1 -Force
    Set-ItemProperty -Path $Adv -Name "HideFileExt"       -Value 0 -Force
    Set-ItemProperty -Path $Adv -Name "TaskbarAnimations"  -Value 0 -Force
    Set-ItemProperty -Path $Adv -Name "ShowTaskViewButton" -Value 0 -Force

    $DesktopPath = "HKCU:\Control Panel\Desktop"
    if (!(Test-Path $DesktopPath)) { New-Item -Path $DesktopPath -Force | Out-Null }
    Set-ItemProperty -Path $DesktopPath -Name "MenuShowDelay" -Value "0" -Force

    Stop-Service -Name "XblGameSave","XboxGipSvc" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\XblGameSave" -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\XboxGipSvc"  -Name "Start" -Value 4 -Force

    Write-Host "-> Ottimizzazioni UI e Input registrate. Attive al riavvio." -ForegroundColor Green
}

# ============================================================
# BLOCCO 15: HARDWARE PRIVACY & KERNEL TICK
# ============================================================
& {
    Write-Host "`n[MODULO] Privacy Hardware & Kernel Optimization..." -ForegroundColor Cyan

    $ConsentBase = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"
    if (!(Test-Path "$ConsentBase\webcam"))     { New-Item -Path "$ConsentBase\webcam"     -Force | Out-Null }
    if (!(Test-Path "$ConsentBase\microphone")) { New-Item -Path "$ConsentBase\microphone" -Force | Out-Null }
    Set-ItemProperty -Path "$ConsentBase\webcam"     -Name "Value" -Value "Allow" -Force
    Set-ItemProperty -Path "$ConsentBase\microphone" -Name "Value" -Value "Allow" -Force

    $KernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel"
    if (!(Test-Path $KernelPath)) { New-Item -Path $KernelPath -Force | Out-Null }
    Set-ItemProperty -Path $KernelPath -Name "OccludedWindowTickCheck" -Value 0 -Force

    Write-Host "-> Privacy impostata e Kernel Latency ottimizzata." -ForegroundColor Green
}

# ============================================================
# BLOCCO 16: WORKSTATION CLEANUP (ADOBE, OFFICE, NVIDIA)
# ============================================================
& {
    Write-Host "`n[MODULO] Workstation Cleanup (Adobe, Office, NVIDIA)..." -ForegroundColor Cyan

    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AdobeGCInvoker-1.0"  /f 2>$null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AdobeCCXProcess"     /f 2>$null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "CCXProcess"          /f 2>$null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Adobe Creative Cloud" /f 2>$null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Autodesk Desktop App" /f 2>$null

    $AdobeCRLog = "HKCU:\Software\Adobe\CommonFiles\CRLog"
    if (!(Test-Path $AdobeCRLog)) { New-Item -Path $AdobeCRLog -Force | Out-Null }
    Set-ItemProperty -Path $AdobeCRLog -Name "NeverAsk" -Value 1 -Force -ErrorAction SilentlyContinue

    $AdobeAR = "HKCU:\Software\Adobe\Acrobat Reader"
    if (!(Test-Path $AdobeAR)) { New-Item -Path $AdobeAR -Force | Out-Null }
    Set-ItemProperty -Path $AdobeAR -Name "bUpdater" -Value 0 -Force -ErrorAction SilentlyContinue

    $OffPath = "HKCU:\Software\Microsoft\Office\Common"
    if (!(Test-Path $OffPath)) { New-Item -Path $OffPath -Force | Out-Null }
    Set-ItemProperty -Path $OffPath -Name "UseOnlineContent" -Value 0 -Force

    $NVPath = "HKCU:\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS"
    if (!(Test-Path $NVPath)) { New-Item -Path $NVPath -Force | Out-Null }
    Set-ItemProperty -Path $NVPath -Name "EnableOverlay" -Value 0 -Force

    Stop-Service -Name "AdobeARMservice","WSearch" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\AdobeARMservice" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch"         -Name "Start" -Value 3 -Force

    Write-Host "-> Cleanup Adobe/Office/NVIDIA completato." -ForegroundColor Green
}

# ============================================================
# BLOCCO 17: CLEANUP, SECURITY HEALTH, SMARTSCREEN & TASK
# Aggiunto: SecurityHealthService tombato (Defender assente)
# Aggiunto: SmartScreen disabilitato (assente su IoT LTSC)
# ============================================================
& {
    Write-Host "`n[MODULO] Pulizia Chiavi Run, SecurityHealth & SmartScreen..." -ForegroundColor Yellow

    # Run keys cleanup
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SecurityHealth"      /f 2>$null
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeUpdate" /f 2>$null

    # SecurityHealthService - tombato (Defender rimosso)
    Stop-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue

    # CDPSvc / CDPUserSvc - tombati (Connected Devices Platform = CrossDevice Resume)
    # Inutile su workstation senza Phone Link o account Microsoft collegato

    # 1. ELIMINA TRIGGER (impedisce riavvio automatico da eventi di sistema)
    & sc.exe triggerinfo CDPSvc delete | Out-Null
    # CDPUserSvc ha suffisso variabile - elimina trigger su istanza corrente
    $cdpUser = Get-Service -Name "CDPUserSvc_*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cdpUser) {
        & sc.exe triggerinfo $cdpUser.Name delete | Out-Null
        Stop-Service -Name $cdpUser.Name -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $cdpUser.Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "   CDPUserSvc trigger eliminato: $($cdpUser.Name)" -ForegroundColor Gray
    }

    # 2. ARRESTO E DISABILITAZIONE
    Stop-Service -Name "CDPSvc" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CDPSvc"    -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue

    # 3. POLICY BLOCCO RIATTIVAZIONE CDP
    $CDPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $CDPath)) { New-Item -Path $CDPath -Force | Out-Null }
    Set-ItemProperty -Path $CDPath -Name "EnableCdp" -Value 0 -Force
    Set-ItemProperty -Path $CDPath -Name "EnableMmx" -Value 0 -Force

    # SmartScreen - disabilitato su tutti i vettori di avvio
    # Vettore 1: Explorer (UI SmartScreen)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue
    # Vettore 2: Policy di sistema
    $SSPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $SSPol)) { New-Item -Path $SSPol -Force | Out-Null }
    Set-ItemProperty -Path $SSPol -Name "EnableSmartScreen"     -Value 0      -Force
    Set-ItemProperty -Path $SSPol -Name "ShellSmartScreenLevel" -Value "Warn" -Force
    # Vettore 3: AppHost (SmartScreen per app Store/sideload)
    $AppHostPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppHost"
    if (!(Test-Path $AppHostPol)) { New-Item -Path $AppHostPol -Force | Out-Null }
    Set-ItemProperty -Path $AppHostPol -Name "EnableWebContentEvaluation" -Value 0 -Force
    # Vettore 4: Edge SmartScreen (residuo WebView2)
    $EdgeSSPol = "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter"
    if (!(Test-Path $EdgeSSPol)) { New-Item -Path $EdgeSSPol -Force | Out-Null }
    Set-ItemProperty -Path $EdgeSSPol -Name "EnabledV9"      -Value 0 -Force
    Set-ItemProperty -Path $EdgeSSPol -Name "PreventOverride" -Value 0 -Force
    # Vettore 5: Kill processo se ancora in esecuzione
    Stop-Process -Name "smartscreen" -Force -ErrorAction SilentlyContinue
    # Vettore 6: Task scheduler SmartScreen
    & schtasks.exe /change /tn "Microsoft\Windows\AppID\SmartScreenSpecific" /disable 2>$null

    # Task WER
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Error Reporting\QueueReporting"    /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Error Reporting\CleanupTemporaryState" /disable 2>$null

    # Servizi critici su Automatico
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CryptSvc"  -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\RpcSs"     -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"  -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Schedule"  -Name "Start" -Value 2 -Force

    # MicrosoftEdgeElevationService su Manuale (WebView2 ready)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService" -Name "Start" -Value 3 -Force -ErrorAction SilentlyContinue


    # CrossDeviceResume - blocco via Firewall outbound SOLTANTO
    # NOTA: IFEO rimosso - confligge con CBS e rompe StartAllBack, flyout volume e shell
    # Il firewall outbound e' sufficiente a bloccare le comunicazioni senza toccare CBS
    $CrossDeviceExe = "C:\WINDOWS\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\CrossDeviceResume.exe"
    if (Test-Path $CrossDeviceExe) {
        $existingRule = Get-NetFirewallRule -DisplayName "Block CrossDeviceResume" -ErrorAction SilentlyContinue
        if (!$existingRule) {
            New-NetFirewallRule -DisplayName "Block CrossDeviceResume" `
                -Direction Outbound -Program $CrossDeviceExe -Action Block `
                -ErrorAction SilentlyContinue | Out-Null
        }
    }
    # Rimuovi eventuale IFEO residuo da versioni precedenti dello script
    $IFEOPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CrossDeviceResume.exe"
    if (Test-Path $IFEOPath) {
        Remove-Item -Path $IFEOPath -Force -ErrorAction SilentlyContinue
        Write-Host "   CrossDeviceResume: IFEO residuo rimosso." -ForegroundColor Gray
    }
    Stop-Process -Name "CrossDeviceResume" -Force -ErrorAction SilentlyContinue
    Write-Host "   CrossDeviceResume: bloccato via Firewall (CBS/Shell intatti)." -ForegroundColor Gray
    # PopupKiller rimosso: non necessario con blocco via Firewall
    # Causava chiusura accidentale del flyout volume e conflitti con StartAllBack

    # Pulizia residui PopupKiller da versioni precedenti
    Unregister-ScheduledTask -TaskName "PopupKiller" -Confirm:$false -ErrorAction SilentlyContinue
    Stop-Process -Name "PopupKiller" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\System32\PopupKiller.exe" -Force -ErrorAction SilentlyContinue

    Write-Host "-> Cleanup completato. SecurityHealth tombato. SmartScreen disabilitato." -ForegroundColor Green
}

# ============================================================
# BLOCCO 17b: PROTEZIONE VOLUME AUDIO & CONNESSIONI INTERNET
# Garantisce che AudioSrv, AudioEndpointBuilder e i servizi
# di rete essenziali rimangano attivi e protetti
# ============================================================
& {
    Write-Host "`n[MODULO] Protezione Volume Audio & Connessioni Internet..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # AUDIO: forza Automatico e avvia i servizi
    # --------------------------------------------------------
    foreach ($svc in @("AudioSrv", "AudioEndpointBuilder")) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 2 -Force -ErrorAction SilentlyContinue
        Start-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Host "   $svc : Automatico + avviato." -ForegroundColor Gray
    }

    # Ri-registra flyout volume (SndVolSSO) per compatibilita' StartAllBack/LTSC
    & regsvr32.exe /s "C:\Windows\System32\SndVolSSO.dll"
    Write-Host "   SndVolSSO.dll ri-registrata." -ForegroundColor Gray

    # --------------------------------------------------------
    # RETE: servizi essenziali su Automatico
    # Protegge WiFi (WlanSvc), DHCP, DNS, Firewall, NLA
    # --------------------------------------------------------
    $NetServices = @{
        "WlanSvc"   = 2   # WLAN AutoConfig - WiFi
        "Dhcp"      = 2   # Client DHCP
        "Dnscache"  = 2   # Client DNS
        "NlaSvc"    = 3   # Network Location Awareness
        "netprofm"  = 3   # Network List Service
        "MpsSvc"    = 2   # Windows Defender Firewall
        "BFE"       = 2   # Base Filtering Engine
        "EapHost"   = 3   # Extensible Authentication (WiFi WPA)
    }

    foreach ($entry in $NetServices.GetEnumerator()) {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Key)"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "Start" -Value $entry.Value -Force -ErrorAction SilentlyContinue
            Start-Service -Name $entry.Key -ErrorAction SilentlyContinue
            Write-Host "   $($entry.Key) : configurato e avviato." -ForegroundColor Gray
        }
    }

    # Reset cache icone tray (evita icona volume fantasma)
    $TrayPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify"
    Remove-ItemProperty -Path $TrayPath -Name "IconStreams"    -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $TrayPath -Name "PastIconsStream" -ErrorAction SilentlyContinue
    Write-Host "   Cache icone tray resettata." -ForegroundColor Gray

    Write-Host "-> Volume Audio e Connessioni Internet protetti." -ForegroundColor Green
}

# ============================================================
# BLOCCO 18: CLEANUP AUTORUN, TEMP & TASK INVASIVI
# ============================================================
& {
    Write-Host "`n[MODULO] Pulizia Autorun, Temp e Task invasivi..." -ForegroundColor Yellow

    $KillList = "AcroRd32","WINWORD","EXCEL","OUTLOOK","chrome","brave","firefox","msedge"
    Stop-Process -Name $KillList -Force -ErrorAction SilentlyContinue

    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AcroRd32"   /f 2>$null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "chrome.exe" /f 2>$null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "msedge.exe" /f 2>$null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Everything" /f 2>$null

    & schtasks.exe /change /tn "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Application Experience\ProgramDataUpdater"               /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Customer Experience Improvement Program\Consolidator"    /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /disable 2>$null

    Remove-Item -Path "$env:TEMP\*"                                              -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\History\*"            -Recurse -Force -ErrorAction SilentlyContinue

    # EdgeUpdate hard block (vaccino)
    $EdgeUpPath = "$env:LOCALAPPDATA\Microsoft\EdgeUpdate"
    if (Test-Path $EdgeUpPath) { Remove-Item -Path $EdgeUpPath -Force -Recurse -ErrorAction SilentlyContinue }
    New-Item -Path $EdgeUpPath -ItemType Directory -Force | Out-Null
    & attrib.exe +R +H +S $EdgeUpPath 2>$null

    Write-Host "-> Bonifica Task e File Temporanei completata." -ForegroundColor Green
}

# ============================================================
# BLOCCO 19: DEFAULT USER TEMPLATE & HARDENING
# ============================================================
& {
    Write-Host "`n[MODULO] Propagazione Ottimizzazioni ai Nuovi Utenti (.DEFAULT)..." -ForegroundColor Cyan

    $DefaultUser = "Registry::HKEY_USERS\.DEFAULT"

    $DnsPath = "$DefaultUser\Software\Policies\Microsoft\Windows NT\DNSClient"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "NameServer" -Value "8.8.8.8,8.8.4.4" -Force

    $FwPath = "$DefaultUser\Software\Policies\Microsoft\Windows\FirewallPolicy\FirewallRules"
    if (!(Test-Path $FwPath)) { New-Item -Path $FwPath -Force | Out-Null }
    $Rule = "v2.30|Action=Block|Active=TRUE|Dir=Out|Protocol=6|RPort=443|RA4=20.54.89.106|RA4=52.114.128.21|Name=Titanium_Default_Block|"
    Set-ItemProperty -Path $FwPath -Name "BlockMSTelemetry" -Value $Rule -Force

    $ExpPath = "$DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (!(Test-Path $ExpPath)) { New-Item -Path $ExpPath -Force | Out-Null }
    Set-ItemProperty -Path $ExpPath -Name "LaunchTo" -Value 1 -Force

    $SearchPath = "$DefaultUser\Software\Microsoft\Windows\CurrentVersion\Search"
    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "DisableSearchBoxSuggestions" -Value 1 -Force
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled"           -Value 0 -Force

    # Firewall attivo per bloccare telemetria
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\MpsSvc" -Name "Start" -Value 2 -Force
    Start-Service -Name "MpsSvc" -ErrorAction SilentlyContinue

    Write-Host "-> Template .DEFAULT configurato con standard Titanium." -ForegroundColor Green
}

# ============================================================
# BLOCCO 20: FINAL TASK SCHEDULER PURGE
# ============================================================
& {
    Write-Host "`n[MODULO] Bonifica Finale Task Scheduler..." -ForegroundColor Yellow

    & schtasks.exe /change /tn "Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Error Reporting\Consent"        /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Application Experience\MareBackup"      /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\NetCeip\BindGatherer"                   /disable 2>$null

    # Task Defender residui su IoT LTSC (Defender assente ma task rimangono)
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Defender\Windows Defender Cleanup"           /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan"    /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Defender\Windows Defender Verification"      /disable 2>$null

    Write-Host "-> Task Scheduler bonificato." -ForegroundColor Green
}

# ============================================================
# BLOCCO 22: SSD/NVMe OPTIMIZATION
# Ottimizza comportamento NTFS e OS per storage a stato solido
# Filosofia: eliminare scritture inutili, preservare longevità
# ============================================================
& {
    Write-Host "`n[MODULO] SSD/NVMe Optimization..." -ForegroundColor Cyan

    # TRIM - deve essere sempre ON su SSD
    & fsutil.exe behavior set DisableDeleteNotify 0 2>$null
    Write-Host "   TRIM: ON (preserva longevità SSD)." -ForegroundColor Gray

    # Last Access Timestamp - scrittura ad ogni lettura file, inutile
    & fsutil.exe behavior set disablelastaccess 1 2>$null
    Write-Host "   Last Access Timestamp: OFF." -ForegroundColor Gray

    # 8.3 filename generation - legacy DOS, nessuna app moderna lo usa
    & fsutil.exe behavior set disable8dot3 1 2>$null
    Write-Host "   8.3 Name Creation: OFF." -ForegroundColor Gray

    # Ibernazione - libera spazio equivalente alla RAM installata
    & powercfg.exe /hibernate off 2>$null
    Write-Host "   Hibernate: OFF (libera $(Get-CimInstance Win32_ComputerSystem | ForEach-Object { [math]::Round($_.TotalPhysicalMemory/1GB) }) GB su disco)." -ForegroundColor Gray

    # Fast Boot - disabilitato per evitare problemi di avvio su macchine cliente
    $FBPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    if (!(Test-Path $FBPath)) { New-Item -Path $FBPath -Force | Out-Null }
    Set-ItemProperty -Path $FBPath -Name "HiberbootEnabled" -Value 0 -Force
    Write-Host "   Fast Boot: OFF (avvio pulito garantito)." -ForegroundColor Gray

    # Prefetch & ReadyBoot - inutili su NVMe, generano scritture
    $PfPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    if (!(Test-Path $PfPath)) { New-Item -Path $PfPath -Force | Out-Null }
    Set-ItemProperty -Path $PfPath -Name "EnablePrefetcher"   -Value 0 -Force
    Set-ItemProperty -Path $PfPath -Name "EnableBootTrace"    -Value 0 -Force
    Set-ItemProperty -Path $PfPath -Name "EnableSuperfetch"   -Value 0 -Force
    Write-Host "   Prefetch/ReadyBoot: OFF." -ForegroundColor Gray

    # Defragmentazione schedulata - dannosa su SSD
    & schtasks.exe /change /tn "Microsoft\Windows\Defrag\ScheduledDefrag" /disable 2>$null
    Write-Host "   Defragmentation schedulata: OFF." -ForegroundColor Gray

    # Boot file defrag - inutile su SSD
    $BootDefrag = "HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction"
    if (!(Test-Path $BootDefrag)) { New-Item -Path $BootDefrag -Force | Out-Null }
    Set-ItemProperty -Path $BootDefrag -Name "Enable" -Value "N" -Force
    Write-Host "   Boot File Defrag: OFF." -ForegroundColor Gray

    # Thumbnail cache - si rigenera da solo, meglio fresco su workstation Adobe
    & schtasks.exe /change /tn "Microsoft\Windows\ClearanceStorage\ClearanceStorageMaintenance" /disable 2>$null
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    Write-Host "   Thumbnail Cache: pulita." -ForegroundColor Gray

    # Kernel Swapping - OFF solo se RAM >= 8GB
    $CS_Ram = Get-CimInstance Win32_ComputerSystem
    $RamGB  = [math]::Round($CS_Ram.TotalPhysicalMemory / 1GB)
    $RegMM  = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if ($RamGB -ge 8) {
        Set-ItemProperty -Path $RegMM -Name "DisablePagingExecutive" -Value 1 -Force
        Write-Host "   Kernel Swapping: OFF (RAM $RamGB GB >= 8 GB)." -ForegroundColor Gray
    } else {
        Set-ItemProperty -Path $RegMM -Name "DisablePagingExecutive" -Value 0 -Force
        Write-Host "   Kernel Swapping: ON preservato (RAM $RamGB GB < 8 GB)." -ForegroundColor Yellow
    }

    # Indicizzazione disco - disabilitata sul drive di sistema
    $SysDrive = $env:SystemDrive
    & fsutil.exe behavior set disableencryption 1 2>$null
    try {
        $vol = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='$SysDrive'" -ErrorAction SilentlyContinue
        if ($vol) { $vol.IndexingEnabled = $false; $vol.Put() | Out-Null }
        Write-Host "   Indexing su $SysDrive`: OFF." -ForegroundColor Gray
    } catch {
        Write-Host "   WARN: Indexing - $_" -ForegroundColor Yellow
    }

    # Crash dump - disabilitato (WerSvc già tombato, evita scritture su disco)
    $CrashPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
    Set-ItemProperty -Path $CrashPath -Name "CrashDumpEnabled" -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "LogEvent"         -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "SendAlert"        -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "AutoReboot"       -Value 1 -Force
    Write-Host "   Crash Dump: OFF." -ForegroundColor Gray

    Write-Host "-> SSD/NVMe ottimizzato. TRIM attivo. Scritture inutili eliminate." -ForegroundColor Green
}

# ============================================================
# BLOCCO 23: PERFORMANCE ENGINE
# GPU priority, SystemProfile, Process scheduler
# Piano energetico: BILANCIATO preservato (scelta intenzionale)
# ============================================================
& {
    Write-Host "`n[MODULO] Performance Engine (GPU, Scheduler, I/O)..." -ForegroundColor Cyan

    # GPU Priority per applicazioni hardware-accelerated (Adobe, CAD)
    $GpuPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (!(Test-Path $GpuPath)) { New-Item -Path $GpuPath -Force | Out-Null }
    Set-ItemProperty -Path $GpuPath -Name "GPU Priority"        -Value 8      -Force
    Set-ItemProperty -Path $GpuPath -Name "Priority"            -Value 6      -Force
    Set-ItemProperty -Path $GpuPath -Name "Scheduling Category" -Value "High" -Force
    Set-ItemProperty -Path $GpuPath -Name "SFIO Priority"       -Value "High" -Force
    Write-Host "   GPU Priority: 8 (High) per Adobe/CAD." -ForegroundColor Gray

    # SystemProfile - responsiveness desktop
    $SysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $SysProfile -Name "SystemResponsiveness"   -Value 10         -Force
    Set-ItemProperty -Path $SysProfile -Name "NetworkThrottlingIndex" -Value 0xffffffff -Force
    Write-Host "   SystemResponsiveness: 10 | NetworkThrottling: OFF." -ForegroundColor Gray

    # I/O priority per processi foreground
    $PrioPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    if (!(Test-Path $PrioPath)) { New-Item -Path $PrioPath -Force | Out-Null }
    Set-ItemProperty -Path $PrioPath -Name "Win32PrioritySeparation" -Value 38 -Force
    Write-Host "   Win32PrioritySeparation: 38 (foreground boost)." -ForegroundColor Gray

    # NTFS - ottimizzazioni I/O
    & fsutil.exe behavior set memoryusage 2 2>$null
    Write-Host "   NTFS Memory Usage: livello 2 (cache paged pool estesa)." -ForegroundColor Gray

    # Font cache - illimitata per workstation con molti font Adobe
    $FontCache = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontCache"
    if (!(Test-Path $FontCache)) { New-Item -Path $FontCache -Force | Out-Null }
    Set-ItemProperty -Path $FontCache -Name "MaxCacheSize" -Value 0 -Force
    Write-Host "   Font Cache: illimitata (Adobe/CAD)." -ForegroundColor Gray

    # NOTA: Piano energetico lasciato su BILANCIATO intenzionalmente
    # Alcune macchine cliente hanno problemi termici con High Performance
    Write-Host "   Piano energetico: BILANCIATO preservato (gestione termica)." -ForegroundColor Gray

    Write-Host "-> Performance Engine applicato." -ForegroundColor Green
}

# ============================================================
# BLOCCO 25: STARTUP CLEANUP & SYSTEM BEHAVIOR
# Voci avvio legacy, servizi inutili, comportamento OS
# Basato su analisi Windows 10 Manager v2.3.1
# ============================================================
& {
    Write-Host "`n[MODULO] Startup Cleanup & System Behavior..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # SERVIZI - disabilita comportamenti inutili su LTSC
    # --------------------------------------------------------

    # PcaSvc - Compatibilità programmi: non funziona su LTSC, interroga MS
    Stop-Service -Name "PcaSvc" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\PcaSvc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Write-Host "   PcaSvc (Compatibilita' programmi): disabilitato." -ForegroundColor Gray

    # Manutenzione automatica - lasciata attiva ma silenziata
    # Esegue TRIM, chkdsk, pulizie - utile su macchine cliente non presidiate
    $MaintPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
    if (!(Test-Path $MaintPath)) { New-Item -Path $MaintPath -Force | Out-Null }
    Set-ItemProperty -Path $MaintPath -Name "MaintenanceDisabled" -Value 0 -Force
    Write-Host "   Manutenzione automatica: PRESERVATA (utile su macchine cliente)." -ForegroundColor Gray

    # Aggiornamento criteri di gruppo all'avvio - PRESERVATO
    # Necessario per mantenere attive le policy WU del Blocco 10
    Write-Host "   Criteri di gruppo avvio: PRESERVATI (richiesti da policy WU Blocco 10)." -ForegroundColor Gray

    # --------------------------------------------------------
    # AVVIO - voci legacy da disabilitare
    # --------------------------------------------------------

    # webcheck - controllo aggiornamenti IE residuo
    $RunPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Remove-ItemProperty -Path $RunPath -Name "WebCheck" -ErrorAction SilentlyContinue
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "WebCheck" /f 2>$null
    Write-Host "   WebCheck (IE legacy): rimosso dall avvio." -ForegroundColor Gray

    # unregmp2.exe - registrazione codec WMP, non serve su LTSC
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "unregmp2" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "unregmp2" /f 2>$null
    Write-Host "   unregmp2.exe (WMP codec): rimosso dall avvio." -ForegroundColor Gray

    # ie4uinit.exe - inizializzazione IE legacy
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ie4uinit" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ie4uinit" /f 2>$null
    # Blocca anche via IFEO silenzioso (noop.exe se presente, altrimenti skip)
    $IFEOie = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\ie4uinit.exe"
    if (!(Test-Path $IFEOie)) { New-Item -Path $IFEOie -Force | Out-Null }
    if (Test-Path "C:\Windows\System32\noop.exe") {
        Set-ItemProperty -Path $IFEOie -Name "Debugger" -Value "C:\Windows\System32\noop.exe" -Force
    }
    Write-Host "   ie4uinit.exe (IE legacy): bloccato." -ForegroundColor Gray

    # iconcodecservice.dll - codec icone legacy
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "IconCodecService" /f 2>$null
    Write-Host "   IconCodecService.dll (legacy): rimosso dall avvio." -ForegroundColor Gray

    # Aggiornamento desktop - refresh wallpaper inutile
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopUpdate" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopUpdate" /f 2>$null
    Write-Host "   Desktop Update: rimosso dall avvio." -ForegroundColor Gray

    # systempropertiesperformance.exe - non deve girare all avvio
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SystemPropertiesPerformance" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SystemPropertiesPerformance" /f 2>$null
    Write-Host "   SystemPropertiesPerformance.exe: rimosso dall avvio." -ForegroundColor Gray

    # mscories.dll - .NET runtime init legacy
    # Rimosso solo dall'autorun, non dal sistema - le app .NET lo caricano da sole
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "mscories" /f 2>$null
    Write-Host "   mscories.dll: rimosso dall avvio (caricato on-demand da app .NET)." -ForegroundColor Gray

    # PRESERVATI intenzionalmente - sistema non parte senza questi
    # userinit.exe  - inizializza profilo utente
    # explorer.exe  - shell principale
    # cmd.exe       - console di sistema
    Write-Host "   userinit/explorer/cmd: PRESERVATI (shell critica)." -ForegroundColor Gray

    # Configurazione Temi - PRESERVATA per StartAllBack
    Write-Host "   Configurazione Temi: PRESERVATA (richiesta da StartAllBack)." -ForegroundColor Gray

    # --------------------------------------------------------
    # COMPORTAMENTO OS
    # --------------------------------------------------------

    # Annotazione Blocco note Windows (Sticky Notes legacy)
    $StickyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\StickyNotes"
    if (!(Test-Path $StickyPath)) { New-Item -Path $StickyPath -Force | Out-Null }
    Set-ItemProperty -Path $StickyPath -Name "HideOnClose" -Value 0 -Force
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "StickyNotes" /f 2>$null
    Write-Host "   Annotazione Blocco note: disabilitata." -ForegroundColor Gray

    # Annulla chkdsk automatico all avvio su C:
    & chkntfs.exe /x C: 2>$null
    Write-Host "   Controllo disco automatico (C:): annullato." -ForegroundColor Gray

    # Ultima configurazione valida - PRESERVATA
    # Rete di sicurezza se uno script futuro danneggia il registro
    $LKGPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
    Set-ItemProperty -Path $LKGPath -Name "LastKnownGoodRecovery" -Value 1 -Force -ErrorAction SilentlyContinue
    Write-Host "   Ultima configurazione valida: PRESERVATA (rete di sicurezza)." -ForegroundColor Gray

    # --------------------------------------------------------
    # NTFS - memoria paging per cache file system
    # Completa il Blocco 23 (fsutil memoryusage 2 già applicato)
    # --------------------------------------------------------
    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $NtfsPath -Name "LargeSystemCache" -Value 0 -Force
    Write-Host "   NTFS LargeSystemCache: ottimizzato per workstation (non server)." -ForegroundColor Gray

    Write-Host "-> Startup Cleanup & System Behavior completato." -ForegroundColor Green
}

# ============================================================
# BLOCCO 24: FINAL SEALING & ATOMIC REBOOT
# ============================================================
& {
    Write-Host "`n[MODULO] Sigillatura Sistema & Pulizia Log Finali..." -ForegroundColor Cyan

    & ipconfig /flushdns | Out-Null

    # Sync registro veloce
    & reg.exe export "HKLM\SYSTEM\Select" "$env:TEMP\flush.reg" /y | Out-Null
    Remove-Item -Path "$env:TEMP\flush.reg" -Force -ErrorAction SilentlyContinue

    # Pulizia Event Viewer
    Write-Host "-> Svuotamento Event Viewer..." -ForegroundColor Gray
    & wevtutil.exe cl System      2>$null
    & wevtutil.exe cl Application 2>$null
    & wevtutil.exe cl Security    2>$null

    Write-Host "`n=== TITANIUM V8 COMPLETATA (24H2 IOT LTSC) ===" -ForegroundColor Green
    Write-Host " -> Suite Adobe/CAD, Everything e Driver: OTTIMIZZATI." -ForegroundColor White
    Write-Host " -> SSD/NVMe: TRIM attivo, scritture inutili eliminate." -ForegroundColor White
    Write-Host " -> GPU/CPU/I/O Performance Engine: APPLICATO." -ForegroundColor White
    Write-Host " -> Startup legacy e comportamento OS: PULITI." -ForegroundColor White
    Write-Host " -> Il sistema si riavviera' tra 10 secondi." -ForegroundColor Yellow

    Start-Sleep -Seconds 10
    & shutdown.exe /r /f /t 0
}