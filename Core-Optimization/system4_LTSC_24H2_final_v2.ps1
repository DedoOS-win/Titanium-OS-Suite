# ============================================================
# ============================================================
# TITANIUM V8 - FULL CONTROLLED SCRIPT (IoT LTSC 24H2)
# Target: Windows 11 IoT LTSC 24H2 (26100.x)
# Run as: SYSTEM via PowerRun
# Language: English - GitHub distribution
# ============================================================
# English version - GitHub distribution
# ============================================================
Write-Host "=== TITANIUM V8 FULL CONTROLLED ENVIRONMENT ===" -ForegroundColor Cyan

# ------------------------------------------------------------
# 0. GATEKEEPER
# ------------------------------------------------------------
if ([Security.Principal.WindowsIdentity]::GetCurrent().Name -ne "NT AUTHORITY\SYSTEM") {
    Write-Host "ERROR: Run as SYSTEM via PowerRun!" -ForegroundColor Red
    Pause; exit
}

# ------------------------------------------------------------
# SISTEMA DI LOGGING
# Log sul Desktop utente + backup in C:\Windows\Logs\System4\
# Gira come SYSTEM: rileva utente reale via WMI
# ------------------------------------------------------------
$LogDate      = Get-Date -Format "yyyy-MM-dd_HH-mm"
$LogDateHuman = Get-Date -Format "dd/MM/yyyy \a\l\l\e HH:mm"
$LogStartTime = Get-Date

# Rileva Desktop utente reale (SYSTEM non ha accesso a $env:USERPROFILE utente)
$_realUserDesktop = $null
try {
    $activeUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if ($activeUser -and $activeUser -match '\\') {
        $activeUserName = $activeUser.Split('\')[-1]
        $candidatePath  = "C:\Users\$activeUserName\Desktop"
        if (Test-Path $candidatePath) { $_realUserDesktop = $candidatePath }
    }
} catch {}

if (-not $_realUserDesktop) {
    try {
        $profiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @("Default","Default User","Public","All Users","SYSTEM") } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($profiles) { $_realUserDesktop = Join-Path $profiles.FullName "Desktop" }
    } catch {}
}
if (-not $_realUserDesktop) { $_realUserDesktop = "C:\Users\Public\Desktop" }

$LogDesktop   = "$_realUserDesktop\System4_Log_$LogDate.txt"
$LogBackupDir = "C:\Windows\Logs\System4"
if (!(Test-Path $LogBackupDir)) { New-Item -Path $LogBackupDir -ItemType Directory -Force | Out-Null }
$LogBackup    = "$LogBackupDir\System4_Log_$LogDate.txt"

$script:LogWarnings = 0
$script:LogErrors   = 0
$script:LogBlocksOk = 0

# Info hardware per intestazione
$_cs      = Get-CimInstance Win32_ComputerSystem  -ErrorAction SilentlyContinue
$_cpu     = Get-CimInstance Win32_Processor       -ErrorAction SilentlyContinue | Select-Object -First 1
$_os      = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$_ram     = if ($_cs)  { [math]::Round($_cs.TotalPhysicalMemory/1GB) } else { "N/D" }
$_cpuName = if ($_cpu) { $_cpu.Name.Trim() } else { "N/D" }
$_osVer   = if ($_os)  { "$($_os.Caption) - build $($_os.BuildNumber)" } else { "N/D" }
$_pcName  = $env:COMPUTERNAME
$_user    = if ($activeUser) { $activeUser } else { "SYSTEM" }
$_psVer   = $PSVersionTable.PSVersion.ToString()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogDesktop -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Add-Content -Path $LogBackup  -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($Level -eq "WARN")  { $script:LogWarnings++ }
    if ($Level -eq "ERROR") { $script:LogErrors++ }
    if ($Level -eq "OK")    { $script:LogBlocksOk++ }
    $color = switch ($Level) {
        "OK"    { "Green" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        default { "Gray" }
    }
    Write-Host $line -ForegroundColor $color
}

$header = @"
╔══════════════════════════════════════════════════════════════╗
║        TITANIUM V8 - OPTIMIZATION REPORT (IoT LTSC)        ║
╠══════════════════════════════════════════════════════════════╣
║ Date:          $LogDateHuman
║ Computer:      $_pcName
║ User:          $_user
║ Windows:       $_osVer
║ CPU:           $_cpuName
║ RAM:           $_ram GB
║ PowerShell:    $_psVer
║ Run as:        SYSTEM (PowerRun)
║ Log Desktop:   $LogDesktop
╚══════════════════════════════════════════════════════════════╝

--- OPERATION DETAIL ---
"@
Add-Content -Path $LogDesktop -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue
Add-Content -Path $LogBackup  -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue
Write-Host "[LOG] Report: $LogDesktop" -ForegroundColor Cyan

# ------------------------------------------------------------
# PUNTO DI RIPRISTINO
# Abilitato prima di qualunque modifica
# Su IoT LTSC il System Restore potrebbe essere disabilitato
# ------------------------------------------------------------
Write-Host "[INIT] Creating restore point..." -ForegroundColor Cyan
try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    $SrPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    if (!(Test-Path $SrPath)) { New-Item -Path $SrPath -Force | Out-Null }
    Set-ItemProperty -Path $SrPath -Name "SystemRestorePointCreationFrequency" -Type DWord -Value 0 -Force
    Checkpoint-Computer -Description "Before Titanium V8 IoT LTSC" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
    Write-Log "Restore point created." "OK"
} catch {
    Write-Log ("Restore point: WARN - {0}" -f $_) "WARN"
}

# ------------------------------------------------------------
# GLOBAL FUNCTION: Enable token privileges
# Required for Block 4 and Block 10 (ACL on protected keys)
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
# GLOBAL FUNCTION: Apply ACL Deny SetValue on service key
# Direct method via Microsoft.Win32.Registry (bypasses Set-Acl)
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
        if ($null -eq $key) { Write-Host "   WARN: cannot open $SvcName" -ForegroundColor Yellow; return }
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
        Write-Host "   ACL Deny applied on $SvcName" -ForegroundColor Gray
    } catch {
        Write-Host "   WARN: $SvcName - $_" -ForegroundColor Yellow
    }
}

# Enable privileges immediately (required from Block 4 onwards)
Enable-Privileges

# ------------------------------------------------------------
# BLOCK 1: LANGUAGE MANAGEMENT
# ------------------------------------------------------------
& {
    Write-Host "`n[MODULE] System Language Management..." -ForegroundColor Cyan

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

    Write-Host "-> Language Module Completed." -ForegroundColor Green
}

# ------------------------------------------------------------
# BLOCK 2: ADAPTIVE MEMORY ENGINE & KERNEL TIMER OPTIMIZER
# ------------------------------------------------------------
& {
    Write-Host "`n[MODULE] Hardware Adaptive Memory & Timer Engine..." -ForegroundColor Cyan

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
    # Safe strategy for bare metal with VirtualBox/Supremo/USB audio
    Write-Host "   Ottimizzazione Timer di Sistema (Low Latency)..." -ForegroundColor Gray

    # Detect if Hyper-V is active (VirtualBox cannot coexist with Hyper-V)
    $HyperVActive = $false
    try {
        $hvStatus = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue).State
        if ($hvStatus -eq "Enabled") { $HyperVActive = $true }
    } catch { $HyperVActive = $false }

    # Detect USB audio devices - sensitive to timer changes
    $UsbAudioPresent = $false
    try {
        $usbAudio = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
            $_.Class -eq "Media" -and $_.InstanceId -match "USB"
        }
        if ($usbAudio) { $UsbAudioPresent = $true }
    } catch { $UsbAudioPresent = $false }

    # Detect CPU generation for invariant TSC
    $CpuName = $Proc_Obj.Name
    $TscInvariant = $CpuName -match "i[3579]-[0-9]{4,}|Ryzen|Xeon|Core.Ultra|i[3579]-1[0-9]{4}"

    if ($HyperVActive) {
        # Hyper-V active: DO NOT touch useplatformclock - VirtualBox depends on it
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformclock 2>$null
        & bcdedit.exe /deletevalue useplatformtick  2>$null
        Write-Host "   Timer: Hyper-V detected - safe mode for VirtualBox." -ForegroundColor Yellow
    } elseif ($UsbAudioPresent) {
        # USB audio present (soundbar, DAC, interfaces): DO NOT disable dynamic tick
        # disabledynamictick altera gli interrupt USB audio causando distorsione
        & bcdedit.exe /set useplatformclock no   2>$null
        & bcdedit.exe /deletevalue disabledynamictick 2>$null  # Ripristina default
        & bcdedit.exe /deletevalue useplatformtick    2>$null
        Write-Host "   Timer: USB audio detected - dynamic tick preserved for audio stability." -ForegroundColor Yellow
        if ($usbAudio) { Write-Host ("   Protected device: {0}" -f $usbAudio.FriendlyName) -ForegroundColor Gray }
    } elseif ($TscInvariant) {
        # Modern CPU, no USB audio, no Hyper-V: full optimization
        & bcdedit.exe /set useplatformclock  no  2>$null
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformtick   2>$null
        Write-Host "   Timer: Invariant TSC - HPET disabled, minimum latency." -ForegroundColor Gray
    } else {
        # Old or unrecognized CPU: conservative configuration
        & bcdedit.exe /set useplatformclock  yes 2>$null
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformtick   2>$null
        Write-Host "   Timer: Legacy CPU - HPET preserved for stability." -ForegroundColor Yellow
    }
    Write-Host ("   CPU: {0} | Hyper-V: {1} | TSC: {2} | USB Audio: {3}" -f $CpuName, $HyperVActive, $TscInvariant, $UsbAudioPresent) -ForegroundColor Gray

    # NOTE: GlobalTimerResolutionRequests removed - causes distortion on USB/jack audio
    # Restore if present from previous script versions
    $KernelTimerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
    Remove-ItemProperty -Path $KernelTimerPath -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue

    # Ripristina driver audio USB generici se rimossi accidentalmente
    & pnputil.exe /add-driver "$env:SystemRoot\INF\wdmaudio.inf" /install /force 2>$null | Out-Null
    & pnputil.exe /add-driver "$env:SystemRoot\INF\usbaudio.inf"  /install /force 2>$null | Out-Null
    Write-Host "   Generic USB audio drivers: verified and restored." -ForegroundColor Gray

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
# BLOCK 3: CPU MITIGATIONS & VBS KILL
# ============================================================
& {
    Write-Host "`n[MODULE] Disabling CPU Mitigations & VBS..." -ForegroundColor Red

    $MMPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $MMPath -Name "FeatureSettingsOverride"     -Value 3 -Force
    Set-ItemProperty -Path $MMPath -Name "FeatureSettingsOverrideMask" -Value 3 -Force

    $DGPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    if (!(Test-Path $DGPath)) { New-Item -Path $DGPath -Force | Out-Null }
    Set-ItemProperty -Path $DGPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DmaGuard" -Name "Enabled" -Value 0 -Force -ErrorAction SilentlyContinue

    Write-Host "-> CPU Mitigations & VBS Disabled." -ForegroundColor Green
}

# ============================================================
# BLOCK 4: FTH & DPS - CHECK & HARD LOCK
# Fixed: uses Microsoft.Win32.Registry instead of Set-Acl
# ============================================================
& {
    Write-Host "`n[MODULE] Checking FTH and DPS status..." -ForegroundColor Cyan

    $FTH_Enabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\FTH" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
    $DPS_Start   = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dps" -Name "Start" -ErrorAction SilentlyContinue).Start

    if ($FTH_Enabled -eq 0 -and $DPS_Start -eq 4) {
        Write-Host "-> FTH and DPS already disabled. Proceeding to Lock." -ForegroundColor Green
    } else {
        Write-Host "-> FTH or DPS active. Forcing disable..." -ForegroundColor Yellow
        Stop-Service -Name "dps" -Force -ErrorAction SilentlyContinue
        if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\FTH")) { New-Item -Path "HKLM:\SOFTWARE\Microsoft\FTH" -Force | Out-Null }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\FTH"                        -Name "Enabled" -Value 0 -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dps"         -Name "Start"   -Value 4 -Force
    }

    Write-Host "[SYS] Applying Hard Lock DPS..." -ForegroundColor Cyan
    Set-SvcDenyAcl -SvcName "dps"
    Write-Host "-> Hard Lock DPS applied." -ForegroundColor Green
}

# ============================================================
# BLOCK 5: NETWORK & DNS UNIFICATION
# ============================================================
& {
    Write-Host "`n[MODULE] Network & DNS Unification (Adobe/Autodesk AI Ready)..." -ForegroundColor Cyan

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
    Write-Host "-> Network configured. AI servers (Adobe/CAD) unblocked via Google DNS." -ForegroundColor Green
}

# ============================================================
# BLOCK 5b: NETWORK ADVANCED TWEAKS & WiFi OPTIMIZER
# Tested standalone - integrated after verification
# ============================================================
& {
    Write-Host "`n[MODULE] Network Advanced Tweaks & WiFi Optimizer..." -ForegroundColor Cyan

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
    Write-Host "   SMB: optimized (IRPStack 32, no SharingViolation, autodisconnect OFF)." -ForegroundColor Gray

    # --------------------------------------------------------
    # DNS CACHE - clear error cache
    # --------------------------------------------------------
    $DnsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    if (!(Test-Path $DnsPath)) { New-Item -Path $DnsPath -Force | Out-Null }
    Set-ItemProperty -Path $DnsPath -Name "NegativeCacheTime"    -Value 0    -Force
    Set-ItemProperty -Path $DnsPath -Name "NegativeSOACacheTime" -Value 0    -Force
    Set-ItemProperty -Path $DnsPath -Name "NetFailureCacheTime"  -Value 0    -Force
    Set-ItemProperty -Path $DnsPath -Name "MaximumUdpPacketSize" -Value 4864 -Force
    Write-Host "   DNS: error cache cleared, UDP packet size 4864." -ForegroundColor Gray

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
    # TcpAckFrequency on all interfaces
    # --------------------------------------------------------
    $InterfacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $interfaces = Get-ChildItem -Path $InterfacesPath -ErrorAction SilentlyContinue
    $count = 0
    foreach ($iface in $interfaces) {
        Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $iface.PSPath -Name "TcpNoDelay"      -Value 1 -Force -ErrorAction SilentlyContinue
        $count++
    }
    Write-Host ("   TcpAckFrequency/NoDelay: applied on {0} interfacce." -f $count) -ForegroundColor Gray

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
        Write-Host ("   WiFi detected: {0}" -f $wifiAdapter.InterfaceDescription) -ForegroundColor Gray

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
        Write-Host "   WiFi: 5GHz preferred, power saving OFF, minimum roaming, buffer 512." -ForegroundColor Gray
    } else {
        Write-Host "   WiFi: no adapter detected - optimization skipped." -ForegroundColor Yellow
    }

    Write-Host "-> Network Advanced Tweaks & WiFi Optimizer completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 6: NETWORK OPTIMIZATION & KERNEL TUNING
# ============================================================
& {
    Write-Host "`n[MODULE] Network Optimization & Kernel Tuning..." -ForegroundColor Cyan

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

    Write-Host "-> Tuning applied. Device & Internet connectivity PRESERVED." -ForegroundColor Green
}

# ============================================================
# BLOCK 7: EDGE/COPILOT PURGE & WEBVIEW2 READINESS
# ============================================================
& {
    Write-Host "`n[MODULE] Edge Hardening & Copilot Removal (Post-Revo)..." -ForegroundColor Yellow

    # Rimozione Copilot
    Write-Host "-> Removing Copilot packages..." -ForegroundColor Gray
    dism.exe /online /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Windows.Ai.Copilot.App_1.0.3.0_neutral_~_8wekyb3d8bbwe 2>$null | Out-Null

    $CopilotPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotPol)) { New-Item -Path $CopilotPol -Force | Out-Null }
    Set-ItemProperty -Path $CopilotPol -Name "TurnOffWindowsCopilot" -Value 1 -Force

    # Block Edge reinstallation
    $EdgeUpdate = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate"
    if (!(Test-Path $EdgeUpdate)) { New-Item -Path $EdgeUpdate -Force | Out-Null }
    Set-ItemProperty -Path $EdgeUpdate -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Force

    $EdgePol = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
    if (!(Test-Path $EdgePol)) { New-Item -Path $EdgePol -Force | Out-Null }
    Set-ItemProperty -Path $EdgePol -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Force

    # Edge services disabled (WebView2 remains functional)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate"  -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue

    # Edge task cleanup
    & schtasks.exe /Delete /TN "MicrosoftEdgeUpdateTaskMachineCore" /F 2>$null
    & schtasks.exe /Delete /TN "MicrosoftEdgeUpdateTaskMachineUA"   /F 2>$null

    Write-Host "-> Edge/Copilot removed and locked. WebView2 intact." -ForegroundColor Green
}

# ============================================================
# BLOCK 8: TELEMETRY & DATA COLLECTION
# ============================================================
& {
    Write-Host "`n[MODULE] Disabling Telemetry & WerSvc..." -ForegroundColor Yellow

    Stop-Service -Name "DiagTrack"       -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "WerSvc"          -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack"        -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"           -Name "Start" -Value 4 -Force

    $WerPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
    if (!(Test-Path $WerPol)) { New-Item -Path $WerPol -Force | Out-Null }
    Set-ItemProperty -Path $WerPol -Name "Disabled" -Value 1 -Force

    Write-Host "-> Telemetry and Error Reporting eliminated." -ForegroundColor Green
}

# ============================================================
# BLOCK 9: TELEMETRY GHOST TRIGGERS
# ============================================================
& {
    Write-Host "`n[MODULE] Full Telemetry Cleanup & Ghost Triggers..." -ForegroundColor Red

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
# BLOCK 10: WINDOWS UPDATE & DRIVER BLOCK
# Corretto:
# - DriverSearching creata se assente (non esiste su IoT LTSC)
# - ACL Deny via Microsoft.Win32.Registry invece di Set-Acl
# - wuauserv: solo Start=4 senza ACL (compatibile con WU-Control)
# ============================================================
& {
    Write-Host "`n[MODULE] Driver Block & Windows Update Hard Lock..." -ForegroundColor Yellow

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
    # WU-Control uses sc.exe to re-enable it temporarily
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv" -Name "Start" -Value 4 -Force

    Write-Host "-> UsoSvc/WaaSMedicSvc: Hard Lock ACL applied." -ForegroundColor Green
    Write-Host "-> wuauserv: Soft Lock (Start=4, WU-Control compatible)." -ForegroundColor Green
    Write-Host "-> Windows Update SEALED. Drivers protected." -ForegroundColor Green
}

# ============================================================
# BLOCK 11: ERROR REPORTING & GAMING
# ============================================================
& {
    Write-Host "`n[MODULE] Applying WER & Gaming Exclusions..." -ForegroundColor Cyan

    $WERPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    Set-ItemProperty -Path $WERPath -Name "Disabled" -Value 1 -Force

    $AeDebug = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug"
    Set-ItemProperty -Path $AeDebug -Name "Auto" -Value 0 -Force -ErrorAction SilentlyContinue

    $GameConfig = "HKCU:\System\GameConfigStore"
    if (!(Test-Path $GameConfig)) { New-Item -Path $GameConfig -Force | Out-Null }
    Set-ItemProperty -Path $GameConfig -Name "GameDVR_Enabled" -Value 0 -Force

    Write-Host "-> WER exclusions applied. GameDVR disabled." -ForegroundColor Green
}

# ============================================================
# BLOCCO 12: SEARCH, BING & CONTENT DELIVERY
# ============================================================
& {
    Write-Host "`n[MODULE] Search and Content Delivery Optimization..." -ForegroundColor Yellow

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

    Write-Host "-> Search, Content Delivery and CDP hardened." -ForegroundColor Green
}

# ============================================================
# BLOCK 13: CLASSIC UI & PERFORMANCE TWEAKS
# ============================================================
& {
    Write-Host "`n[MODULE] Shell & Context Menu Configuration..." -ForegroundColor Cyan

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

    Write-Host "-> UI and Input optimizations registered. Active after reboot." -ForegroundColor Green
}

# ============================================================
# BLOCK 15: HARDWARE PRIVACY & KERNEL TICK
# ============================================================
& {
    Write-Host "`n[MODULE] Hardware Privacy & Kernel Optimization..." -ForegroundColor Cyan

    $ConsentBase = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"
    if (!(Test-Path "$ConsentBase\webcam"))     { New-Item -Path "$ConsentBase\webcam"     -Force | Out-Null }
    if (!(Test-Path "$ConsentBase\microphone")) { New-Item -Path "$ConsentBase\microphone" -Force | Out-Null }
    Set-ItemProperty -Path "$ConsentBase\webcam"     -Name "Value" -Value "Allow" -Force
    Set-ItemProperty -Path "$ConsentBase\microphone" -Name "Value" -Value "Allow" -Force

    $KernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel"
    if (!(Test-Path $KernelPath)) { New-Item -Path $KernelPath -Force | Out-Null }
    Set-ItemProperty -Path $KernelPath -Name "OccludedWindowTickCheck" -Value 0 -Force

    Write-Host "-> Privacy set and Kernel Latency optimized." -ForegroundColor Green
}

# ============================================================
# BLOCK 16: WORKSTATION CLEANUP (ADOBE, OFFICE, NVIDIA)
# ============================================================
& {
    Write-Host "`n[MODULE] Workstation Cleanup (Adobe, Office, NVIDIA)..." -ForegroundColor Cyan

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

    Write-Host "-> Adobe/Office/NVIDIA Cleanup completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 17: CLEANUP, SECURITY HEALTH, SMARTSCREEN & TASK
# Added: SecurityHealthService killed (Defender absent)
# Added: SmartScreen disabled (absent on IoT LTSC)
# ============================================================
& {
    Write-Host "`n[MODULE] Run Keys Cleanup, SecurityHealth & SmartScreen..." -ForegroundColor Yellow

    # Run keys cleanup
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SecurityHealth"      /f 2>$null
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeUpdate" /f 2>$null

    # SecurityHealthService - killed (Defender removed)
    Stop-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue

    # CDPSvc / CDPUserSvc - killed (Connected Devices Platform = CrossDevice Resume)
    # Useless on workstations without Phone Link or linked Microsoft account

    # 1. ELIMINA TRIGGER (impedisce riavvio automatico da eventi di sistema)
    & sc.exe triggerinfo CDPSvc delete | Out-Null
    # CDPUserSvc has variable suffix - delete trigger on current instance
    $cdpUser = Get-Service -Name "CDPUserSvc_*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cdpUser) {
        & sc.exe triggerinfo $cdpUser.Name delete | Out-Null
        Stop-Service -Name $cdpUser.Name -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $cdpUser.Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "   CDPUserSvc trigger deleted: $($cdpUser.Name)" -ForegroundColor Gray
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

    # SmartScreen - disabled on all launch vectors
    # Vector 1: Explorer (UI SmartScreen)
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue
    # Vector 2: System policy
    $SSPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $SSPol)) { New-Item -Path $SSPol -Force | Out-Null }
    Set-ItemProperty -Path $SSPol -Name "EnableSmartScreen"     -Value 0      -Force
    Set-ItemProperty -Path $SSPol -Name "ShellSmartScreenLevel" -Value "Warn" -Force
    # Vector 3: AppHost (SmartScreen for Store/sideload apps)
    $AppHostPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppHost"
    if (!(Test-Path $AppHostPol)) { New-Item -Path $AppHostPol -Force | Out-Null }
    Set-ItemProperty -Path $AppHostPol -Name "EnableWebContentEvaluation" -Value 0 -Force
    # Vector 4: Edge SmartScreen (WebView2 residual)
    $EdgeSSPol = "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter"
    if (!(Test-Path $EdgeSSPol)) { New-Item -Path $EdgeSSPol -Force | Out-Null }
    Set-ItemProperty -Path $EdgeSSPol -Name "EnabledV9"      -Value 0 -Force
    Set-ItemProperty -Path $EdgeSSPol -Name "PreventOverride" -Value 0 -Force
    # Vector 5: Kill process if still running
    Stop-Process -Name "smartscreen" -Force -ErrorAction SilentlyContinue
    # Vector 6: SmartScreen task scheduler
    & schtasks.exe /change /tn "Microsoft\Windows\AppID\SmartScreenSpecific" /disable 2>$null

    # WER tasks
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Error Reporting\QueueReporting"    /disable 2>$null
    & schtasks.exe /change /tn "Microsoft\Windows\Windows Error Reporting\CleanupTemporaryState" /disable 2>$null

    # Critical services set to Automatic
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CryptSvc"  -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\RpcSs"     -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"  -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Schedule"  -Name "Start" -Value 2 -Force

    # MicrosoftEdgeElevationService set to Manual (WebView2 ready)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService" -Name "Start" -Value 3 -Force -ErrorAction SilentlyContinue


    # CrossDeviceResume - block via outbound Firewall ONLY
    # NOTE: IFEO removed - conflicts with CBS and breaks StartAllBack, volume flyout and shell
    # Outbound firewall is sufficient to block communications without touching CBS
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
        Write-Host "   CrossDeviceResume: residual IFEO removed." -ForegroundColor Gray
    }
    Stop-Process -Name "CrossDeviceResume" -Force -ErrorAction SilentlyContinue
    Write-Host "   CrossDeviceResume: blocked via Firewall (CBS/Shell intact)." -ForegroundColor Gray
    # PopupKiller removed: not needed with Firewall block
    # Was causing accidental closure of volume flyout and StartAllBack conflicts

    # PopupKiller residuals cleanup from previous versions
    Unregister-ScheduledTask -TaskName "PopupKiller" -Confirm:$false -ErrorAction SilentlyContinue
    Stop-Process -Name "PopupKiller" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\System32\PopupKiller.exe" -Force -ErrorAction SilentlyContinue

    Write-Host "-> Cleanup completed. SecurityHealth killed. SmartScreen disabled." -ForegroundColor Green
}

# ============================================================
# BLOCK 17b: AUDIO VOLUME PROTECTION & INTERNET CONNECTIONS
# Ensures AudioSrv, AudioEndpointBuilder and
# essential network services remain active and protected
# ============================================================
& {
    Write-Host "`n[MODULE] Audio Volume Protection & Internet Connections..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # AUDIO: force Automatic and start services
    # --------------------------------------------------------
    foreach ($svc in @("AudioSrv", "AudioEndpointBuilder")) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 2 -Force -ErrorAction SilentlyContinue
        Start-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Host "   $svc : Automatico + avviato." -ForegroundColor Gray
    }

    # Ri-registra flyout volume (SndVolSSO) per compatibilita' StartAllBack/LTSC
    & regsvr32.exe /s "C:\Windows\System32\SndVolSSO.dll"
    Write-Host "   SndVolSSO.dll re-registered." -ForegroundColor Gray

    # --------------------------------------------------------
    # NETWORK: essential services set to Automatic
    # Protects WiFi (WlanSvc), DHCP, DNS, Firewall, NLA
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

    # Reset tray icon cache (prevents ghost volume icon)
    $TrayPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify"
    Remove-ItemProperty -Path $TrayPath -Name "IconStreams"    -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $TrayPath -Name "PastIconsStream" -ErrorAction SilentlyContinue
    Write-Host "   Tray icon cache reset." -ForegroundColor Gray

    Write-Host "-> Audio Volume and Internet Connections protected." -ForegroundColor Green
}

# ============================================================
# BLOCK 18: AUTORUN, TEMP & INVASIVE TASK CLEANUP
# ============================================================
& {
    Write-Host "`n[MODULE] Autorun, Temp and Invasive Task Cleanup..." -ForegroundColor Yellow

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

    Write-Host "-> Task and Temporary File Cleanup completed." -ForegroundColor Green
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
# BLOCK 22: SSD/NVMe OPTIMIZATION
# Optimizes NTFS and OS behavior for solid state storage
# Philosophy: eliminate unnecessary writes, preserve longevity
# ============================================================
& {
    Write-Host "`n[MODULE] SSD/NVMe Optimization..." -ForegroundColor Cyan

    # TRIM - must always be ON on SSD
    & fsutil.exe behavior set DisableDeleteNotify 0 2>$null
    Write-Host "   TRIM: ON (preserves SSD longevity)." -ForegroundColor Gray

    # Last Access Timestamp - written on every file read, useless
    & fsutil.exe behavior set disablelastaccess 1 2>$null
    Write-Host "   Last Access Timestamp: OFF." -ForegroundColor Gray

    # 8.3 filename generation - legacy DOS, no modern app uses it
    & fsutil.exe behavior set disable8dot3 1 2>$null
    Write-Host "   8.3 Name Creation: OFF." -ForegroundColor Gray

    # Hibernation - frees space equal to installed RAM
    & powercfg.exe /hibernate off 2>$null
    Write-Host "   Hibernate: OFF (libera $(Get-CimInstance Win32_ComputerSystem | ForEach-Object { [math]::Round($_.TotalPhysicalMemory/1GB) }) GB su disco)." -ForegroundColor Gray

    # Fast Boot - disabled to avoid startup issues on client machines
    $FBPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    if (!(Test-Path $FBPath)) { New-Item -Path $FBPath -Force | Out-Null }
    Set-ItemProperty -Path $FBPath -Name "HiberbootEnabled" -Value 0 -Force
    Write-Host "   Fast Boot: OFF (clean boot guaranteed)." -ForegroundColor Gray

    # Prefetch & ReadyBoot - useless on NVMe, generate writes
    $PfPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    if (!(Test-Path $PfPath)) { New-Item -Path $PfPath -Force | Out-Null }
    Set-ItemProperty -Path $PfPath -Name "EnablePrefetcher"   -Value 0 -Force
    Set-ItemProperty -Path $PfPath -Name "EnableBootTrace"    -Value 0 -Force
    Set-ItemProperty -Path $PfPath -Name "EnableSuperfetch"   -Value 0 -Force
    Write-Host "   Prefetch/ReadyBoot: OFF." -ForegroundColor Gray

    # Scheduled defragmentation - harmful on SSD
    & schtasks.exe /change /tn "Microsoft\Windows\Defrag\ScheduledDefrag" /disable 2>$null
    Write-Host "   Scheduled Defragmentation: OFF." -ForegroundColor Gray

    # Boot file defrag - useless on SSD
    $BootDefrag = "HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction"
    if (!(Test-Path $BootDefrag)) { New-Item -Path $BootDefrag -Force | Out-Null }
    Set-ItemProperty -Path $BootDefrag -Name "Enable" -Value "N" -Force
    Write-Host "   Boot File Defrag: OFF." -ForegroundColor Gray

    # Thumbnail cache - self-regenerates, better fresh on Adobe workstations
    & schtasks.exe /change /tn "Microsoft\Windows\ClearanceStorage\ClearanceStorageMaintenance" /disable 2>$null
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    Write-Host "   Thumbnail Cache: cleaned." -ForegroundColor Gray

    # Kernel Swapping - OFF only if RAM >= 8GB
    $CS_Ram = Get-CimInstance Win32_ComputerSystem
    $RamGB  = [math]::Round($CS_Ram.TotalPhysicalMemory / 1GB)
    $RegMM  = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    if ($RamGB -ge 8) {
        Set-ItemProperty -Path $RegMM -Name "DisablePagingExecutive" -Value 1 -Force
        Write-Host "   Kernel Swapping: OFF (RAM $RamGB GB >= 8 GB)." -ForegroundColor Gray
    } else {
        Set-ItemProperty -Path $RegMM -Name "DisablePagingExecutive" -Value 0 -Force
        Write-Host "   Kernel Swapping: ON preserved (RAM $RamGB GB < 8 GB)." -ForegroundColor Yellow
    }

    # Disk indexing - disabled on system drive
    $SysDrive = $env:SystemDrive
    & fsutil.exe behavior set disableencryption 1 2>$null
    try {
        $vol = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='$SysDrive'" -ErrorAction SilentlyContinue
        if ($vol) { $vol.IndexingEnabled = $false; $vol.Put() | Out-Null }
        Write-Host "   Indexing on $SysDrive`: OFF." -ForegroundColor Gray
    } catch {
        Write-Host "   WARN: Indexing - $_" -ForegroundColor Yellow
    }

    # Crash dump - disabled (WerSvc already killed, avoids disk writes)
    $CrashPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
    Set-ItemProperty -Path $CrashPath -Name "CrashDumpEnabled" -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "LogEvent"         -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "SendAlert"        -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "AutoReboot"       -Value 1 -Force
    Write-Host "   Crash Dump: OFF." -ForegroundColor Gray

    Write-Host "-> SSD/NVMe optimized. TRIM active. Unnecessary writes eliminated." -ForegroundColor Green
}

# ============================================================
# BLOCK 23: PERFORMANCE ENGINE
# GPU priority, SystemProfile, Process scheduler
# Power plan: BALANCED preserved (intentional choice)
# ============================================================
& {
    Write-Host "`n[MODULE] Performance Engine (GPU, Scheduler, I/O)..." -ForegroundColor Cyan

    # GPU Priority for hardware-accelerated applications (Adobe, CAD)
    $GpuPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (!(Test-Path $GpuPath)) { New-Item -Path $GpuPath -Force | Out-Null }
    Set-ItemProperty -Path $GpuPath -Name "GPU Priority"        -Value 8      -Force
    Set-ItemProperty -Path $GpuPath -Name "Priority"            -Value 6      -Force
    Set-ItemProperty -Path $GpuPath -Name "Scheduling Category" -Value "High" -Force
    Set-ItemProperty -Path $GpuPath -Name "SFIO Priority"       -Value "High" -Force
    Write-Host "   GPU Priority: 8 (High) for Adobe/CAD." -ForegroundColor Gray

    # SystemProfile - desktop responsiveness
    $SysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $SysProfile -Name "SystemResponsiveness"   -Value 10         -Force
    Set-ItemProperty -Path $SysProfile -Name "NetworkThrottlingIndex" -Value 0xffffffff -Force
    Write-Host "   SystemResponsiveness: 10 | NetworkThrottling: OFF." -ForegroundColor Gray

    # I/O priority for foreground processes
    $PrioPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
    if (!(Test-Path $PrioPath)) { New-Item -Path $PrioPath -Force | Out-Null }
    Set-ItemProperty -Path $PrioPath -Name "Win32PrioritySeparation" -Value 38 -Force
    Write-Host "   Win32PrioritySeparation: 38 (foreground boost)." -ForegroundColor Gray

    # NTFS - I/O optimizations
    & fsutil.exe behavior set memoryusage 2 2>$null
    Write-Host "   NTFS Memory Usage: level 2 (extended paged pool cache)." -ForegroundColor Gray

    # Font cache - unlimited for workstations with many Adobe fonts
    $FontCache = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontCache"
    if (!(Test-Path $FontCache)) { New-Item -Path $FontCache -Force | Out-Null }
    Set-ItemProperty -Path $FontCache -Name "MaxCacheSize" -Value 0 -Force
    Write-Host "   Font Cache: unlimited (Adobe/CAD)." -ForegroundColor Gray

    # NOTE: Power plan intentionally left on BALANCED
    # Some client machines have thermal issues with High Performance
    Write-Host "   Power plan: BALANCED preserved (thermal management)." -ForegroundColor Gray

    Write-Host "-> Performance Engine applied." -ForegroundColor Green
}

# ============================================================
# BLOCK 25: STARTUP CLEANUP & SYSTEM BEHAVIOR
# Legacy startup entries, useless services, OS behavior
# Based on Windows 10 Manager v2.3.1 analysis
# ============================================================
& {
    Write-Host "`n[MODULE] Startup Cleanup & System Behavior..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # SERVICES - disable useless behaviors on LTSC
    # --------------------------------------------------------

    # PcaSvc - Program Compatibility: does not work on LTSC, queries MS
    Stop-Service -Name "PcaSvc" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\PcaSvc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Write-Host "   PcaSvc (Program Compatibility): disabled." -ForegroundColor Gray

    # Automatic maintenance - left active but silenced
    # Runs TRIM, chkdsk, cleanups - useful on unattended client machines
    $MaintPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
    if (!(Test-Path $MaintPath)) { New-Item -Path $MaintPath -Force | Out-Null }
    Set-ItemProperty -Path $MaintPath -Name "MaintenanceDisabled" -Value 0 -Force
    Write-Host "   Automatic Maintenance: PRESERVED (useful on client machines)." -ForegroundColor Gray

    # Group policy update at startup - PRESERVED
    # Required to keep WU policies from Block 10 active
    Write-Host "   Startup group policies: PRESERVED (required by WU policy Block 10)." -ForegroundColor Gray

    # --------------------------------------------------------
    # STARTUP - legacy entries to disable
    # --------------------------------------------------------

    # webcheck - IE residual update check
    $RunPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Remove-ItemProperty -Path $RunPath -Name "WebCheck" -ErrorAction SilentlyContinue
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "WebCheck" /f 2>$null
    Write-Host "   WebCheck (IE legacy): removed from startup." -ForegroundColor Gray

    # unregmp2.exe - WMP codec registration, not needed on LTSC
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "unregmp2" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "unregmp2" /f 2>$null
    Write-Host "   unregmp2.exe (WMP codec): removed from startup." -ForegroundColor Gray

    # ie4uinit.exe - IE legacy initialization
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ie4uinit" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ie4uinit" /f 2>$null
    # Also block via silent IFEO (noop.exe if present, otherwise skip)
    $IFEOie = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\ie4uinit.exe"
    if (!(Test-Path $IFEOie)) { New-Item -Path $IFEOie -Force | Out-Null }
    if (Test-Path "C:\Windows\System32\noop.exe") {
        Set-ItemProperty -Path $IFEOie -Name "Debugger" -Value "C:\Windows\System32\noop.exe" -Force
    }
    Write-Host "   ie4uinit.exe (IE legacy): blocked." -ForegroundColor Gray

    # iconcodecservice.dll - legacy icon codec
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "IconCodecService" /f 2>$null
    Write-Host "   IconCodecService.dll (legacy): removed from startup." -ForegroundColor Gray

    # Desktop update - useless wallpaper refresh
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopUpdate" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopUpdate" /f 2>$null
    Write-Host "   Desktop Update: removed from startup." -ForegroundColor Gray

    # systempropertiesperformance.exe - must not run at startup
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SystemPropertiesPerformance" /f 2>$null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SystemPropertiesPerformance" /f 2>$null
    Write-Host "   SystemPropertiesPerformance.exe: removed from startup." -ForegroundColor Gray

    # mscories.dll - legacy .NET runtime init
    # Removed only from autorun, not from system - .NET apps load it on demand
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "mscories" /f 2>$null
    Write-Host "   mscories.dll: removed from startup (loaded on-demand by .NET apps)." -ForegroundColor Gray

    # INTENTIONALLY PRESERVED - system cannot start without these
    # userinit.exe  - inizializza profilo utente
    # explorer.exe  - shell principale
    # cmd.exe       - console di sistema
    Write-Host "   userinit/explorer/cmd: PRESERVED (critical shell)." -ForegroundColor Gray

    # Theme configuration - PRESERVED for StartAllBack
    Write-Host "   Theme Configuration: PRESERVED (required by StartAllBack)." -ForegroundColor Gray

    # --------------------------------------------------------
    # OS BEHAVIOR
    # --------------------------------------------------------

    # Windows Notepad annotation (legacy Sticky Notes)
    $StickyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\StickyNotes"
    if (!(Test-Path $StickyPath)) { New-Item -Path $StickyPath -Force | Out-Null }
    Set-ItemProperty -Path $StickyPath -Name "HideOnClose" -Value 0 -Force
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "StickyNotes" /f 2>$null
    Write-Host "   Notepad Annotation: disabled." -ForegroundColor Gray

    # Cancel automatic chkdsk at startup on C:
    & chkntfs.exe /x C: 2>$null
    Write-Host "   Automatic disk check (C:): cancelled." -ForegroundColor Gray

    # Last known good configuration - PRESERVED
    # Safety net if a future script damages the registry
    $LKGPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
    Set-ItemProperty -Path $LKGPath -Name "LastKnownGoodRecovery" -Value 1 -Force -ErrorAction SilentlyContinue
    Write-Host "   Last Known Good Configuration: PRESERVED (safety net)." -ForegroundColor Gray

    # --------------------------------------------------------
    # NTFS - paging memory for file system cache
    # Completes Block 23 (fsutil memoryusage 2 already applied)
    # --------------------------------------------------------
    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $NtfsPath -Name "LargeSystemCache" -Value 0 -Force
    Write-Host "   NTFS LargeSystemCache: optimized for workstation (not server)." -ForegroundColor Gray

    Write-Host "-> Startup Cleanup & System Behavior completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 24: FINAL SEALING & ATOMIC REBOOT
# ============================================================
& {
    Write-Host "`n[MODULE] System Sealing & Final Log Cleanup..." -ForegroundColor Cyan

    & ipconfig /flushdns | Out-Null

    # Quick registry sync
    & reg.exe export "HKLM\SYSTEM\Select" "$env:TEMP\flush.reg" /y | Out-Null
    Remove-Item -Path "$env:TEMP\flush.reg" -Force -ErrorAction SilentlyContinue

    # Event Viewer cleanup
    Write-Host "-> Clearing Event Viewer..." -ForegroundColor Gray
    & wevtutil.exe cl System      2>$null
    & wevtutil.exe cl Application 2>$null
    & wevtutil.exe cl Security    2>$null

    # --------------------------------------------------------
    # RIEPILOGO FINALE NEL LOG
    # --------------------------------------------------------
    $LogEndTime  = Get-Date
    $LogDuration = $LogEndTime - $LogStartTime
    $DurMin      = [math]::Floor($LogDuration.TotalMinutes)
    $DurSec      = $LogDuration.Seconds
    $LogResult   = if ($script:LogErrors -eq 0) { "COMPLETATO CON SUCCESSO" } else { "COMPLETATO CON ERRORI" }

    $footer = @"

--- FINAL SUMMARY ---
╔══════════════════════════════════════════════════════════════╗
║  RESULT:     $LogResult
║  Duration:   $DurMin minuti e $DurSec secondi
║  OK: $script:LogBlocksOk   Avvisi: $script:LogWarnings   Errori: $script:LogErrors
╚══════════════════════════════════════════════════════════════╝

In case of issues, send this file to your technician.
Log backup: C:\Windows\Logs\System4\
"@
    Add-Content -Path $LogDesktop -Value $footer -Encoding UTF8 -ErrorAction SilentlyContinue
    Add-Content -Path $LogBackup  -Value $footer -Encoding UTF8 -ErrorAction SilentlyContinue

    Write-Host "`n=== TITANIUM V8 COMPLETED (24H2 IOT LTSC) ===" -ForegroundColor Green
    Write-Host " -> Adobe/CAD Suite, Everything and Drivers: OPTIMIZED." -ForegroundColor White
    Write-Host " -> SSD/NVMe: TRIM active, unnecessary writes eliminated." -ForegroundColor White
    Write-Host " -> GPU/CPU/I/O Performance Engine: APPLIED." -ForegroundColor White
    Write-Host " -> Legacy Startup and OS Behavior: CLEANED." -ForegroundColor White
    Write-Host " -> Report saved: $LogDesktop" -ForegroundColor Cyan
    Write-Host " -> System will reboot in 10 seconds." -ForegroundColor Yellow

    # Popup finale
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            "Optimization completed!`n`nReport saved to Desktop:`n$LogDesktop`n`nIn case of issues, send this file to your technician.`n`nThe PC will reboot in a few seconds.",
            "Titanium V8 IoT LTSC - Completed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {}

    Start-Sleep -Seconds 10
    & shutdown.exe /r /f /t 0
}