# ============================================================
# TITANIUM V8 - WIN11 PRO 26100/26200
# - UAC: preserved (1) - required for RDP and Pro shell
# - HVCI: conditional - detects Hyper-V before touching
# - hypervisorlaunchtype: conditional (preserves WSL2/Sandbox)
# - Bloatware: moderate - Teams/OneDrive separate popup
# - WU lock: dual layer (registry + native Pro GPO path)
# - PcaSvc: preserved (consumer app compatibility)
# - Tamper Protection: registry sequence as Home
# ============================================================
Write-Host "=== TITANIUM V8 WIN11 PRO ===" -ForegroundColor Cyan

# ------------------------------------------------------------
# 0. GATEKEEPER + SELF-ELEVATION
# ------------------------------------------------------------
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isSystem = $currentIdentity.Name -eq "NT AUTHORITY\SYSTEM"
$isAdmin  = ([Security.Principal.WindowsPrincipal]$currentIdentity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isSystem -and -not $isAdmin) {
    Write-Host "ERROR: Run as administrator or SYSTEM via PowerRun!" -ForegroundColor Red
    Pause; exit
}

if ($isAdmin -and -not $isSystem) {
    Write-Host "WARN: Run as administrator - some ACL operations require SYSTEM." -ForegroundColor Yellow
    Write-Host "      For complete results use PowerRun." -ForegroundColor Yellow
}

# ============================================================
# TEST MODE
# Set $true during local VM testing - reads psd1 from disk
# Set $false before pushing to GitHub/production
# ============================================================
$TestMode    = $true
$TestLangDir = "C:\Titanium\lang"

# ============================================================
# LANGUAGE SYSTEM
# Loads localized strings from .psd1 via Worker
# Fallback: en-US if culture not supported or download fails
# ============================================================
$ScriptName    = "win11_PRO"
$LogDate       = Get-Date -Format "yyyy-MM-dd_HH-mm"
$LogDateHuman  = (Get-Date).ToString("g")   # follows system culture
$LogStartTime  = Get-Date

$_culture   = (Get-UICulture).Name
$_supported = @("it-IT","ru-RU","zh-CN","de-DE","es-ES","fr-FR","pt-BR","tr-TR","pl-PL")
$_langCode  = if ($_supported -contains $_culture) { $_culture } else { "en-US" }
$_workerBase = "https://dedo-os.dedonato-paolo.workers.dev"

$Lang = $null

if ($TestMode) {
    # TEST MODE: load from local folder
    $localPsd1 = Join-Path $TestLangDir "$_langCode.psd1"
    if (-not (Test-Path $localPsd1)) {
        $localPsd1 = Join-Path $TestLangDir "en-US.psd1"
    }
    if (Test-Path $localPsd1) {
        try {
            $langContent = Get-Content $localPsd1 -Raw -Encoding UTF8
            $Lang = Invoke-Expression $langContent
            Write-Host "[TEST] Language loaded from: $localPsd1" -ForegroundColor Magenta
        } catch {}
    }
} else {
    # PRODUCTION MODE: load from Worker CDN
    try {
        $langContent = (New-Object System.Net.WebClient).DownloadString("$_workerBase/lang/$_langCode")
        $Lang = Invoke-Expression $langContent
    } catch {}

    if (-not $Lang) {
        try {
            $langContent = (New-Object System.Net.WebClient).DownloadString("$_workerBase/lang/en-US")
            $Lang = Invoke-Expression $langContent
        } catch {}
    }
}

# Hard fallback if both TestMode file and Worker unreachable
if (-not $Lang) {
    $Lang = @{
        ScriptName       = "win11_PRO"
        ReportTitle      = "TITANIUM V8 - OPTIMIZATION REPORT (Win11 Pro)"
        LabelDate        = "Date"; LabelComputer = "Computer"; LabelUser = "User"
        LabelWindows     = "Windows"; LabelCPU = "CPU"; LabelRAM = "RAM"
        LabelPS          = "PowerShell"; LabelRunAs = "Run as"
        LabelRunAsSystem = "SYSTEM (PowerRun)"; LabelRunAsAdmin = "Administrator"
        LabelLogDesktop  = "Log Desktop"; LabelDetail = "--- OPERATION DETAIL ---"
        RestoreCreating  = "[INIT] Creating restore point..."
        FooterSummary    = "--- FINAL SUMMARY ---"; FooterResult = "RESULT"
        FooterSuccess    = "COMPLETED SUCCESSFULLY"; FooterWithErrors = "COMPLETED WITH ERRORS"
        FooterDuration   = "Duration"; FooterMinutes = "min"; FooterSeconds = "sec"
        FooterOK         = "OK"; FooterWarnings = "Warnings"; FooterErrors = "Errors"
        FooterSendFile   = "In case of problems, send this file to your technician."
        FooterBackupPath = "Log backup:"
        SummaryTitle     = "=== TITANIUM V8 WIN11 PRO - COMPLETED ==="
        SummaryDefender  = " -> Defender/SmartScreen/Tamper Protection: DISABLED."
        SummaryBloatware = " -> Bloatware Xbox/Teams/OneDrive/Recall: REMOVED."
        SummaryMSA       = " -> Microsoft Account and Consumer Features: BLOCKED."
        SummarySSD       = " -> SSD/NVMe: TRIM active, unnecessary writes eliminated."
        SummaryPerf      = " -> GPU/CPU/I/O Performance Engine: APPLIED."
        SummaryReboot    = " -> The system will reboot in 12 seconds."
        PopupTitle       = "Titanium V8 Pro - Completed"
        PopupBody        = "Optimization complete!`n`nReport saved to Desktop:`n{0}`n`nSend to technician if issues.`n`nPC restarts in seconds."
        # Search / Everything
        SearchInfoTitle  = "INFORMATION - Windows Search Function"
        SearchInfoLine1  = "The script will disable the Windows Search box"
        SearchInfoLine2  = "and Microsoft cloud connection."
        SearchInfoLine3  = "File search on your PC will continue to work"
        SearchInfoLine4  = "via EVERYTHING (install or portable)."
        SearchInfoLine5  = "Will be disabled:"
        SearchInfoLine6  = "- Bing search from taskbar"
        SearchInfoLine7  = "- Microsoft cloud suggestions"
        SearchInfoLine9  = "- WebView2 Search (background)"
        EverythingTitle  = "EVERYTHING - File Search"
        EverythingLine1  = "Do you want to use Everything for file search?"
        EverythingLine2  = "Fast, lightweight and free."
        EverythingLine3  = "Much faster than Windows Search on any hardware."
        EverythingOptY   = "Y = Use Everything (recommended)"
        EverythingOptN   = "N = Keep Windows Search"
        EverythingPrompt = "Use Everything for file search? (Y/N)"
        EverythingYes    = "Everything selected. Windows Search will be disabled."
        EverythingNo     = "Windows Search kept on user request."
        EverythingNote1  = "Download Everything: voidtools.com"
        EverythingNote2  = "Portable version available - no installation needed."
        EverythingNote3  = "Launch it and drag the icon to the taskbar."
        # OneDrive
        OneDriveTitle    = "Titanium V8 Pro - OneDrive"
        OneDriveMsg      = "Do you want to disable OneDrive?"
        OneDriveMsg2     = "If you choose No, OneDrive remains operational."
        OneDriveDisabled = "OneDrive: disabled on user request."
        OneDriveKept     = "OneDrive: kept active on user request."
        # Teams
        TeamsTitle       = "Titanium V8 Pro - Microsoft Teams"
        TeamsMsg         = "Do you want to remove Microsoft Teams?"
        TeamsMsg2        = "If used for business meetings, choose No."
        TeamsRemoved     = "Teams: removed on user request."
        TeamsKept        = "Teams: kept active on user request."
        # Pre-flight
        PreFlightTitle   = "[PRE-FLIGHT] System checks..."
        PreFlightDone    = "[PRE-FLIGHT] Checks completed."
        PreFlightRebootOK = "[OK]   No pending reboot."
        PreFlightReboot  = "[WARN] Pending reboot detected. Recommend rebooting before running."
        # Activation
        ActWarnTitle     = "WARNING - WINDOWS NOT ACTIVATED"
        ActWarnBody1     = "This script will lock Windows Update services."
        ActWarnBody2     = "After locking, activation requires temporarily"
        ActWarnBody3     = "re-enabling them manually."
        ActOpt1          = "[1] Activate now"
        ActOpt1b         = "    Services enabled - activate then press ENTER"
        ActOpt2          = "[2] Exit and activate first (recommended)"
        ActOpt2b         = "    Re-run this script after activation"
        ActOpt3          = "[3] Continue without activating (advanced users only)"
        ActChoice        = "Your choice (1/2/3)"
        ActServicesOn    = "[INFO] Services enabled."
        ActActivateNow   = "[INFO] Activate via: Settings -> System -> Activation"
        ActPressEnter    = "Press ENTER when activation is complete"
        ActExiting       = "Exiting. Activate Windows first, then re-run this script."
        ActWarnContinue  = "[WARN] Continuing without activation."
        ActWUControl     = "Tip: WU-Control simplifies this - available with donation:"
    }
}

# Log paths use ScriptName for folder and file
$_LogBackupDir = "C:\Windows\Logs\$ScriptName"
$_LogFileName  = "${ScriptName}_${LogDate}.txt"

# Detect real user's Desktop path even when running as SYSTEM
$_realUserDesktop = $null
try {
    # Method 1: User logged in via WMI
    $activeUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if ($activeUser -and $activeUser -match '\\') {
        $activeUserName = $activeUser.Split('\')[-1]
        $candidatePath  = "C:\Users\$activeUserName\Desktop"
        if (Test-Path $candidatePath) { $_realUserDesktop = $candidatePath }
    }
} catch {}

if (-not $_realUserDesktop) {
    try {
        # Method 2: First non-system user profile in C:\Users
        $profiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @("Default","Default User","Public","All Users","SYSTEM") } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($profiles) { $_realUserDesktop = Join-Path $profiles.FullName "Desktop" }
    } catch {}
}

# Fallback: Public desktop accessible from SYSTEM
if (-not $_realUserDesktop) {
    $_realUserDesktop = "C:\Users\Public\Desktop"
}

$DesktopPath = $_realUserDesktop
$LogDesktop  = "$DesktopPath\$_LogFileName"

# Backup to Windows/Logs folder (safe, untouched by cleanups)
$LogBackupDir = $_LogBackupDir
if (!(Test-Path $LogBackupDir)) { New-Item -Path $LogBackupDir -ItemType Directory -Force | Out-Null }
$LogBackup    = "$LogBackupDir\$_LogFileName"

# Counters
$script:LogWarnings = 0
$script:LogErrors   = 0
$script:LogBlocks   = 0
$script:LogBlocksOk = 0

# Collect hardware info by header
$_cs  = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$_cpu = Get-CimInstance Win32_Processor      -ErrorAction SilentlyContinue | Select-Object -First 1
$_os  = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$_ram = if ($_cs) { [math]::Round($_cs.TotalPhysicalMemory/1GB) } else { "N/D" }
$_cpuName = if ($_cpu) { $_cpu.Name.Trim() } else { "N/D" }
$_osVer   = if ($_os)  { "$($_os.Caption) - build $($_os.BuildNumber)" } else { "N/D" }
$_pcName  = $env:COMPUTERNAME
$_user    = if ($activeUser) { $activeUser } else { $env:USERNAME }
$_psVer   = $PSVersionTable.PSVersion.ToString()
$_runAs   = if ($isSystem) { $Lang.LabelRunAsSystem } else { $Lang.LabelRunAsAdmin }

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $ts   = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] [$Level] $Message"

    # Write to both log files
    Add-Content -Path $LogDesktop -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Add-Content -Path $LogBackup  -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue

    # Counters
    if ($Level -eq "WARN")  { $script:LogWarnings++ }
    if ($Level -eq "ERROR") { $script:LogErrors++ }
    if ($Level -eq "BLOCK") { $script:LogBlocks++ }
    if ($Level -eq "OK")    { $script:LogBlocksOk++ }

    # Console color based on level
    $color = switch ($Level) {
        "OK"    { "Green" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        "BLOCK" { "Cyan" }
        default { "Gray" }
    }
    Write-Host $line -ForegroundColor $color
}

# Write log header
$header = @"
╔══════════════════════════════════════════════════════════════╗
║  $($Lang.ReportTitle)
╠══════════════════════════════════════════════════════════════╣
║ $($Lang.LabelDate):        $LogDateHuman
║ $($Lang.LabelComputer):    $_pcName
║ $($Lang.LabelUser):        $_user
║ $($Lang.LabelWindows):     $_osVer
║ $($Lang.LabelCPU):         $_cpuName
║ $($Lang.LabelRAM):         $_ram GB
║ $($Lang.LabelPS):          $_psVer
║ $($Lang.LabelRunAs):       $_runAs
║ $($Lang.LabelLogDesktop):  $LogDesktop
╚══════════════════════════════════════════════════════════════╝

$($Lang.LabelDetail)
"@
Add-Content -Path $LogDesktop -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue
Add-Content -Path $LogBackup  -Value $header -Encoding UTF8 -ErrorAction SilentlyContinue
Write-Host "[LOG] File di report: $LogDesktop" -ForegroundColor Cyan

# Initial restore point before any major changes
# ------------------------------------------------------------
# PRE-FLIGHT CHECKS (Pro specific)
# ------------------------------------------------------------
Write-Host $Lang.PreFlightTitle -ForegroundColor Cyan

# ---- BACKUP .REG SELETTIVO ----
# Esporta servizi e trigger che verranno modificati
# Ripristino: doppio click sul .reg come Amministratore
$_backupDir = "C:\Windows\Logs\$ScriptName"
if (!(Test-Path $_backupDir)) { New-Item -Path $_backupDir -ItemType Directory -Force | Out-Null }
$_regBackup = "$_backupDir\${ScriptName}_services_backup_$LogDate.reg"

Write-Host "  [BACKUP] Exporting service registry keys..." -ForegroundColor Cyan

# Lista servizi che verranno modificati dallo script
$_svcToBackup = @(
    # Telemetria
    "HKLM\SYSTEM\CurrentControlSet\Services\DiagTrack",
    "HKLM\SYSTEM\CurrentControlSet\Services\dmwappushservice",
    "HKLM\SYSTEM\CurrentControlSet\Services\WerSvc",
    # Windows Update
    "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc",
    "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc",
    "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv",
    "HKLM\SYSTEM\CurrentControlSet\Services\bits",
    # Connected Devices / Push
    "HKLM\SYSTEM\CurrentControlSet\Services\CDPSvc",
    "HKLM\SYSTEM\CurrentControlSet\Services\WpnService",
    # SysMain / Search
    "HKLM\SYSTEM\CurrentControlSet\Services\SysMain",
    "HKLM\SYSTEM\CurrentControlSet\Services\WSearch",
    # Pro-only
    "HKLM\SYSTEM\CurrentControlSet\Services\RemoteRegistry",
    "HKLM\SYSTEM\CurrentControlSet\Services\WinRM",
    "HKLM\SYSTEM\CurrentControlSet\Services\MMCSS",
    # AI / Geolocation
    "HKLM\SYSTEM\CurrentControlSet\Services\lfsvc",
    "HKLM\SYSTEM\CurrentControlSet\Services\SsdpDiscovery",
    "HKLM\SYSTEM\CurrentControlSet\Services\TrkWks"
)

# Scrivi intestazione .reg
"Windows Registry Editor Version 5.00" | Out-File $_regBackup -Encoding Unicode
"" | Out-File $_regBackup -Encoding Unicode -Append
"; Titanium V8 Pro - Services backup before optimization" | Out-File $_regBackup -Encoding Unicode -Append
"; Date: $LogDateHuman" | Out-File $_regBackup -Encoding Unicode -Append
"; Restore: double-click this file as Administrator" | Out-File $_regBackup -Encoding Unicode -Append
"" | Out-File $_regBackup -Encoding Unicode -Append

$_backedUp = 0
foreach ($regPath in $_svcToBackup) {
    $result = & reg.exe export $regPath "$_backupDir\_temp_svc.reg" /y 2>$null
    if (Test-Path "$_backupDir\_temp_svc.reg") {
        # Salta la prima riga (intestazione reg) e aggiungi al file principale
        Get-Content "$_backupDir\_temp_svc.reg" -Encoding Unicode |
            Select-Object -Skip 1 |
            Out-File $_regBackup -Encoding Unicode -Append
        Remove-Item "$_backupDir\_temp_svc.reg" -Force -ErrorAction SilentlyContinue
        $_backedUp++
    }
}

Write-Host ("  [BACKUP] {0} service keys exported to:" -f $_backedUp) -ForegroundColor Green
Write-Host "           $_regBackup" -ForegroundColor Gray

# Check 1: Free disk space (restore point needs at least 2GB)
try {
    $sysDrive  = $env:SystemDrive
    $freeGB    = [math]::Round((Get-PSDrive ($sysDrive.Replace(":","")) -ErrorAction SilentlyContinue).Free / 1GB, 1)
    if ($freeGB -lt 2) {
        Write-Host ("  [WARN] Low disk space: {0} GB free. At least 2 GB recommended." -f $freeGB) -ForegroundColor Yellow
    } else {
        Write-Host ("  [OK]   Disk space: {0} GB free." -f $freeGB) -ForegroundColor Gray
    }
} catch {}

# Check 2: Pending reboot detection
$_pendingReboot = $false
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { $_pendingReboot = $true }
if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations") { $_pendingReboot = $true }
if ($_pendingReboot) {
    Write-Host "  $($Lang.PreFlightReboot)" -ForegroundColor Yellow
} else {
    Write-Host "  $($Lang.PreFlightRebootOK)" -ForegroundColor Gray
}

# Check 3: Windows activation status
    try {
        $licProduct = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%'" -ErrorAction SilentlyContinue |
            Where-Object { $_.PartialProductKey } | Select-Object -First 1
        $licStatus = $licProduct.LicenseStatus

        if ($licStatus -eq 1) {
            Write-Host "  [OK]   Windows activated." -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
            Write-Host ("  |  {0,-58}|" -f $Lang.ActWarnTitle) -ForegroundColor Yellow
            Write-Host "  |                                                          |" -ForegroundColor Yellow
            Write-Host ("  |  {0,-58}|" -f $Lang.ActWarnBody1) -ForegroundColor Yellow
            Write-Host ("  |  {0,-58}|" -f $Lang.ActWarnBody2) -ForegroundColor Yellow
            Write-Host ("  |  {0,-58}|" -f $Lang.ActWarnBody3) -ForegroundColor Yellow
            Write-Host "  |                                                          |" -ForegroundColor Yellow
            Write-Host ("  |  {0,-58}|" -f $Lang.ActOpt1) -ForegroundColor Green
            Write-Host ("  |  {0,-58}|" -f $Lang.ActOpt1b) -ForegroundColor Green
            Write-Host "  |                                                          |" -ForegroundColor Yellow
            Write-Host ("  |  {0,-58}|" -f $Lang.ActOpt2) -ForegroundColor Cyan
            Write-Host ("  |  {0,-58}|" -f $Lang.ActOpt2b) -ForegroundColor Cyan
            Write-Host "  |                                                          |" -ForegroundColor Yellow
            Write-Host ("  |  {0,-58}|" -f $Lang.ActOpt3) -ForegroundColor Gray
            Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
            Write-Host ""

            $actChoice = Read-Host "  $($Lang.ActChoice)"

            switch ($actChoice) {
                "1" {
                    foreach ($svc in @("wuauserv","LicenseManager","ClipSVC","TokenBroker")) {
                        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" `
                            -Name "Start" -Value 3 -Force -ErrorAction SilentlyContinue
                        Start-Service -Name $svc -ErrorAction SilentlyContinue
                    }
                    Write-Host ""
                    Write-Host "  $($Lang.ActServicesOn)" -ForegroundColor Cyan
                    Write-Host "  $($Lang.ActActivateNow)" -ForegroundColor Cyan
                    Write-Host ""
                    Read-Host "  $($Lang.ActPressEnter)"
                }
                "2" {
                    Write-Host ""
                    Write-Host "  $($Lang.ActExiting)" -ForegroundColor Cyan
                    Write-Host ""
                    Start-Sleep -Seconds 3
                    exit 0
                }
                "3" {
                    Write-Host ""
                    Write-Host "  $($Lang.ActWarnContinue)" -ForegroundColor Yellow
                    Write-Host "  [INFO] To activate later:" -ForegroundColor Gray
                    Write-Host "         1. Run PowerShell as Administrator" -ForegroundColor Gray
                    Write-Host "         2. Start-Service wuauserv, LicenseManager, ClipSVC" -ForegroundColor Gray
                    Write-Host "         3. Activate via Settings -> System -> Activation" -ForegroundColor Gray
                    Write-Host "         Tip: WU-Control simplifies this - available with" -ForegroundColor DarkGray
                    Write-Host "              project donation: paypal.me/fastwindows" -ForegroundColor DarkCyan
                    Write-Host ""
                }
                default {
                    Write-Host "  Invalid choice. Exiting for safety." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                    exit 0
                }
            }
        }
    } catch {}

Write-Host $Lang.PreFlightDone -ForegroundColor Green

# Restore point
Write-Host $Lang.RestoreCreating -ForegroundColor Cyan
Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
$SrPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
if (!(Test-Path $SrPath)) { New-Item -Path $SrPath -Force | Out-Null }
Set-ItemProperty -Path $SrPath -Name "SystemRestorePointCreationFrequency" -Type DWord -Value 0 -Force
Checkpoint-Computer -Description "before Titanium V8 win11 pro" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# DEFENDER: SCRIPT PATH EXCLUSION (pre-execution blocks)
# ------------------------------------------------------------
$Sys4ScriptPath = $MyInvocation.MyCommand.Path
if (-not $Sys4ScriptPath) { $Sys4ScriptPath = $PSCommandPath }
$Sys4ExclusionPaths = @(
    $Sys4ScriptPath,
    "C:\ProgramData\System4"
) | Where-Object { $_ }

Write-Host "[DEFENDER] Added script path exclusion..." -ForegroundColor Cyan
foreach ($excPath in $Sys4ExclusionPaths) {
    try {
        Add-MpPreference -ExclusionPath $excPath -ErrorAction SilentlyContinue
        Write-Host ("   Exclusion aggiunta: {0}" -f $excPath) -ForegroundColor DarkGray
    } catch {
        Write-Host ("   WARN exclusion ({0}): {1}" -f $excPath, $_) -ForegroundColor Yellow
    }
}

function Remove-Sys4DefenderExclusions {
    Write-Host "[DEFENDER] Removing script path exclusions..." -ForegroundColor Cyan
    foreach ($excPath in $Sys4ExclusionPaths) {
        try {
            Remove-MpPreference -ExclusionPath $excPath -ErrorAction SilentlyContinue
            Write-Host ("   Exclusion rimossa: {0}" -f $excPath) -ForegroundColor DarkGray
        } catch {}
    }
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
# GLOBAL FUNCTION: Apply Deny SetValue ACL on service key
# Direct method Microsoft.Win32.Registry (bypassSet-Acl)
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
        Write-Host "   ACL Deny applied on $SvcName" -ForegroundColor Gray
    } catch {
        Write-Host "   WARN: $SvcName - $_" -ForegroundColor Yellow
    }
}

function Invoke-SchtasksQuiet {
    param([string]$Arguments)
    & cmd.exe /c "schtasks $Arguments >nul 2>nul" | Out-Null
}

function Remove-RegValueQuiet {
    param(
        [string]$Path,
        [string]$Name
    )
    try { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue } catch {}
}

function Set-RegDwordQuiet {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )
    try {
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {}
}

# ------------------------------------------------------------
# GLOBAL FUNCTION: Retrieve active interactive user SID
# ------------------------------------------------------------
function Get-ActiveUserSid {
    try {
        $activeUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
        if ([string]::IsNullOrWhiteSpace($activeUser)) { return $null }
        $parts = $activeUser.Split('\')
        if ($parts.Count -lt 2) { return $null }
        $domain = $parts[0]; $user = $parts[1]
        $acct = Get-CimInstance -ClassName Win32_UserAccount -Filter "Name='$user' AND Domain='$domain'" -ErrorAction SilentlyContinue
        if ($acct -and $acct.SID) { return $acct.SID }
    } catch {}
    return $null
}

# ------------------------------------------------------------
# GLOBAL FEATURE: Set TaskbarFrom on all user profiles
# ------------------------------------------------------------
function Set-TaskbarDaEverywhere {
    param([int]$Value = 0)
    $advKey = "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-RegDwordQuiet -Path "HKCU:\$advKey" -Name "TaskbarDa" -Value $Value
    $activeSid = Get-ActiveUserSid
    if ($activeSid) {
        Set-RegDwordQuiet -Path "Registry::HKEY_USERS\$activeSid\$advKey" -Name "TaskbarDa" -Value $Value
        Write-Host ("   Widgets: TaskbarDa={0} su SID utente attivo: {1}" -f $Value, $activeSid) -ForegroundColor DarkGray
    } else {
        Write-Host "   Widgets: Active user SID not detected (no user logged in)." -ForegroundColor DarkGray
    }
    Set-RegDwordQuiet -Path "Registry::HKEY_USERS\.DEFAULT\$advKey" -Name "TaskbarDa" -Value $Value
}

function Ask-YesNoPopup {
    param(
        [string]$Title,
        [string]$Message
    )
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $result = [System.Windows.Forms.MessageBox]::Show(
            $Message,
            $Title,
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
    } catch {
        $fallback = Read-Host "$Message (S/N)"
        return ($fallback -match "^[SsYy]$")
    }
}

function Invoke-ZombiePurge {
    param([bool]$DisableOneDrive = $true)
    # Repeatable purge to prevent reinstallations after updates/installations
    $patterns = @("*Copilot*", "*MicrosoftTeams*", "*Teams*", "*OneDrive*", "*Bing*")
    foreach ($p in $patterns) {
        Get-AppxPackage -AllUsers -Name $p -ErrorAction SilentlyContinue |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $p -or $_.PackageName -like $p } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }

    Remove-RegValueQuiet -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "TeamsMachineInstaller"

    if ($DisableOneDrive) {
        Remove-RegValueQuiet -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive"
        Remove-RegValueQuiet -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive"
        Remove-RegValueQuiet -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDriveSetup"
        Remove-RegValueQuiet -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDriveSetup"
        $ODPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (!(Test-Path $ODPath)) { New-Item -Path $ODPath -Force | Out-Null }
        Set-ItemProperty -Path $ODPath -Name "DisableFileSyncNGSC" -Value 1 -Force
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    }
    Stop-Process -Name "ms-teams","Teams","Copilot" -Force -ErrorAction SilentlyContinue
}

function Invoke-CopilotHardBlock {
    # Keeps Edge/WebView2 intact, only blocks Copilot from running
    $CopilotExeCandidates = @(
        "C:\Program Files (x86)\Microsoft\Copilot\Application\copilot.exe",
        "C:\Program Files (x86)\Microsoft\Copilot\Application\msedge_proxy.exe"
    )

    foreach ($exe in $CopilotExeCandidates) {
        if (Test-Path $exe) {
            $ruleName = "System4 Block Copilot - " + [System.IO.Path]::GetFileName($exe)
            $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Program $exe -Action Block -Profile Any -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    # Disable Copilot-related scheduled tasks without touching Edge core
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -match "Copilot" -or $_.TaskPath -match "Copilot" } |
            Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    Stop-Process -Name "copilot","ms-copilot","msedge_proxy" -Force -ErrorAction SilentlyContinue
}

# Enable privileges now (needed from Block 4 onwards)
Enable-Privileges

# ------------------------------------------------------------
# BLOCK 1: LANGUAGE MANAGEMENT
# ------------------------------------------------------------
& {
    Write-Host "`n[MODULO] System Language Management..." -ForegroundColor Cyan

    Stop-Service -Name "W32Time"          -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "FontCache"        -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "LanmanWorkstation" -Force -ErrorAction SilentlyContinue

    # Use culture detected during language loading - do not hardcode
    $sysCulture = $_culture  # already detected: it-IT, de-DE, en-US etc.

    # Only apply if culture is in supported list - skip for unsupported/unknown
    if ($_supported -contains $sysCulture -or $sysCulture -eq "en-US") {
        $keepLangs = @($sysCulture, "en-US") | Select-Object -Unique
        $WarningPreference_Bak = $WarningPreference
        $WarningPreference = "SilentlyContinue"
        Set-WinUserLanguageList -LanguageList $keepLangs -Force -ErrorAction SilentlyContinue | Out-Null
        Set-WinSystemLocale     -SystemLocale $sysCulture -ErrorAction SilentlyContinue | Out-Null
        Set-WinUILanguageOverride -Language $sysCulture -ErrorAction SilentlyContinue | Out-Null
        $WarningPreference = $WarningPreference_Bak
        Write-Host "   System language: $sysCulture (applied)." -ForegroundColor Gray
    } else {
        Write-Host "   System language: $sysCulture (not in supported list - skipped)." -ForegroundColor Yellow
    }

    Start-Service -Name "W32Time"          -ErrorAction SilentlyContinue
    Start-Service -Name "FontCache"        -ErrorAction SilentlyContinue
    Start-Service -Name "LanmanWorkstation" -ErrorAction SilentlyContinue

    Write-Host "-> Language Module Completed." -ForegroundColor Green
}

# ------------------------------------------------------------
# BLOCK 2: ADAPTIVE MEMORY ENGINE & KERNEL TIMER OPTIMIZER
# ------------------------------------------------------------
& {
    Write-Host "`n[MODULO] Hardware Adaptive Memory & Timer Engine..." -ForegroundColor Cyan

    # 1. DEEP HARDWARE DETECTION
    $CS_Obj       = Get-CimInstance Win32_ComputerSystem | Select-Object -First 1
    $Proc_Obj     = Get-CimInstance Win32_Processor | Select-Object -First 1
    $RAM_Data     = Get-CimInstance Win32_PhysicalMemory
    
    $TotalRAM_MB  = [math]::Round($CS_Obj.TotalPhysicalMemory / 1MB)
    $RAM_GB       = [math]::Round($TotalRAM_MB / 1024)
    $CpuCores     = $Proc_Obj.NumberOfCores
    $RAMSpeed     = if ($RAM_Data) { ($RAM_Data | Measure-Object -Property Speed -Maximum).Maximum } else { 2400 }

    Write-Host "   Hardware: $CpuCores Core Fisici | $RAM_GB GB RAM @ $RAMSpeed MHz" -ForegroundColor Gray

    # 2. TIMER OPTIMIZATION (HPET & TICK)
    # Safe strategy for bare metal with VirtualBox/Supremo/USB audio
    Write-Host "   System Timer Optimization (Low Latency)..." -ForegroundColor Gray

    # Detect if Hyper-V is active (VirtualBox does not coexist with Hyper-V)
    $HyperVActive = $false
    try {
        $hvStatus = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue).State
        if ($hvStatus -eq "Enabled") { $HyperVActive = $true }
    } catch { $HyperVActive = $false }

    # Detect USB audio devices - sensitive to timers
    $UsbAudioPresent = $false
    try {
        $usbAudio = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
            $_.Class -eq "Media" -and $_.InstanceId -match "USB"
        }
        if ($usbAudio) { $UsbAudioPresent = $true }
    } catch { $UsbAudioPresent = $false }

    # Detect CPU generation for TSC invariant
    $CpuName = $Proc_Obj.Name
    $TscInvariant = $CpuName -match "i[3579]-[0-9]{4,}|Ryzen|Xeon|Core.Ultra|i[3579]-1[0-9]{4}"

    if ($HyperVActive) {
        # Hyper-V active: DO NOT touch useplatformclock - VirtualBox depends on it.
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformclock 2>$null
        & bcdedit.exe /deletevalue useplatformtick  2>$null
        Write-Host "   Timer: Hyper-V detected - safe mode for VirtualBox." -ForegroundColor Yellow
    } elseif ($UsbAudioPresent) {
        # USB audio present (soundbar, DAC, interfaces): DO NOT disable dynamic tick
        # disabledynamictick alters USB audio interrupts, causing distortion
        & bcdedit.exe /set useplatformclock no   2>$null
        & bcdedit.exe /deletevalue disabledynamictick 2>$null  # Ripristina default
        & bcdedit.exe /deletevalue useplatformtick    2>$null
        Write-Host "   Timer: Audio USB rilevato - dynamic tick preservato per stabilita' audio." -ForegroundColor Yellow
        if ($usbAudio) { Write-Host ("   Dispositivo protetto: {0}" -f $usbAudio.FriendlyName) -ForegroundColor Gray }
    } elseif ($TscInvariant) {
        # Modern CPU, no USB audio, no Hyper-V: full optimization
        & bcdedit.exe /set useplatformclock  no  2>$null
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformtick   2>$null
        Write-Host "   Timer: TSC invariant - HPET disabled, minimal latency." -ForegroundColor Gray
    } else {
        # Old or unrecognized CPU: conservative configuration
        & bcdedit.exe /set useplatformclock  yes 2>$null
        & bcdedit.exe /set disabledynamictick yes 2>$null
        & bcdedit.exe /deletevalue useplatformtick   2>$null
        Write-Host "   Timer: Legacy CPU - HPET preserved for stability." -ForegroundColor Yellow
    }
    Write-Host ("   CPU: {0} | Hyper-V: {1} | TSC: {2} | USB Audio: {3}" -f $CpuName, $HyperVActive, $TscInvariant, $UsbAudioPresent) -ForegroundColor Gray

    # NOTE: Global Timer Resolution Requests removed - causes distortion on USB/jack audio
    # Restore if present from previous versions of the script
    $KernelTimerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
    Remove-ItemProperty -Path $KernelTimerPath -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue

    # Restore generic USB audio drivers if accidentally removed
    & pnputil.exe /add-driver "$env:SystemRoot\INF\wdmaudio.inf" /install /force 2>$null | Out-Null
    & pnputil.exe /add-driver "$env:SystemRoot\INF\usbaudio.inf"  /install /force 2>$null | Out-Null
    Write-Host "   Driver audio USB generici: verificati e ripristinati." -ForegroundColor Gray

    Stop-Service -Name "SysMain","WSearch","Spooler" -Force -ErrorAction SilentlyContinue

    # 3. ADAPTIVE PAGEFILE LOGIC
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

    # 4. SVCHOST SPLIT LOGIC - granular table for RAM
    $thresholdMap = @{
        4  = 410000
        6  = 614000
        8  = 819200
        12 = 1228800
        16 = 1638400
        24 = 2457600
        32 = 3276800
        64 = 6553600
    }
    $availableKeys = $thresholdMap.Keys | Where-Object { $_ -le $RAM_GB } | Sort-Object -Descending
    if ($availableKeys.Count -gt 0) {
        $svcValue = $thresholdMap[$availableKeys[0]]
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $svcValue -Force
        Write-Host "   SvcHostSplitThreshold: $svcValue KB (RAM: $RAM_GB GB)." -ForegroundColor Gray
    } else {
        Write-Host "   WARN: Unmapped RAM ($RAM_GB GB), SvcHostSplitThreshold unchanged." -ForegroundColor Yellow
    }

    # 5. MEMORY COMPRESSION (MMAgent)
    if (Get-Command Disable-MMAgent -ErrorAction SilentlyContinue) {
        if ($RAM_GB -ge 16 -or $CpuCores -le 4) {
            Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            $CompStatus = "OFF"
        } else {
            Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            $CompStatus = "ON"
        }
    } else { $CompStatus = "N/D" }

    # WSearch NOT restarted - permanently disabled in Block 16
    # SysMain: on Pro ISO is NOT pre-disabled (unlike Home/LTSC) - disable explicitly
    Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SysMain" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Write-Host "   SysMain (Superfetch): disabled (Pro ISO does not pre-disable it)." -ForegroundColor Gray
    Start-Service -Name "Spooler" -ErrorAction SilentlyContinue

    Write-Host ("-> Profilo {0}: Timer Ottimizzati | SvcHost {1} {2} KB | Compressione {3}" -f $Profile, $(if($RAM_GB -ge 4){"Split"}else{"Unified"}), $svcValue, $CompStatus) -ForegroundColor Green
}

# ============================================================
# BLOCK 3: CPU MITIGATIONS & VBS/HVCI KILL
# PRO: HVCI conditional - detects Hyper-V before DISM
# If Hyper-V active (WSL2/Sandbox) -> skip DISM, registry only
# ============================================================
& {
    Write-Host "`n[MODULO] CPU Mitigations & VBS/HVCI..." -ForegroundColor Red

    # Detect Hyper-V state BEFORE touching anything
    $HyperVState = $false
    try {
        $hvFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
        if ($hvFeature.State -eq "Enabled") { $HyperVState = $true }
    } catch { $HyperVState = $false }

    # Also check hypervisorlaunchtype in BCD
    $bcdOutput = & bcdedit.exe /enum current 2>$null
    if ($bcdOutput -match "hypervisorlaunchtype\s+Auto") { $HyperVState = $true }

    Write-Host ("   Hyper-V detected: {0}" -f $HyperVState) -ForegroundColor Gray

    $MMPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $MMPath -Name "FeatureSettingsOverride"     -Value 3 -Force
    Set-ItemProperty -Path $MMPath -Name "FeatureSettingsOverrideMask" -Value 3 -Force

    $DGPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    if (!(Test-Path $DGPath)) { New-Item -Path $DGPath -Force | Out-Null }
    Set-ItemProperty -Path $DGPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Force
    Set-ItemProperty -Path $DGPath -Name "HypervisorEnforcedCodeIntegrity"   -Value 0 -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DmaGuard" -Name "Enabled" -Value 0 -Force -ErrorAction SilentlyContinue

    $CIPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (!(Test-Path $CIPath)) { New-Item -Path $CIPath -Force | Out-Null }
    Set-ItemProperty -Path $CIPath -Name "Enabled"    -Value 0 -Force
    Set-ItemProperty -Path $CIPath -Name "WasEnabledBy" -Value 0 -Force -ErrorAction SilentlyContinue

    if (-not $HyperVState) {
        # Hyper-V NOT active: disable HVCI via DISM (safe)
        Write-Host "   Disabling HVCI via DISM (Hyper-V not active)..." -ForegroundColor Gray
        & dism.exe /online /Disable-Feature /FeatureName:IsolatedUserMode /NoRestart 2>$null | Out-Null
        & dism.exe /online /Disable-Feature /FeatureName:Microsoft-Hyper-V-Hypervisor /NoRestart 2>$null | Out-Null
        Write-Host "-> CPU Mitigations & VBS/HVCI Disabled." -ForegroundColor Green
    } else {
        # Hyper-V ACTIVE: skip DISM - WSL2/Sandbox/VMs preserved
        Write-Host "   HVCI via DISM: SKIPPED - Hyper-V active (WSL2/Sandbox preserved)." -ForegroundColor Yellow
        Write-Host "-> CPU Mitigations: registry policy applied. DISM skipped." -ForegroundColor Yellow
    }

    # Export HyperVState for Block 6
    $script:HyperVState = $HyperVState
}

# ============================================================
# BLOCK 4: FTH & DPS - CHECK & HARD LOCK
# Use Microsoft.Win32.Registry instead of Set-Acl
# ============================================================
& {
    Write-Host "`n[MODULO] Checking FTH and DPS status..." -ForegroundColor Cyan

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
# BLOCK 5: NETWORK & DNS UNIFICATION
# ============================================================
& {
    Write-Host "`n[MODULO] Network and DNS Unification (Adobe/Autodesk AI Ready)..." -ForegroundColor Cyan

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
    Write-Host "-> Network configured. AI (Adobe/CAD) servers unlocked via Google DNS." -ForegroundColor Green
}

# ============================================================
# BLOCK 5b: NETWORK ADVANCED TWEAKS & WiFi OPTIMIZER
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
    Write-Host "   SMB: Optimized (IRPStack 32, no SharingViolation, autodisconnect OFF)." -ForegroundColor Gray

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
    # TCP/IP PARAMETERS - connection optimization
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
    Write-Host ("   TcpAckFrequency/NoDelay: applied on {0} interfaces." -f $count) -ForegroundColor Gray

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
    # PSCHED QoS - no bandwidth reserve
    # --------------------------------------------------------
    $PschedPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
    if (!(Test-Path $PschedPath)) { New-Item -Path $PschedPath -Force | Out-Null }
    Set-ItemProperty -Path $PschedPath -Name "NonBestEffortLimit" -Value 0 -Force
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "Psched" -ErrorAction SilentlyContinue
    Write-Host "   Psched QoS: bandwidth reserve reset." -ForegroundColor Gray

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
        Write-Host "   WiFi: 5GHz preferred, power saving OFF, minimal roaming, 512 buffer." -ForegroundColor Gray
    } else {
        Write-Host "   WiFi: No cards detected - optimization skipped." -ForegroundColor Yellow
    }

    Write-Host "-> Network Advanced Tweaks & WiFi Optimizer completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 6: NETWORK OPTIMIZATION & KERNEL TUNING
# ============================================================
& {
    Write-Host "`n[MODULO] Network Optimization & Kernel Tuning..." -ForegroundColor Cyan

    $TcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-ItemProperty -Path $TcpPath -Name "TcpAckFrequency"    -Value 1 -Force
    Set-ItemProperty -Path $TcpPath -Name "TCPNoDelay"         -Value 1 -Force
    Set-ItemProperty -Path $TcpPath -Name "EnableRSS"          -Value 1 -Force
    Set-ItemProperty -Path $TcpPath -Name "DisableTaskOffload" -Value 0 -Force

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "NoNameReleaseOnDemand" -Value 1 -Force

    & bcdedit.exe /set "{current}" nx OptOut        2>$null
    & bcdedit.exe /set "{current}" bootmenupolicy   legacy 2>$null

    # PRO: hypervisorlaunchtype conditional
    # If Hyper-V active (WSL2/Sandbox) -> preserve, otherwise set off
    if (-not $script:HyperVState) {
        & bcdedit.exe /set "{current}" hypervisorlaunchtype off 2>$null
        Write-Host "   hypervisorlaunchtype: OFF (Hyper-V not active)." -ForegroundColor Gray
    } else {
        Write-Host "   hypervisorlaunchtype: PRESERVED (Hyper-V active - WSL2/Sandbox)." -ForegroundColor Yellow
    }

    # PRO: UAC = 1 preserved - required for RDP consent and Pro shell behavior
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -Force
    Write-Host "   UAC: preserved (1) - required for RDP and Pro shell." -ForegroundColor Gray
    & ipconfig /flushdns | Out-Null

    Write-Host "-> Tuning applied. Device & Internet connectivity PRESERVED." -ForegroundColor Green
}

# ============================================================
# BLOCK 7: EDGE/COPILOT PURGE & WEBVIEW2 READINESS
# ============================================================
& {
    Write-Host "`n[MODULO] Edge Armoring & Copilot Removal..." -ForegroundColor Yellow

    # Copilot Removal - build 26100 Win11 Home
    Write-Host "-> Deleting Copilot packages..." -ForegroundColor Gray
    # Remove all existing Copilot packages (name varies by version)
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -match "Copilot" } | 
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -match "Copilot" } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    # Fallback DISM per build 26100
    dism.exe /online /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Windows.Ai.Copilot.App_1.0.3.0_neutral_~_8wekyb3d8bbwe 2>$null | Out-Null
    dism.exe /online /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Copilot_1.0.0.0_neutral_~_8wekyb3d8bbwe 2>$null | Out-Null

    $CopilotPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (!(Test-Path $CopilotPol)) { New-Item -Path $CopilotPol -Force | Out-Null }
    Set-ItemProperty -Path $CopilotPol -Name "TurnOffWindowsCopilot" -Value 1 -Force
    Set-ItemProperty -Path $CopilotPol -Name "TurnOffCopilot" -Value 1 -Force -ErrorAction SilentlyContinue

    # Edge Copilot/Sidebar: explicit block (copilot often reappears from here)
    $EdgePolMain = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (!(Test-Path $EdgePolMain)) { New-Item -Path $EdgePolMain -Force | Out-Null }
    Set-ItemProperty -Path $EdgePolMain -Name "HubsSidebarEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $EdgePolMain -Name "StandaloneHubsSidebarEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $EdgePolMain -Name "CopilotPageContext" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $EdgePolMain -Name "EdgeEntraCopilotPageContext" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $EdgePolMain -Name "ShowCopilotButton" -Value 0 -Force -ErrorAction SilentlyContinue
    Invoke-CopilotHardBlock

    # Edge Reinstall Blocked
    $EdgeUpdate = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate"
    if (!(Test-Path $EdgeUpdate)) { New-Item -Path $EdgeUpdate -Force | Out-Null }
    Set-ItemProperty -Path $EdgeUpdate -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Force

    $EdgePol = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
    if (!(Test-Path $EdgePol)) { New-Item -Path $EdgePol -Force | Out-Null }
    Set-ItemProperty -Path $EdgePol -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Force

    # Edge Services disabled (WebView2 remains functional)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate"  -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue

    # Edge Task Cleanup
    Invoke-SchtasksQuiet '/Delete /TN "MicrosoftEdgeUpdateTaskMachineCore" /F'
    Invoke-SchtasksQuiet '/Delete /TN "MicrosoftEdgeUpdateTaskMachineUA" /F'

    Write-Host "-> Edge/Copilot rimossi e blindati. WebView2 integro." -ForegroundColor Green
}

# ============================================================
# BLOCK 8: TELEMETRY & DATA COLLECTION
# ============================================================
& {
    Write-Host "`n[MODULO] Disabling Telemetry & WerSvc..." -ForegroundColor Yellow

    Stop-Service -Name "DiagTrack"       -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "WerSvc"          -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack"        -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"           -Name "Start" -Value 4 -Force

    # Windows AI services - introduced in build 26100+ (not present on older builds)
    $AIServices = @("WSAIFabricSvc","AIFabricSvc","WindowsAIService","WinAIFabric")
    foreach ($aiSvc in $AIServices) {
        $aiPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$aiSvc"
        if (Test-Path $aiPath) {
            Stop-Service -Name $aiSvc -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $aiPath -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
            Write-Host "   AI service disabled: $aiSvc" -ForegroundColor Gray
        }
    }

    # Clear recovery actions - prevent Windows auto-restart of telemetry services
    foreach ($ts in @("DiagTrack","dmwappushservice","WerSvc")) {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ts" -Name "FailureActions" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ts" -Name "FailureActionsOnNonCrashFailures" -ErrorAction SilentlyContinue
    }
    Write-Host "   Recovery actions cleared on telemetry services." -ForegroundColor Gray

    $WerPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
    if (!(Test-Path $WerPol)) { New-Item -Path $WerPol -Force | Out-Null }
    Set-ItemProperty -Path $WerPol -Name "Disabled" -Value 1 -Force

    Write-Host "-> Telemetry and Error Reporting eliminated." -ForegroundColor Green
}

# ============================================================
# BLOCK 9: TELEMETRY GHOST TRIGGERS
# Win11 Home: added anti-reactivation policies and tasks
# ============================================================
& {
    Write-Host "`n[MODULO] Total Telemetry Clearing & Ghost Triggers..." -ForegroundColor Red

    $TelPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (!(Test-Path $TelPolicy)) { New-Item -Path $TelPolicy -Force | Out-Null }
    Set-ItemProperty -Path $TelPolicy -Name "AllowTelemetry" -Value 0 -Force
    Set-ItemProperty -Path $TelPolicy -Name "MaxTelemetryAllowed" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $TelPolicy -Name "DisableTelemetryOptInSettingsUx" -Value 1 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $TelPolicy -Name "DoNotShowFeedbackNotifications" -Value 1 -Force -ErrorAction SilentlyContinue

    $CEIPPath = "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"
    if (!(Test-Path $CEIPPath)) { New-Item -Path $CEIPPath -Force | Out-Null }
    Set-ItemProperty -Path $CEIPPath -Name "CEIPEnable" -Value 0 -Force -ErrorAction SilentlyContinue

    $AppCompatPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
    if (!(Test-Path $AppCompatPath)) { New-Item -Path $AppCompatPath -Force | Out-Null }
    Set-ItemProperty -Path $AppCompatPath -Name "AITEnable" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $AppCompatPath -Name "DisableInventory" -Value 1 -Force -ErrorAction SilentlyContinue

    # Ghost trigger elimination - extended for Pro
    # Pro has more trigger-enabled services than Home
    $triggerSvcs = @(
        "DiagTrack","WerSvc","dmwappushservice",   # telemetry core
        "CDPSvc","CDPUserSvc",                      # Connected Devices Platform
        "MapsBroker","lfsvc",                       # Maps and geolocation
        "WpnService","WpnUserService",              # Push notifications
        "PimIndexMaintenanceSvc","UnistoreSvc","UserDataSvc",  # Personal data
        "DmEnrollmentSvc","EntAppSvc","SCPolicySvc",           # Enterprise/Pro specific
        "WSAIFabricSvc","AIFabricSvc",              # AI/Copilot build 26100+
        "DoSvc","UsoSvc","SsdpDiscovery"            # Delivery/Update/SSDP
    )
    foreach ($t in $triggerSvcs) {
        & sc.exe triggerinfo $t delete 2>$null | Out-Null
    }
    Write-Host "   SCM trigger registrations: deleted (Pro extended ghost prevention)." -ForegroundColor Gray

    Stop-Service -Name "DiagTrack"        -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "WerSvc"           -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack"        -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "Start" -Value 4 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WerSvc"           -Name "Start" -Value 4 -Force

    # Windows AI services - introduced in build 26100+ (not present on older builds)
    $AIServices = @("WSAIFabricSvc","AIFabricSvc","WindowsAIService","WinAIFabric")
    foreach ($aiSvc in $AIServices) {
        $aiPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$aiSvc"
        if (Test-Path $aiPath) {
            Stop-Service -Name $aiSvc -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $aiPath -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
            Write-Host "   AI service disabled: $aiSvc" -ForegroundColor Gray
        }
    }

    # Scheduled tasks that can reactivate data collection on Home
    $TelemetryTasks = @(
        "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
        "Microsoft\Windows\Application Experience\ProgramDataUpdater"
        "Microsoft\Windows\Application Experience\StartupAppTask"
        "Microsoft\Windows\Autochk\Proxy"
        "Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
        "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
        "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
        "Microsoft\Windows\Feedback\Siuf\DmClient"
        "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    )
    foreach ($t in $TelemetryTasks) {
        Invoke-SchtasksQuiet "/change /tn `"$t`" /disable"
    }

    Write-Host "-> Telemetria tombata, trigger eliminati e task invasivi disattivati." -ForegroundColor Green
}

# ============================================================
# BLOCK 10: WINDOWS UPDATE & DRIVER BLOCK
# - wuauserv: Start=4 only without ACL (compatible with WU-Control)
# ============================================================
& {
    Write-Host "`n[MODULO] BLOCK Driver & Hard Lock Windows Update..." -ForegroundColor Yellow

    # 1. BLOCK DRIVER - create key if it doesn't exist
    $DriverSearchPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
    if (!(Test-Path $DriverSearchPath)) { New-Item -Path $DriverSearchPath -Force | Out-Null }
    Set-ItemProperty -Path $DriverSearchPath -Name "SearchOrderConfig" -Value 0 -Force

    $DevInstall = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (!(Test-Path $DevInstall)) { New-Item -Path $DevInstall -Force | Out-Null }
    Set-ItemProperty -Path $DevInstall -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Force

    # 2. WU CONFIGURATION (Target 24H2 & No Auto Update)
    $WU_AU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (!(Test-Path $WU_AU)) { New-Item -Path $WU_AU -Force | Out-Null }
    Set-ItemProperty -Path $WU_AU     -Name "AUOptions"              -Value 2      -Force
    Set-ItemProperty -Path $WU_AU     -Name "NoAutoUpdate"           -Value 1      -Force
    Set-ItemProperty -Path $DevInstall -Name "TargetReleaseVersion"     -Value 1      -Force
    Set-ItemProperty -Path $DevInstall -Name "TargetReleaseVersionInfo" -Value "24H2" -Force

    # BLOCK WU panel access - on Home the user could open it
    Set-ItemProperty -Path $DevInstall -Name "DisableWindowsUpdateAccess" -Value 1 -Force
    Set-ItemProperty -Path $DevInstall -Name "DisableWindowsUpdateAccessConf" -Value 1 -Force -ErrorAction SilentlyContinue

    # Block WU notifications in taskbar
    $WUNotif = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    Set-ItemProperty -Path $WUNotif -Name "SetDisableUXWUAccess" -Value 1 -Force -ErrorAction SilentlyContinue

    # PRO ONLY: Native GPO dual layer
    # Corresponds to gpedit.msc -> Computer Configuration -> Windows Update
    # Dual layer: registry policy + native GPO path = stronger enforcement
    $WUGPOPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (!(Test-Path $WUGPOPath)) { New-Item -Path $WUGPOPath -Force | Out-Null }
    Set-ItemProperty -Path $WUGPOPath -Name "WUServer"                  -Value "" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $WUGPOPath -Name "WUStatusServer"            -Value "" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $WUGPOPath -Name "UpdateServiceUrlAlternate" -Value "" -Force -ErrorAction SilentlyContinue
    Write-Host "   WU GPO dual layer (Pro native path): applied." -ForegroundColor Gray

    # Delivery Optimization: disable (stops using your bandwidth for other PCs)
    $DOPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
    if (!(Test-Path $DOPath)) { New-Item -Path $DOPath -Force | Out-Null }
    Set-ItemProperty -Path $DOPath -Name "DODownloadMode" -Value 0 -Force
    Write-Host "   Delivery Optimization: disabled (no bandwidth sharing)." -ForegroundColor Gray

    # 3. HARD LOCK: UsoSvc e WaaSMedicSvc
    # Start=4 + ACL Deny + Recovery Actions cleared
    foreach ($s in @("UsoSvc", "WaaSMedicSvc")) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$s" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        Set-SvcDenyAcl -SvcName $s
        # Clear recovery actions - prevents Windows auto-restart after crash
        $svcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$s"
        Remove-ItemProperty -Path $svcRegPath -Name "FailureActions" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $svcRegPath -Name "FailureActionsOnNonCrashFailures" -ErrorAction SilentlyContinue
        Write-Host "   Recovery actions cleared: $s" -ForegroundColor Gray
    }

    # 4. SOFT LOCK: wuauserv (Start=4 senza ACL Deny)
    # WU-Control usa sc.exe per riabilitarlo temporaneamente
    Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv" -Name "Start" -Value 4 -Force

    Write-Host "-> UsoSvc/WaaSMedicSvc: Hard Lock ACL applied." -ForegroundColor Green
    Write-Host "-> wuauserv: Soft Lock (Start=4, WU-Control compatible)." -ForegroundColor Green
    Write-Host "-> Windows Update SEALED. Protected drivers." -ForegroundColor Green
}

# ============================================================
# BLOCK 11: ERROR REPORTING & GAMING
# ============================================================
& {
    Write-Host "`n[MODULO] WER & Gaming Exclusions Application..." -ForegroundColor Cyan

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
# BLOCK 12: SEARCH, BING & CONTENT DELIVERY
# On Win11 Home 26100 the Search UI runs inside WebView2
# cloud-connected - blocked via policy + reg.exe
# ============================================================
& {
    Write-Host "`n[MODULO] Search Optimization and Content Delivery..." -ForegroundColor Yellow

    # --------------------------------------------------------
    # AVVISO per neofiti e utenti non esperti
    # --------------------------------------------------------
    # Unified Search/Everything info panel with choice
    Write-Host "`n+--------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoTitle) -ForegroundColor Cyan
    Write-Host "|                                                              |" -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine1) -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine2) -ForegroundColor Cyan
    Write-Host "|                                                              |" -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine3) -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine4) -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.EverythingLine2) -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.EverythingLine3) -ForegroundColor Cyan
    Write-Host "|                                                              |" -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine5) -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine6) -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine7) -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.SearchInfoLine9) -ForegroundColor Cyan
    Write-Host "|                                                              |" -ForegroundColor Cyan
    Write-Host ("|  {0,-60}|" -f $Lang.EverythingOptY) -ForegroundColor Green
    Write-Host ("|  {0,-60}|" -f $Lang.EverythingOptN) -ForegroundColor Yellow
    Write-Host "+--------------------------------------------------------------+" -ForegroundColor Cyan

    $useEverything = Read-Host "`n$($Lang.EverythingPrompt)"

    # WSearch: gestito qui in base alla scelta utente
    if ($useEverything -match "^[SsTtYyOo]$") {
        # Utente sceglie Everything - disabilita WSearch
        & sc.exe stop WSearch 2>$null | Out-Null
        Start-Sleep -Seconds 1
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        Write-Host "   $($Lang.EverythingYes)" -ForegroundColor Green
        Write-Host ""
        Write-Host "+--------------------------------------------------------------+" -ForegroundColor Green
        Write-Host ("|  {0,-60}|" -f $Lang.EverythingNote1) -ForegroundColor Green
        Write-Host ("|  {0,-60}|" -f $Lang.EverythingNote2) -ForegroundColor Green
        Write-Host ("|  {0,-60}|" -f $Lang.EverythingNote3) -ForegroundColor Green
        Write-Host "+--------------------------------------------------------------+" -ForegroundColor Green
        Write-Host ""
        Read-Host "  $($Lang.SearchInfoEnter)"
    } else {
        # Utente mantiene Windows Search
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" -Name "Start" -Value 3 -Force -ErrorAction SilentlyContinue
        Write-Host "   $($Lang.EverythingNo)" -ForegroundColor Yellow
    }

    # --------------------------------------------------------
    # SEARCH POLICY - BLOCK cloud e WebView2
    # Use reg.exe - compatible with SYSTEM context on Home
    # --------------------------------------------------------
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "DisableSearch"         /t REG_DWORD /d 1 /f 2>$null | Out-Null
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "ConnectedSearchUseWeb" /t REG_DWORD /d 0 /f 2>$null | Out-Null
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCloudSearch"      /t REG_DWORD /d 0 /f 2>$null | Out-Null
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana"          /t REG_DWORD /d 0 /f 2>$null | Out-Null
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "BingSearchEnabled"     /t REG_DWORD /d 0 /f 2>$null | Out-Null
    & reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "DisableWebSearch"      /t REG_DWORD /d 1 /f 2>$null | Out-Null
    & reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search"   /v "SearchboxTaskbarMode"  /t REG_DWORD /d 0 /f 2>$null | Out-Null
    Write-Host "   Search cloud and WebView2: blocked by policy." -ForegroundColor Gray

    # --------------------------------------------------------
    # SEARCH SETTINGS - PowerShell (for compatibility)
    # --------------------------------------------------------
    $SearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $SSettings  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
    $CDMan      = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $CDP        = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP"

    if (!(Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }
    Set-ItemProperty -Path $SearchPath -Name "SearchboxTaskbarMode"  -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $SearchPath -Name "BingSearchEnabled"     -Value 0 -Force -ErrorAction SilentlyContinue

    if (!(Test-Path $SSettings)) { New-Item -Path $SSettings -Force | Out-Null }
    Set-ItemProperty -Path $SSettings -Name "IsDynamicSearchBoxEnabled" -Value 0 -Force -ErrorAction SilentlyContinue

    if (!(Test-Path $CDMan)) { New-Item -Path $CDMan -Force | Out-Null }
    Set-ItemProperty -Path $CDMan -Name "SilentInstalledAppsEnabled" -Value 0 -Force -ErrorAction SilentlyContinue

    if (!(Test-Path $CDP)) { New-Item -Path $CDP -Force | Out-Null }
    Set-ItemProperty -Path $CDP -Name "CdpSessionUserOverride" -Value 0 -Force -ErrorAction SilentlyContinue

    # Build noop.exe if not present (compiles inline via csc.exe bundled with .NET Framework)
$NoopPath = "C:\Windows\System32\noop.exe"
if (-not (Test-Path $NoopPath)) {
    $cscPath = Get-ChildItem "C:\Windows\Microsoft.NET\Framework64" -Filter "csc.exe" -Recurse -ErrorAction SilentlyContinue |
               Sort-Object FullName -Descending |
               Select-Object -First 1 -ExpandProperty FullName
    if ($null -ne $cscPath) {
        $tmpSrc = Join-Path $env:TEMP "noop_src.cs"
        Set-Content -Path $tmpSrc -Value @'
using System;
class Noop { static int Main() { return 0; } }
'@ -Encoding UTF8 -Force
        & $cscPath /nologo /out:$NoopPath /target:exe /platform:x64 $tmpSrc 2>&1 | Out-Null
        Remove-Item $tmpSrc -ErrorAction SilentlyContinue
    }
}

# Block SearchApp.exe via IFEO if noop.exe is present
$IFEOSearch = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SearchApp.exe"
if (!(Test-Path $IFEOSearch)) { New-Item -Path $IFEOSearch -Force | Out-Null }
if (Test-Path $NoopPath) {
    Set-ItemProperty -Path $IFEOSearch -Name "Debugger" -Value $NoopPath -Force
    Write-Host "   SearchApp.exe: bloccato via IFEO." -ForegroundColor Gray
}

    Write-Host "-> Ricerca cloud, Bing, Content Delivery e CDP blindati." -ForegroundColor Green
}

# ============================================================
# BLOCK 13: UI CLASSIC & PERFORMANCE TWEAKS
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

    Write-Host "-> UI changes recorded (Active on reboot)." -ForegroundColor Green
}

# ============================================================
# BLOCK 14: GAMING, INPUT LAG & UI OPTIMIZATION
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

    # Exception: Snipping Tool needs background access + toast notifications
    # to capture after selection AND show "Screenshot saved" popup
    $SnipPath = "$BGApp\Microsoft.ScreenSketch_8wekyb3d8bbwe"
    if (!(Test-Path $SnipPath)) { New-Item -Path $SnipPath -Force | Out-Null }
    Set-ItemProperty -Path $SnipPath -Name "Disabled"       -Value 0 -Force
    Set-ItemProperty -Path $SnipPath -Name "DisabledByUser" -Value 0 -Force

    # Preserve Snipping Tool toast notifications (screenshot saved popup)
    $SnipNotifPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.ScreenSketch_8wekyb3d8bbwe!App"
    if (!(Test-Path $SnipNotifPath)) { New-Item -Path $SnipNotifPath -Force | Out-Null }
    Set-ItemProperty -Path $SnipNotifPath -Name "Enabled" -Value 1 -Force -ErrorAction SilentlyContinue

    # Enable automatic save to Screenshots folder (without manual Save dialog)
    $SnipAppPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ScreenCapture"
    if (!(Test-Path $SnipAppPath)) { New-Item -Path $SnipAppPath -Force | Out-Null }
    Set-ItemProperty -Path $SnipAppPath -Name "AutomaticallySaveScreenshots" -Value 1 -Force -ErrorAction SilentlyContinue

    # Also set via SnippingTool settings path (build 26100+ uses this path)
    $SnipSettingsPath = "HKCU:\Software\Microsoft\ScreenCapture"
    if (!(Test-Path $SnipSettingsPath)) { New-Item -Path $SnipSettingsPath -Force | Out-Null }
    Set-ItemProperty -Path $SnipSettingsPath -Name "AutomaticallySaveScreenshots" -Value 1 -Force -ErrorAction SilentlyContinue

    # Ensure Screenshots folder exists
    $screenshotsPath = "$env:USERPROFILE\Pictures\Screenshots"
    if (!(Test-Path $screenshotsPath)) {
        New-Item -Path $screenshotsPath -ItemType Directory -Force | Out-Null
    }

    # CaptureService: required by Snipping Tool (Windows.Graphics.Capture API)
    # Set to Manual trigger - starts automatically when Snipping Tool opens
    $capSvcs = Get-Service -Name "CaptureService*" -ErrorAction SilentlyContinue
    foreach ($capSvc in $capSvcs) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($capSvc.Name)" `
            -Name "Start" -Value 3 -Force -ErrorAction SilentlyContinue
    }

    Write-Host "   Snipping Tool: background + notifications + auto-save + CaptureService preserved." -ForegroundColor Gray

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

    Write-Host "-> UI and input optimizations recorded. Active on reboot." -ForegroundColor Green
}

# ============================================================
# BLOCK 15: HARDWARE PRIVACY & KERNEL TICK
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

    Write-Host "-> Privacy set and Kernel Latency optimized." -ForegroundColor Green
}

# ============================================================
# BLOCK 16: WORKSTATION CLEANUP (ADOBE, OFFICE, NVIDIA, AUTOCAD, ONLYOFFICE)
# ============================================================
& {
    Write-Host "`n[MODULO] Workstation Cleanup (Adobe, AutoCAD, Office, NVIDIA)..." -ForegroundColor Cyan

    $Hosts = "$env:SystemRoot\System32\drivers\etc\hosts"

    # --------------------------------------------------------
    # ADOBE — Auto-detect Licensed vs Portable
    # --------------------------------------------------------
    $isAdobeLicensed = $false
    if (Test-Path "C:\Program Files (x86)\Adobe\Adobe Creative Cloud\ACC\Creative Cloud.exe") { $isAdobeLicensed = $true }
    if (!$isAdobeLicensed) {
        $ags = Get-Service -Name "AGSService" -ErrorAction SilentlyContinue
        if ($ags -and $ags.StartType -ne "Disabled") { $isAdobeLicensed = $true }
    }
    if (!$isAdobeLicensed -and (Test-Path "C:\Program Files (x86)\Common Files\Adobe\OOBE\PDApp")) { $isAdobeLicensed = $true }
    $adobePresent = $isAdobeLicensed -or (Test-Path "C:\Program Files\Adobe") -or (Test-Path "C:\Program Files (x86)\Adobe")

    if ($adobePresent) {
        Write-Host ("   Adobe: {0}" -f (if ($isAdobeLicensed) { "LICENSED" } else { "PORTABLE" })) -ForegroundColor Gray
        foreach ($svc in @("AdobeUpdateService","AdobeARMservice","AdobeIPCBroker")) {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        }
        if ($isAdobeLicensed) {
            Set-Service "AGSService"           -StartupType Manual -ErrorAction SilentlyContinue
            Set-Service "AdobeActiveLUService" -StartupType Manual -ErrorAction SilentlyContinue
            Write-Host "   Adobe: AGSService preserved (Manual - licensed)." -ForegroundColor Gray
        } else {
            foreach ($svc in @("AGSService","AdobeActiveLUService")) {
                Stop-Service $svc -Force -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
            }
        }
        $adobeHosts = @("ardownload.adobe.com","ardownload2.adobe.com","agsservice.adobe.com")
        if (!$isAdobeLicensed) { $adobeHosts += @("genuine.adobe.com","lcs-cops.adobe.io","adobe-identity.adobe.com") }
        foreach ($h in $adobeHosts) {
            if (!(Select-String -Path $Hosts -Pattern $h -Quiet -ErrorAction SilentlyContinue)) {
                Add-Content -Path $Hosts -Value "`n127.0.0.1 $h" -ErrorAction SilentlyContinue
            }
        }
        foreach ($app in @(
            @{E="Photoshop.exe";C=3;I=3}, @{E="Illustrator.exe";C=3;I=3},
            @{E="AfterFX.exe";C=4;I=3},  @{E="Acrobat.exe";C=3;I=3},
            @{E="AcroRd32.exe";C=3;I=3}
        )) {
            $bk = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($app.E)"
            & reg.exe add $bk               -v "IoPriority"       -t REG_DWORD -d $app.I -f 2>$null | Out-Null
            & reg.exe add "$bk\PerfOptions" -v "CpuPriorityClass" -t REG_DWORD -d $app.C -f 2>$null | Out-Null
        }
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsMemoryUsage" -Value 2 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 1 -Force -ErrorAction SilentlyContinue
        $AdobeUpdateExe = "C:\Program Files (x86)\Common Files\Adobe\OOBE\PDApp\UWA\updater.exe"
        if (Test-Path $AdobeUpdateExe) {
            New-NetFirewallRule -DisplayName "Block Adobe Updater" -Direction Outbound -Program $AdobeUpdateExe -Action Block -ErrorAction SilentlyContinue | Out-Null
        }
        foreach ($t in @("AdobeGCInvoker-1.0","AdobeAAMUpdater-1.0","Adobe Acrobat Update Task","MicrosoftEdgeUpdateTaskMachineCore","MicrosoftEdgeUpdateTaskMachineUA")) {
            Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        }
        foreach ($v in @("AdobeGCInvoker-1.0","AdobeCCXProcess","CCXProcess","Adobe Creative Cloud")) {
            & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v $v /f 2>$null | Out-Null
        }
        $AdobeCRLog = "HKCU:\Software\Adobe\CommonFiles\CRLog"
        if (!(Test-Path $AdobeCRLog)) { New-Item -Path $AdobeCRLog -Force | Out-Null }
        Set-ItemProperty -Path $AdobeCRLog -Name "NeverAsk" -Value 1 -Force -ErrorAction SilentlyContinue
        $AdobeAR = "HKCU:\Software\Adobe\Acrobat Reader"
        if (!(Test-Path $AdobeAR)) { New-Item -Path $AdobeAR -Force | Out-Null }
        Set-ItemProperty -Path $AdobeAR -Name "bUpdater" -Value 0 -Force -ErrorAction SilentlyContinue
        Write-Host "   Adobe cleanup: DONE." -ForegroundColor Green
    }

    # --------------------------------------------------------
    # AUTOCAD / AUTODESK — Auto-detect Licensed vs Portable
    # --------------------------------------------------------
    $isAutodeskLicensed = $false
    if (Test-Path "C:\Program Files\Autodesk\AdskLicensingService") { $isAutodeskLicensed = $true }
    if (!$isAutodeskLicensed) {
        $adsk = Get-Service -Name "AdskLicensingService" -ErrorAction SilentlyContinue
        if ($adsk -and $adsk.StartType -ne "Disabled") { $isAutodeskLicensed = $true }
    }
    foreach ($p in @("C:\Program Files\Autodesk\AutoCAD 2024","C:\Program Files\Autodesk\AutoCAD 2025","C:\Program Files\Autodesk\AutoCAD 2026","C:\Program Files\Autodesk\Revit 2024","C:\Program Files\Autodesk\Revit 2025","C:\Program Files\Autodesk\Revit 2026")) {
        if (Test-Path $p) { $isAutodeskLicensed = $true; break }
    }
    $autodeskPresent = $isAutodeskLicensed -or (Test-Path "C:\Program Files\Autodesk")

    if ($autodeskPresent) {
        Write-Host ("   Autodesk: {0}" -f (if ($isAutodeskLicensed) { "LICENSED" } else { "PORTABLE" })) -ForegroundColor Gray
        Stop-Service "AutodeskDesktopAppService" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\AutodeskDesktopAppService" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        foreach ($svc in @("AdAppMgrSvc","AdskGenuineService","AdskLicensingService")) {
            if ($isAutodeskLicensed) {
                Set-Service $svc -StartupType Manual -ErrorAction SilentlyContinue
            } else {
                Stop-Service $svc -Force -ErrorAction SilentlyContinue
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
            }
        }
        $adskHosts = @("dpm.autodesk.com","genuine-software.autodesk.com","registeronce.autodesk.com")
        if (!$isAutodeskLicensed) { $adskHosts += @("clm.autodesk.com","registerproduct.autodesk.com","activation.autodesk.com","lic.autodesk.com") }
        foreach ($h in $adskHosts) {
            if (!(Select-String -Path $Hosts -Pattern $h -Quiet -ErrorAction SilentlyContinue)) {
                Add-Content -Path $Hosts -Value "`n127.0.0.1 $h" -ErrorAction SilentlyContinue
            }
        }
        foreach ($app in @(
            @{E="acad.exe";C=3;I=3}, @{E="Revit.exe";C=4;I=3},
            @{E="3dsmax.exe";C=4;I=3}, @{E="3dsmaxcmd.exe";C=4;I=3},
            @{E="AdskLicensingAgent.exe";C=1;I=1}
        )) {
            $bk = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($app.E)"
            & reg.exe add $bk               -v "IoPriority"       -t REG_DWORD -d $app.I -f 2>$null | Out-Null
            & reg.exe add "$bk\PerfOptions" -v "CpuPriorityClass" -t REG_DWORD -d $app.C -f 2>$null | Out-Null
        }
        foreach ($t in @("AutodeskDesktopApp","AdskGenuineServiceMonitor","AdobeGCInvoker-1.0")) {
            Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        }
        & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Autodesk Desktop App" /f 2>$null | Out-Null
        $ADSKPol = "HKLM:\SOFTWARE\Autodesk\MC3"
        if (!(Test-Path $ADSKPol)) { New-Item -Path $ADSKPol -Force | Out-Null }
        Set-ItemProperty -Path $ADSKPol -Name "ADAOptIn" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $ADSKPol -Name "ADAReady" -Value 0 -Force -ErrorAction SilentlyContinue
        Write-Host "   Autodesk cleanup: DONE." -ForegroundColor Green
    }

    # --------------------------------------------------------
    # OFFICE — Auto-detect Licensed/M365 vs Portable
    # --------------------------------------------------------
    $isOfficeLicensed = $false
    if (Test-Path "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe") { $isOfficeLicensed = $true }
    if (!$isOfficeLicensed) {
        $ctr = Get-Service -Name "ClickToRunSvc" -ErrorAction SilentlyContinue
        if ($ctr -and $ctr.StartType -ne "Disabled") { $isOfficeLicensed = $true }
    }
    if (!$isOfficeLicensed -and ((Test-Path "C:\Program Files\Microsoft Office\root\Office16") -or (Test-Path "C:\Program Files (x86)\Microsoft Office\root\Office16"))) { $isOfficeLicensed = $true }
    $officePresent = $isOfficeLicensed -or (Test-Path "C:\Program Files\Microsoft Office") -or (Test-Path "C:\Program Files (x86)\Microsoft Office")

    if ($officePresent) {
        Write-Host ("   Office: {0}" -f (if ($isOfficeLicensed) { "LICENSED/M365" } else { "PORTABLE" })) -ForegroundColor Gray
        if ($isOfficeLicensed) {
            Set-Service "ClickToRunSvc" -StartupType Manual -ErrorAction SilentlyContinue
            Stop-Service "ClickToRunSvc" -Force -ErrorAction SilentlyContinue
        } else {
            Stop-Service "ClickToRunSvc" -Force -ErrorAction SilentlyContinue
            Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\ClickToRunSvc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        }
        Stop-Service "OfficeInventoryService" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\OfficeInventoryService" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        $OffPol = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy"
        if (!(Test-Path $OffPol)) { New-Item -Path $OffPol -Force | Out-Null }
        Set-ItemProperty -Path $OffPol -Name "sendtelemetry"     -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $OffPol -Name "disconnectedstate" -Value (if ($isOfficeLicensed) { 0 } else { 1 }) -Force -ErrorAction SilentlyContinue
        $OffCommon = "HKLM:\SOFTWARE\Policies\Microsoft\office\common"
        if (!(Test-Path $OffCommon)) { New-Item -Path $OffCommon -Force | Out-Null }
        Set-ItemProperty -Path $OffCommon -Name "qsh_enabled" -Value 0 -Force -ErrorAction SilentlyContinue
        $OffPath = "HKCU:\Software\Microsoft\Office\Common"
        if (!(Test-Path $OffPath)) { New-Item -Path $OffPath -Force | Out-Null }
        Set-ItemProperty -Path $OffPath -Name "UseOnlineContent" -Value 0 -Force
        $offHosts = @("telemetry.office.com","telemetry.microsoft.com","watson.microsoft.com","watson.telemetry.microsoft.com")
        if (!$isOfficeLicensed) { $offHosts += @("officeclient.microsoft.com","activation.sls.microsoft.com","ols.officeapps.live.com") }
        foreach ($h in $offHosts) {
            if (!(Select-String -Path $Hosts -Pattern $h -Quiet -ErrorAction SilentlyContinue)) {
                Add-Content -Path $Hosts -Value "`n127.0.0.1 $h" -ErrorAction SilentlyContinue
            }
        }
        foreach ($app in @(
            @{E="WINWORD.EXE";C=3;I=3}, @{E="EXCEL.EXE";C=3;I=3},
            @{E="POWERPNT.EXE";C=3;I=3}, @{E="OUTLOOK.EXE";C=3;I=3},
            @{E="MSACCESS.EXE";C=3;I=3}
        )) {
            $bk = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($app.E)"
            & reg.exe add $bk               -v "IoPriority"       -t REG_DWORD -d $app.I -f 2>$null | Out-Null
            & reg.exe add "$bk\PerfOptions" -v "CpuPriorityClass" -t REG_DWORD -d $app.C -f 2>$null | Out-Null
        }
        if (!$isOfficeLicensed) {
            $OfficeCTR = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
            if (Test-Path $OfficeCTR) {
                New-NetFirewallRule -DisplayName "Block Office CTR Cloud" -Direction Outbound -Program $OfficeCTR -Action Block -ErrorAction SilentlyContinue | Out-Null
            }
        }
        foreach ($t in @("OfficeTelemetryAgentLogOn","OfficeTelemetryAgentFallBack","Office Feature Updates","Office Feature Updates Logon")) {
            Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Host "   Office cleanup: DONE." -ForegroundColor Green
    }

    # --------------------------------------------------------
    # ONLYOFFICE PORTABLE — Auto-detect
    # --------------------------------------------------------
    $realUser    = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName -replace ".*\\", ""
    $realProfile = "C:\Users\$realUser"
    $ooExe = $null
    foreach ($path in @(
        "$realProfile\Programmi\ONLYOFFICEPortable\ONLYOFFICEPortable.exe",
        "$realProfile\Desktop\ONLYOFFICEPortable\ONLYOFFICEPortable.exe",
        "C:\PortableApps\ONLYOFFICEPortable\ONLYOFFICEPortable.exe",
        "D:\PortableApps\ONLYOFFICEPortable\ONLYOFFICEPortable.exe"
    )) { if (Test-Path $path) { $ooExe = $path; break } }
    if (!$ooExe) {
        $found = Get-ChildItem -Path $realProfile -Recurse -Filter "ONLYOFFICEPortable.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $ooExe = $found.FullName }
    }
    if ($ooExe) {
        $ooDataDir = Split-Path $ooExe
        $settingsFile = @("$ooDataDir\Data\settings.json","$ooDataDir\data\settings.json","$ooDataDir\settings.json") |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($settingsFile) {
            try {
                $s = Get-Content $settingsFile -Raw | ConvertFrom-Json
                foreach ($k in @("checkForUpdates","statisticsEnabled","updateNotification","crashReporterEnabled","maxRecentFilesCount")) {
                    $s | Add-Member -NotePropertyName $k -NotePropertyValue 0 -Force
                }
                $s | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
            } catch {}
        }
        foreach ($app in @(
            @{E="DesktopEditors.exe";C=3;I=3}, @{E="ONLYOFFICEPortable.exe";C=3;I=3},
            @{E="editors.exe";C=3;I=3},         @{E="converter.exe";C=4;I=3},
            @{E="spellcheck.exe";C=2;I=2},       @{E="SumatraPDF.exe";C=3;I=3}
        )) {
            $bk = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($app.E)"
            & reg.exe add $bk               -v "IoPriority"       -t REG_DWORD -d $app.I -f 2>$null | Out-Null
            & reg.exe add "$bk\PerfOptions" -v "CpuPriorityClass" -t REG_DWORD -d $app.C -f 2>$null | Out-Null
        }
        foreach ($h in @("download.onlyoffice.com","analytics.onlyoffice.com","update.onlyoffice.com","crash.onlyoffice.com")) {
            if (!(Select-String -Path $Hosts -Pattern $h -Quiet -ErrorAction SilentlyContinue)) {
                Add-Content -Path $Hosts -Value "`n127.0.0.1 $h" -ErrorAction SilentlyContinue
            }
        }
        Write-Host "   OnlyOffice cleanup: DONE." -ForegroundColor Green
    }

    # --------------------------------------------------------
    # NVIDIA — Overlay + Telemetry
    # --------------------------------------------------------
    $NVPath = "HKCU:\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS"
    if (!(Test-Path $NVPath)) { New-Item -Path $NVPath -Force | Out-Null }
    Set-ItemProperty -Path $NVPath -Name "EnableOverlay" -Value 0 -Force -ErrorAction SilentlyContinue
    $nvcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NvTelemetryContainer"
    if (Test-Path $nvcPath) {
        Stop-Service "NvTelemetryContainer" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $nvcPath -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    }
    $nvTmPath = "HKLM:\SOFTWARE\NVIDIA Corporation\NvTmMon"
    if (Test-Path $nvTmPath) {
        Set-ItemProperty -Path $nvTmPath -Name "DisableMon" -Value 1 -Force -ErrorAction SilentlyContinue
    }
    Disable-ScheduledTask -TaskName "NvBackend" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "   NVIDIA: overlay + telemetry disabled." -ForegroundColor Gray

    # EdgeUpdate Firewall
    $EdgeUpdateExe = "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
    if (Test-Path $EdgeUpdateExe) {
        New-NetFirewallRule -DisplayName "Block EdgeUpdate Core" -Direction Outbound -Program $EdgeUpdateExe -Action Block -ErrorAction SilentlyContinue | Out-Null
        Write-Host "   Firewall: EdgeUpdate blocked." -ForegroundColor Gray
    }

    Write-Host "-> Workstation Suite cleanup complete." -ForegroundColor Green
}
# ============================================================
# BLOCK 17: CLEANUP, DEFENDER, SMARTSCREEN
# On Win11 Home Defender has Tamper Protection active
# Mandatory sequence: disable TP → disable Defender → SmartScreen
# ============================================================
& {
    Write-Host "`n[MODULO] Defender, SmartScreen & Cleanup..." -ForegroundColor Yellow

    # --------------------------------------------------------
    # STEP 1: Disable Tamper Protection via Registry
    # Required before making any changes to Defender on Home
    # --------------------------------------------------------
    $TPPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
    if (!(Test-Path $TPPath)) { New-Item -Path $TPPath -Force | Out-Null }
    Set-ItemProperty -Path $TPPath -Name "TamperProtection" -Value 4 -Force -ErrorAction SilentlyContinue
    Write-Host "   Tamper Protection: Disabled." -ForegroundColor Gray

    # --------------------------------------------------------
    # STEP 2: Disable Defender Real-Time Protection
    # --------------------------------------------------------
    $DefPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (!(Test-Path $DefPath)) { New-Item -Path $DefPath -Force | Out-Null }
    Set-ItemProperty -Path $DefPath -Name "DisableAntiSpyware"    -Value 1 -Force
    Set-ItemProperty -Path $DefPath -Name "DisableAntiVirus"      -Value 1 -Force -ErrorAction SilentlyContinue

    $RTPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
    if (!(Test-Path $RTPath)) { New-Item -Path $RTPath -Force | Out-Null }
    Set-ItemProperty -Path $RTPath -Name "DisableRealtimeMonitoring"  -Value 1 -Force
    Set-ItemProperty -Path $RTPath -Name "DisableBehaviorMonitoring"  -Value 1 -Force
    Set-ItemProperty -Path $RTPath -Name "DisableOnAccessProtection"  -Value 1 -Force
    Set-ItemProperty -Path $RTPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Force

    # Disable via MpPreference (official API)
    Set-MpPreference -DisableRealtimeMonitoring $true    -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true    -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen   $true    -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection     $true    -ErrorAction SilentlyContinue
    Set-MpPreference -MAPSReporting             0        -ErrorAction SilentlyContinue
    Set-MpPreference -SubmitSamplesConsent      2        -ErrorAction SilentlyContinue
    Write-Host "   Defender Real-Time Protection: Disabled." -ForegroundColor Gray

    # --------------------------------------------------------
    # STEP 3: SecurityHealthService
    # --------------------------------------------------------
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SecurityHealth"      /f 2>$null | Out-Null
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeUpdate" /f 2>$null | Out-Null
    Stop-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Write-Host "   SecurityHealthService: Disabled." -ForegroundColor Gray

    # --------------------------------------------------------
    # STEP 4: CDPSvc / CDPUserSvc
    # --------------------------------------------------------
    & sc.exe triggerinfo CDPSvc delete | Out-Null
    $cdpUser = Get-Service -Name "CDPUserSvc_*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cdpUser) {
        & sc.exe triggerinfo $cdpUser.Name delete | Out-Null
        Stop-Service -Name $cdpUser.Name -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $cdpUser.Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host ("   CDPUserSvc trigger eliminato: {0}" -f $cdpUser.Name) -ForegroundColor Gray
    }
    Stop-Service -Name "CDPSvc" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CDPSvc"     -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
    $CDPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $CDPath)) { New-Item -Path $CDPath -Force | Out-Null }
    Set-ItemProperty -Path $CDPath -Name "EnableCdp" -Value 0 -Force
    Set-ItemProperty -Path $CDPath -Name "EnableMmx" -Value 0 -Force

    # --------------------------------------------------------
    # STEP 5: SmartScreen - after disabling Defender
    # --------------------------------------------------------
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Force -ErrorAction SilentlyContinue
    $SSPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $SSPol)) { New-Item -Path $SSPol -Force | Out-Null }
    Set-ItemProperty -Path $SSPol -Name "EnableSmartScreen"     -Value 0      -Force
    Set-ItemProperty -Path $SSPol -Name "ShellSmartScreenLevel" -Value "Warn" -Force
    $AppHostPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppHost"
    if (!(Test-Path $AppHostPol)) { New-Item -Path $AppHostPol -Force | Out-Null }
    Set-ItemProperty -Path $AppHostPol -Name "EnableWebContentEvaluation" -Value 0 -Force
    $EdgeSSPol = "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter"
    if (!(Test-Path $EdgeSSPol)) { New-Item -Path $EdgeSSPol -Force | Out-Null }
    Set-ItemProperty -Path $EdgeSSPol -Name "EnabledV9"      -Value 0 -Force
    Set-ItemProperty -Path $EdgeSSPol -Name "PreventOverride" -Value 0 -Force
    Stop-Process -Name "smartscreen" -Force -ErrorAction SilentlyContinue
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\AppID\SmartScreenSpecific" /disable'

    # Task WER
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Error Reporting\CleanupTemporaryState" /disable'

    # Critical Services on Automatic
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CryptSvc" -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\RpcSs"    -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog" -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Schedule" -Name "Start" -Value 2 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService" -Name "Start" -Value 3 -Force -ErrorAction SilentlyContinue

    # CrossDeviceResume - BLOCK via Firewall
    $CrossDeviceExe = "C:\WINDOWS\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\CrossDeviceResume.exe"
    if (Test-Path $CrossDeviceExe) {
        $existingRule = Get-NetFirewallRule -DisplayName "Block CrossDeviceResume" -ErrorAction SilentlyContinue
        if (!$existingRule) {
            New-NetFirewallRule -DisplayName "Block CrossDeviceResume" `
                -Direction Outbound -Program $CrossDeviceExe -Action Block `
                -ErrorAction SilentlyContinue | Out-Null
        }
    }
    $IFEOPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\CrossDeviceResume.exe"
    if (Test-Path $IFEOPath) { Remove-Item -Path $IFEOPath -Force -ErrorAction SilentlyContinue }
    Stop-Process -Name "CrossDeviceResume" -Force -ErrorAction SilentlyContinue

    # PopupKiller Residue Cleaning
    Unregister-ScheduledTask -TaskName "PopupKiller" -Confirm:$false -ErrorAction SilentlyContinue
    Stop-Process -Name "PopupKiller" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\System32\PopupKiller.exe" -Force -ErrorAction SilentlyContinue

    Write-Host "-> Defender disabled. SmartScreen OFF. Cleanup completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 17b:AUDIO VOLUME & INTERNET CONNECTION PROTECTION
# Ensures that AudioSrv, AudioEndpointBuilder and services
# essential network services remain active and protected
# ============================================================
& {
    Write-Host "`n[MODULO] Protect Audio Volume & Internet Connections..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # AUDIO: Force Automatic and start services
    # --------------------------------------------------------
    foreach ($svc in @("AudioSrv", "AudioEndpointBuilder")) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 2 -Force -ErrorAction SilentlyContinue
        Start-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Host "   $svc : Automatico + avviato." -ForegroundColor Gray
    }

    # Re-register volume flyout (SndVolSSO) for StartAllBack compatibility
    & regsvr32.exe /s "C:\Windows\System32\SndVolSSO.dll"
    Write-Host "   SndVolSSO.dll re-registered." -ForegroundColor Gray

    # --------------------------------------------------------
    # NETWORK: essential services on Automatic
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
            Write-Host "   $($entry.Key) : configured and started." -ForegroundColor Gray
        }
    }

    # Reset tray icon cache (prevent ghost volume icon)
    $TrayPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify"
    Remove-ItemProperty -Path $TrayPath -Name "IconStreams"    -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $TrayPath -Name "PastIconsStream" -ErrorAction SilentlyContinue
    Write-Host "   Cache icone tray resettata." -ForegroundColor Gray

    Write-Host "-> Protect Audio Volume and Internet Connections." -ForegroundColor Green
}

# ============================================================
# BLOCK 18: CLEANUP AUTORUN, TEMP & INVASIVE TASKS
# ============================================================
& {
    Write-Host "`n[MODULO] Cleaning Autorun, Temp and Invasive Tasks..." -ForegroundColor Yellow

    $KillList = "AcroRd32","WINWORD","EXCEL","OUTLOOK","chrome","brave","firefox","msedge"
    Stop-Process -Name $KillList -Force -ErrorAction SilentlyContinue

    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AcroRd32"   /f 2>$null | Out-Null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "chrome.exe" /f 2>$null | Out-Null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "msedge.exe" /f 2>$null | Out-Null
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Everything" /f 2>$null | Out-Null

    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Application Experience\ProgramDataUpdater" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /disable'

    Remove-Item -Path "$env:TEMP\*"                                              -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\History\*"            -Recurse -Force -ErrorAction SilentlyContinue

    # EdgeUpdate hard block (vaccine)
    $EdgeUpPath = "$env:LOCALAPPDATA\Microsoft\EdgeUpdate"
    if (Test-Path $EdgeUpPath) { Remove-Item -Path $EdgeUpPath -Force -Recurse -ErrorAction SilentlyContinue }
    New-Item -Path $EdgeUpPath -ItemType Directory -Force | Out-Null
    & attrib.exe +R +H +S $EdgeUpPath 2>$null

    Write-Host "-> Task and Temporary File Cleanup completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 19: DEFAULT USER TEMPLATE & HARDENING
# ============================================================
& {
    Write-Host "`n[MODULO] Propagate Optimizations to New Users (.DEFAULT)..." -ForegroundColor Cyan

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

    # Firewall active to block telemetry
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\MpsSvc" -Name "Start" -Value 2 -Force
    Start-Service -Name "MpsSvc" -ErrorAction SilentlyContinue

    Write-Host "-> Template .DEFAULT configured with Titanium standard." -ForegroundColor Green
}

# ============================================================
# BLOCK 20: FINAL TASK SCHEDULER PURGE
# ============================================================
& {
    Write-Host "`n[MODULO] Final Cleanup Task Scheduler..." -ForegroundColor Yellow

    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Error Reporting\Consent" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Application Experience\MareBackup" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\NetCeip\BindGatherer" /disable'

    # Task Defender - on Win11 Home they are active and protected
    # Disabled after lowering Tamper Protection in BLOCK 17
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Defender\Windows Defender Cleanup" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" /disable'
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Windows Defender\Windows Defender Verification" /disable'

    Write-Host "-> Task Scheduler cleaned up." -ForegroundColor Green
}

# ============================================================
# BLOCK 22: SSD/NVMe OPTIMIZATION
# Optimize NTFS and OS behavior for solid-state storage
# Philosophy: Eliminate unnecessary writing, preserve longevity
# ============================================================
& {
    Write-Host "`n[MODULO] SSD/NVMe Optimization..." -ForegroundColor Cyan

    # TRIM - deve essere sempre ON su SSD
    & fsutil.exe behavior set DisableDeleteNotify 0 2>$null
    Write-Host "   TRIM: ON (preserves SSD longevity)." -ForegroundColor Gray

    # Last Access Timestamp - writing at every file read, useless
    & fsutil.exe behavior set disablelastaccess 1 2>$null
    Write-Host "   Last Access Timestamp: OFF." -ForegroundColor Gray

    # 8.3 filename generation - legacy DOS, no modern app uses it
    & fsutil.exe behavior set disable8dot3 1 2>$null
    Write-Host "   8.3 Name Creation: OFF." -ForegroundColor Gray

    # Ibernazione - frees up space equivalent to the installed RAM
    & powercfg.exe /hibernate off 2>$null
    Write-Host "   Hibernate: OFF (libera $(Get-CimInstance Win32_ComputerSystem | ForEach-Object { [math]::Round($_.TotalPhysicalMemory/1GB) }) GB on disk)." -ForegroundColor Gray

    # Fast Boot - disabled to avoid startup problems
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

    # Scheduled defragmentation - harmful on SSDs
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\Defrag\ScheduledDefrag" /disable'
    Write-Host "   Defragmentation schedulata: OFF." -ForegroundColor Gray

    # Boot file defragment - useless on SSDs
    $BootDefrag = "HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction"
    if (!(Test-Path $BootDefrag)) { New-Item -Path $BootDefrag -Force | Out-Null }
    Set-ItemProperty -Path $BootDefrag -Name "Enable" -Value "N" -Force
    Write-Host "   Boot File Defrag: OFF." -ForegroundColor Gray

    # Thumbnail cache - regenerates itself, best fresh on Adobe workstations
    Invoke-SchtasksQuiet '/change /tn "Microsoft\Windows\ClearanceStorage\ClearanceStorageMaintenance" /disable'
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    Write-Host "   Thumbnail Cache: clean." -ForegroundColor Gray

    # Kernel Swapping - OFF solo se RAM >= 8GB
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

    # Disk Indexing - Disabled on the system drive
    $SysDrive = $env:SystemDrive
    & fsutil.exe behavior set disableencryption 1 2>$null
    try {
        $vol = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='$SysDrive'" -ErrorAction SilentlyContinue
        if ($vol) { $vol.IndexingEnabled = $false; $vol.Put() | Out-Null }
        Write-Host "   Indexing su $SysDrive`: OFF." -ForegroundColor Gray
    } catch {
        Write-Host "   WARN: Indexing - $_" -ForegroundColor Yellow
    }

    # Crash dump - disabled (WerSvc already crashed, avoids disk writes)
    $CrashPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
    Set-ItemProperty -Path $CrashPath -Name "CrashDumpEnabled" -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "LogEvent"         -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "SendAlert"        -Value 0 -Force
    Set-ItemProperty -Path $CrashPath -Name "AutoReboot"       -Value 1 -Force
    Write-Host "   Crash Dump: OFF." -ForegroundColor Gray

    Write-Host "-> SSD/NVMe optimized. TRIM enabled. Wasteful writes eliminated." -ForegroundColor Green
}

# ============================================================
# BLOCK 23: PERFORMANCE ENGINE
# GPU priority, SystemProfile, Process scheduler
# Energy plan: BALANCED preserved (intentional choice)
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

    # Font cache - unlimited for workstations with many Adobe fonts
    $FontCache = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontCache"
    if (!(Test-Path $FontCache)) { New-Item -Path $FontCache -Force | Out-Null }
    Set-ItemProperty -Path $FontCache -Name "MaxCacheSize" -Value 0 -Force
    Write-Host "   Font Cache: unlimited (Adobe/CAD)." -ForegroundColor Gray

    # MMCSS - conditional: disable only if no USB audio present
    # MMCSS introduces latency on Adobe/CAD workstations without real-time audio
    if (-not $UsbAudioPresent) {
        # Use sc.exe to avoid Stop-Service infinite loop on MMCSS
        & sc.exe stop MMCSS 2>$null | Out-Null
        Start-Sleep -Seconds 2
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\MMCSS" -Name "Start" -Value 4 -Force -ErrorAction SilentlyContinue
        Write-Host "   MMCSS: disabled (no USB audio detected)." -ForegroundColor Gray
    } else {
        Write-Host "   MMCSS: preserved (USB audio detected - real-time audio safe)." -ForegroundColor Gray
    }

    # Adaptive power plan - hardware aware
    $_battery  = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    $_isLaptop = $null -ne $_battery

    # CPU family detection - covers all major manufacturers
    $_cpuFamily = switch -Regex ($CpuName) {

        # ---- INTEL XEON LEGACY (high TDP, budget VRM boards) ----
        "Xeon E[357]-[0-9]{4}v?[1-4]?|Xeon W3[0-9]{3}|Xeon X[0-9]{4}" { "XEON_LEGACY" }

        # ---- INTEL XEON MODERN (Scalable, W series) ----
        "Xeon Gold|Xeon Platinum|Xeon Silver|Xeon Bronze|Xeon W-[0-9]{4}" { "XEON_MODERN" }

        # ---- INTEL CORE ULTRA (Meteor Lake, Arrow Lake 2024+) ----
        "Core.Ultra [79]|Ultra 9|Ultra 7" { "HIGH_END" }
        "Core.Ultra [35]|Ultra 5|Ultra 3" { "MID_HIGH" }

        # ---- INTEL CORE 12th-14th gen (Alder/Raptor/Meteor Lake) ----
        "i9-1[2-4][0-9]{3}|i9-13[0-9]{3}|i9-14[0-9]{3}" { "HIGH_END" }
        "i7-1[2-4][0-9]{3}|i7-13[0-9]{3}|i7-14[0-9]{3}" { "MID_HIGH" }
        "i[35]-1[2-4][0-9]{3}|i[35]-13[0-9]{3}|i5-1[0-9]{4}|i3-1[0-9]{4}" { "MID" }

        # ---- INTEL CORE 6th-11th gen ----
        "i9-[6-9][0-9]{3}|i9-1[01][0-9]{3}" { "HIGH_END" }
        "i7-[6-9][0-9]{3}|i7-1[01][0-9]{3}" { "MID_HIGH" }
        "i[35]-[6-9][0-9]{3}|i5-[6-9][0-9]{3}|i3-[6-9][0-9]{3}|i[35]-1[01][0-9]{3}" { "MID" }
        "i[35]-[234][0-9]{3}|Pentium|Celeron" { "LOW" }

        # ---- AMD RYZEN 7000/9000 series (Zen 4/5) ----
        "Ryzen 9 [79][0-9]{3}X3D|Ryzen 9 [79][0-9]{3}" { "HIGH_END" }
        "Ryzen 7 [79][0-9]{3}"                           { "MID_HIGH" }
        "Ryzen [35] [79][0-9]{3}"                        { "MID" }

        # ---- AMD RYZEN 5000 series (Zen 3) ----
        "Ryzen 9 5[0-9]{3}X3D|Ryzen 9 5[0-9]{3}" { "HIGH_END" }
        "Ryzen 7 5[0-9]{3}"                        { "MID_HIGH" }
        "Ryzen [35] 5[0-9]{3}"                     { "MID" }

        # ---- AMD RYZEN 3000/4000 series (Zen 2) ----
        "Ryzen 9 [34][0-9]{3}" { "HIGH_END" }
        "Ryzen 7 [34][0-9]{3}" { "MID_HIGH" }
        "Ryzen [35] [34][0-9]{3}" { "MID" }

        # ---- AMD THREADRIPPER ----
        "Threadripper PRO|Threadripper [5-9][0-9]{3}" { "HIGH_END" }
        "Threadripper [1-4][0-9]{3}"                   { "MID_HIGH" }

        # ---- AMD EPYC (server) ----
        "EPYC [79][0-9]{3}|EPYC [3-6][0-9]{3}" { "XEON_MODERN" }

        # ---- AMD ATHLON / older Ryzen ----
        "Athlon|Ryzen 3 [12][0-9]{3}|Ryzen 5 [12][0-9]{3}" { "LOW" }

        # ---- QUALCOMM SNAPDRAGON (ARM Windows) ----
        "Snapdragon X Elite|Snapdragon X Plus|Snapdragon 8cx" { "MID_HIGH" }
        "Snapdragon 7c|Snapdragon 8c" { "MID" }

        # ---- APPLE SILICON via VM (Parallels etc) ----
        "Apple M[1-4]" { "MID_HIGH" }

        # ---- DEFAULT ----
        default { "UNKNOWN" }
    }

    Write-Host ("   CPU family: {0} ({1})" -f $_cpuFamily, $CpuName) -ForegroundColor Gray

    $_ppName = $null
    $_ppGuid = $null

    # ---- GRANULAR RAM TIERS (same scale as Block 2 SvcHost threshold) ----
    # 4GB=entry 6GB=low 8GB=mid 12GB=mid+ 16GB=high 24GB=workstation 32GB+=pro
    $_ramTier = switch ($RAM_GB) {
        { $_ -le 4  } { "ENTRY" }
        { $_ -le 6  } { "LOW" }
        { $_ -le 8  } { "MID" }
        { $_ -le 12 } { "MID_PLUS" }
        { $_ -le 16 } { "HIGH" }
        { $_ -le 24 } { "WORKSTATION" }
        { $_ -le 32 } { "PRO" }
        default        { "MAX" }  # 64GB+
    }

    Write-Host ("   RAM tier: {0} ({1} GB @ {2} MHz)" -f $_ramTier, $RAM_GB, $RAMSpeed) -ForegroundColor Gray

    if ($_isLaptop) {
        # Laptop: always Balanced regardless of specs - thermal and battery priority
        $_ppName = "Balanced"
        Write-Host "   Power plan: BALANCED (laptop - thermal/battery management)." -ForegroundColor Gray

    } elseif ($_cpuFamily -eq "XEON_LEGACY") {
        # Xeon legacy: always Balanced - high TDP, budget VRM boards
        $_ppName = "Balanced"
        Write-Host "   Power plan: BALANCED (Xeon legacy - high TDP, conservative)." -ForegroundColor Yellow

    } elseif ($_cpuFamily -eq "UNKNOWN" -or $CpuCores -le 2) {
        # Unknown or very old CPU: safe default
        $_ppName = "Balanced"
        Write-Host "   Power plan: BALANCED (unknown/legacy CPU - safe default)." -ForegroundColor Yellow

    } elseif ($_cpuFamily -match "HIGH_END|MID_HIGH|XEON_MODERN" -and
              $CpuCores -ge 8 -and $_ramTier -match "WORKSTATION|PRO|MAX") {
        # High-end CPU + workstation RAM (24GB+): Ultimate Performance
        $_upGuid = (& powercfg.exe /l 2>$null | Select-String "Ultimate Performance" |
            Select-String -Pattern "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})" |
            ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1)
        if (-not $_upGuid) {
            # Activate Ultimate Performance on Pro (available but hidden by default)
            & powercfg.exe /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
            $_upGuid = (& powercfg.exe /l 2>$null | Select-String "Ultimate Performance" |
                Select-String -Pattern "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})" |
                ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1)
        }
        if ($_upGuid) {
            $_ppName = "Ultimate Performance"
            $_ppGuid = $_upGuid
            Write-Host ("   Power plan: ULTIMATE PERFORMANCE ({0} core, {1} GB RAM [{2}])." -f $CpuCores, $RAM_GB, $_ramTier) -ForegroundColor Green
        } else {
            $_ppName = "High Performance"
            Write-Host "   Power plan: HIGH PERFORMANCE (Ultimate not available)." -ForegroundColor Gray
        }

    } elseif ($_cpuFamily -match "HIGH_END|MID_HIGH|XEON_MODERN" -and
              $CpuCores -ge 6 -and $_ramTier -match "HIGH|WORKSTATION|PRO|MAX") {
        # High-end CPU + 16GB+ RAM: High Performance
        $_ppName = "High Performance"
        Write-Host ("   Power plan: HIGH PERFORMANCE ({0} core, {1} GB RAM [{2}])." -f $CpuCores, $RAM_GB, $_ramTier) -ForegroundColor Gray

    } elseif ($_cpuFamily -match "MID|MID_HIGH" -and
              $CpuCores -ge 4 -and $_ramTier -match "MID_PLUS|HIGH|WORKSTATION|PRO|MAX") {
        # Mid-range CPU + 12GB+ RAM: High Performance
        $_ppName = "High Performance"
        Write-Host ("   Power plan: HIGH PERFORMANCE (mid-range, {0} GB RAM [{1}])." -f $RAM_GB, $_ramTier) -ForegroundColor Gray

    } elseif ($_ramTier -match "ENTRY|LOW|MID" -or $CpuCores -le 4) {
        # Low RAM or few cores: Balanced
        $_ppName = "Balanced"
        Write-Host ("   Power plan: BALANCED (limited resources - {0} core, {1} GB [{2}])." -f $CpuCores, $RAM_GB, $_ramTier) -ForegroundColor Gray

    } else {
        # Fallback
        $_ppName = "Balanced"
        Write-Host "   Power plan: BALANCED (safe default)." -ForegroundColor Gray
    }

    # Apply plan if not already set or if guid found
    if (-not $_ppGuid -and $_ppName) {
        $_ppGuid = (& powercfg.exe /l 2>$null | Select-String $_ppName |
            Select-String -Pattern "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})" |
            ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1)
    }
    if ($_ppGuid) {
        & powercfg.exe /setactive $_ppGuid 2>$null
    }

    Write-Host "-> Performance Engine applied." -ForegroundColor Green
}

# ============================================================
# BLOCK 25: STARTUP CLEANUP & SYSTEM BEHAVIOR
# Legacy boot entries, useless services, OS behavior
# ============================================================
& {
    Write-Host "`n[MODULO] Startup Cleanup & System Behavior..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # Legacy boot entries, useless services, OS behavior 
    # --------------------------------------------------------

    # PcaSvc - On Win11 Home it is useful for consumer app compatibility
    # Left active but with telemetry disabled
    Write-Host "   PcaSvc (Program Compatibility): PRESERVED on Win11 Pro/Home." -ForegroundColor Gray

    # Disable running services not needed on standalone workstation
    # Source: verified from actual Pro 26200 running services list
    # NOTE: CaptureService_* preserved - required by Snipping Tool Windows.Graphics.Capture API
    $ExtraRunningServices = @{
        "SsdpDiscovery"    = 4  # SSDP Discovery - UPnP device discovery (security risk)
        "lfsvc"            = 4  # Geolocation Service
        "WpnService"       = 4  # Push Notifications (WPN)
        "ShellHWDetection" = 4  # Shell Hardware Detection - autoplay
        "DPS"              = 4  # Diagnostic Policy Service - performance data
        "DsmSvc"           = 4  # Device Setup Manager
        "TrkWks"           = 4  # Distributed Link Tracking Client
        "DoSvc"            = 4  # Delivery Optimization - already blocked via GPO
        "WpnUserService"   = 3  # Push User Service - manual only
        "CDPSvc"           = 4  # Connected Devices Platform
        "WSAIFabricSvc"    = 4  # Windows AI Fabric Service (build 26100+)
    }
    foreach ($entry in $ExtraRunningServices.GetEnumerator()) {
        $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Key)"
        if (Test-Path $svcPath) {
            Stop-Service -Name $entry.Key -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $svcPath -Name "Start" -Value $entry.Value -Force -ErrorAction SilentlyContinue
            Write-Host ("   {0}: disabled (running on Pro, not needed standalone)." -f $entry.Key) -ForegroundColor Gray
        }
    }

    # PRO-ONLY: Disable services active on Pro but useless on standalone workstations
    # These are enabled by default on Pro but not on Home/LTSC
    # NOTE: TermService (RDP) is preserved - user may need remote access
    $ProOnlyServices = @{
        "RemoteRegistry"  = 4   # Remote registry access - security risk on workstation
        "WinRM"           = 4   # Windows Remote Management - not needed on standalone
        "PrintNotify"     = 4   # Printer notifications - not needed without print server
        "Fax"             = 4   # Fax service - legacy
        "TapiSrv"         = 3   # Telephony - manual, only if needed
        "WSearch"         = 4   # Windows Search - handled in Block 16
    }
    foreach ($entry in $ProOnlyServices.GetEnumerator()) {
        $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Key)"
        if (Test-Path $svcPath) {
            Stop-Service -Name $entry.Key -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $svcPath -Name "Start" -Value $entry.Value -Force -ErrorAction SilentlyContinue
            Write-Host ("   {0}: disabled (Pro-only, not needed on standalone)." -f $entry.Key) -ForegroundColor Gray
        }
    }

    # Automatic maintenance - left on but silenced
    # Runs TRIM, chkdsk, cleanups - useful on unattended machines
    $MaintPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
    if (!(Test-Path $MaintPath)) { New-Item -Path $MaintPath -Force | Out-Null }
    Set-ItemProperty -Path $MaintPath -Name "MaintenanceDisabled" -Value 0 -Force
    Write-Host "   Automatic maintenance: PRESERVED (useful on unattended machines)." -ForegroundColor Gray

    # Group Policy Update on Startup - PRESERVED
    # Required to keep BLOCK 10 WU policies active
    Write-Host "   Startup Group Policy: PRESERVED (required by WU BLOCK 10 policy)." -ForegroundColor Gray

    # --------------------------------------------------------
    # STARTUP - Legacy entries to disable
    # --------------------------------------------------------

    # webcheck - Check for residual IE updates
    $RunPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Remove-ItemProperty -Path $RunPath -Name "WebCheck" -ErrorAction SilentlyContinue
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "WebCheck" /f 2>$null | Out-Null
    Write-Host "   WebCheck (IE legacy): removed from startup." -ForegroundColor Gray

    # unregmp2.exe - WMP codec recording
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "unregmp2" /f 2>$null | Out-Null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "unregmp2" /f 2>$null | Out-Null
    Write-Host "   unregmp2.exe (WMP codec): removed from startup." -ForegroundColor Gray

    # ie4uinit.exe - legacy IE initialization
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ie4uinit" /f 2>$null | Out-Null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ie4uinit" /f 2>$null | Out-Null
    # Also blocks via silent IFEO 
    $IFEOie = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\ie4uinit.exe"
    if (!(Test-Path $IFEOie)) { New-Item -Path $IFEOie -Force | Out-Null }
    if (Test-Path "C:\Windows\System32\noop.exe") {
        Set-ItemProperty -Path $IFEOie -Name "Debugger" -Value "C:\Windows\System32\noop.exe" -Force
    }
    Write-Host "   ie4uinit.exe (IE legacy): blocked." -ForegroundColor Gray

    # iconcodecservice.dll - codec icone legacy
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "IconCodecService" /f 2>$null | Out-Null
    Write-Host "   IconCodecService.dll (legacy): removed from startup." -ForegroundColor Gray

    # Desktop Update - Wallpaper Refresh Useless
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopUpdate" /f 2>$null | Out-Null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "DesktopUpdate" /f 2>$null | Out-Null
    Write-Host "   Desktop Update: removed from startup." -ForegroundColor Gray

    # systempropertiesperformance.exe - it should not run at startup
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SystemPropertiesPerformance" /f 2>$null | Out-Null
    & reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SystemPropertiesPerformance" /f 2>$null | Out-Null
    Write-Host "   SystemPropertiesPerformance.exe: removed from startup." -ForegroundColor Gray

    # mscories.dll - .NET runtime init legacy
    # Removed only from autorun, not system - .NET apps load it themselves
    & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "mscories" /f 2>$null | Out-Null
    Write-Host "   mscories.dll: removed from startup (loaded on demand from .NET apps)." -ForegroundColor Gray

    # --------------------------------------------------------
    # COMPORTAMENTO OS
    # --------------------------------------------------------

    # Windows Notepad Annotation (Sticky Notes legacy)
    $StickyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\StickyNotes"
    if (!(Test-Path $StickyPath)) { New-Item -Path $StickyPath -Force | Out-Null }
    Set-ItemProperty -Path $StickyPath -Name "HideOnClose" -Value 0 -Force
    & reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "StickyNotes" /f 2>$null | Out-Null
    Write-Host "   BLOCK note annotation: disabled." -ForegroundColor Gray

    # Cancel automatic chkdsk on startup on C:
    & chkntfs.exe /x C: 2>$null
    Write-Host "   Automatic disk check (C:): canceled." -ForegroundColor Gray

    # Startup delay elimination - removes artificial Explorer startup delay
    $SerializePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    if (!(Test-Path $SerializePath)) { New-Item -Path $SerializePath -Force | Out-Null }
    Set-ItemProperty -Path $SerializePath -Name "StartupDelayInMSec" -Value 0 -Force
    Write-Host "   Explorer startup delay: eliminated." -ForegroundColor Gray

    # Last Known Good Configuration - PRESERVED
    # Safety net if a future script damages the registry
    $LKGPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
    Set-ItemProperty -Path $LKGPath -Name "LastKnownGoodRecovery" -Value 1 -Force -ErrorAction SilentlyContinue
    Write-Host "  Last known good configuration: PRESERVED (safety net)." -ForegroundColor Gray

    # --------------------------------------------------------
    # NTFS - paging memory for file system cache
    # Complete BLOCK 23 (fsutil memoryusage 2 already applied)
    # --------------------------------------------------------
    $NtfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $NtfsPath -Name "LargeSystemCache" -Value 0 -Force
    Write-Host "   NTFS LargeSystemCache: optimized for workstations (not servers)." -ForegroundColor Gray

    Write-Host "-> Startup Cleanup & System Behavior completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 26: BLOATWARE REMOVAL - Win11 Home
# Removes unnecessary pre-installed apps on workstation machines
# Preserve: Store, Photos, Calculator, Notepad, Terminal
# ============================================================
& {
    Write-Host "`n[MODULO] Bloatware Removal Win11 Pro..." -ForegroundColor Yellow

    $bloatware = @(
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.XboxSpeechToTextOverlay"
        "Microsoft.GamingApp"
        # NOTA: Microsoft.XboxGameCallableUI excluded - protected shell package
        # Removal generates 0x80070032 and is ignored by Windows
        "Microsoft.MicrosoftTeams"
        "MicrosoftTeams"
        "Microsoft.Teams*"
        "Microsoft.BingNews"
        "Microsoft.BingWeather"
        "Microsoft.BingSearch"
        "Microsoft.BingSports"
        "Microsoft.BingFinance"
        "Microsoft.BingTravel"
        # Sponsored apps - pre-installed on Pro OEM/fresh install
        "Microsoft.LinkedIn"
        "LinkedIn.LinkedIn"
        "king.com.CandyCrushSaga"
        "king.com.CandyCrushFriends"
        "king.com.BubbleWitch3Saga"
        "king.com.FarmHeroesSaga"
        "A278AB0D.MarchofEmpires"
        "SpotifyAB.SpotifyMusic"
        "Facebook.Facebook"
        "BytedancePte.TikTok"
        "TikTok.TikTok"
        "2FE3CB00.PicsArt-PhotoStudio"
        "Microsoft.People"
        "Microsoft.Getstarted"
        "Microsoft.GetHelp"
        "Microsoft.Todos"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        "Microsoft.YourPhone"
        "Microsoft.WindowsPhone"
        "Microsoft.Phone*"
        "Microsoft.MixedReality.Portal"
        "Microsoft.SkypeApp"
        "Microsoft.OneDriveSync"
        "Microsoft.PowerAutomateDesktop"
        "Microsoft.Clipchamp*"
        "Clipchamp.Clipchamp"
        "MicrosoftCorporationII.MicrosoftFamily"
        "Microsoft.OutlookForWindows"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.549981C3F5F10"  # Cortana
        "Microsoft.Windows.Cortana"
    )

    $removed = 0
    foreach ($app in $bloatware) {
        $pkgs = Get-AppxPackage -AllUsers -Name $app -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            $removed++
            Write-Host ("   Rimosso: {0}" -f $pkg.Name) -ForegroundColor Gray
        }
        # Also remove provisioned (does not return after new user)
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $app } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }

    # User choice: OneDrive is disabled only if confirmed by a popup
    # OneDrive popup - split message (backtick-n unreliable in psd1)
    $OneDriveMsg = $Lang.OneDriveMsg + "`n" + $Lang.OneDriveMsg2
    $DisableOneDrive = Ask-YesNoPopup `
        -Title $Lang.OneDriveTitle `
        -Message $OneDriveMsg
    if ($DisableOneDrive) {
        Invoke-ZombiePurge -DisableOneDrive $true

        # Uninstall classic OneDrive (if present) - strong anti-reappearance
        # Use timeout to prevent blocking if installer hangs
        $odSetup = $null
        if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
            $odSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        } elseif (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
            $odSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
        }
        if ($odSetup) {
            $odProc = Start-Process $odSetup "/uninstall" -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
            if ($odProc) {
                $odProc.WaitForExit(30000) | Out-Null  # 30 second timeout
                if (-not $odProc.HasExited) { $odProc.Kill() }
            }
        } else {
            Write-Host "   OneDrive setup not found - skipping uninstall." -ForegroundColor Gray
        }
        Write-Host "   $($Lang.OneDriveDisabled)" -ForegroundColor Gray
    } else {
        Invoke-ZombiePurge -DisableOneDrive $false
        Write-Host "   $($Lang.OneDriveKept)" -ForegroundColor Gray
    }

    # PRO ONLY: Teams separate popup
    # On Pro, Teams may be used for business - separate choice from OneDrive
    # Teams popup - use two-line message (backtick-n unreliable in psd1)
    $TeamsMsg = $Lang.TeamsMsg + "`n" + $Lang.TeamsMsg2
    $DisableTeams = Ask-YesNoPopup `
        -Title $Lang.TeamsTitle `
        -Message $TeamsMsg
    if ($DisableTeams) {
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -match "Teams|MicrosoftTeams" } |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match "Teams|MicrosoftTeams" } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        Remove-RegValueQuiet -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "TeamsMachineInstaller"
        Write-Host "   $($Lang.TeamsRemoved)" -ForegroundColor Gray
    } else {
        Write-Host "   $($Lang.TeamsKept)" -ForegroundColor Gray
    }

    # Disabilita Xbox Game Bar
    $XBPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (!(Test-Path $XBPath)) { New-Item -Path $XBPath -Force | Out-Null }
    Set-ItemProperty -Path $XBPath -Name "AllowGameDVR" -Value 0 -Force
    Write-Host "   Xbox Game Bar: Disabled." -ForegroundColor Gray

    # Anti-Zombie Persistent Task: Cleans Copilot/Teams/OneDrive on every startup
    $AntiZombieScript = "C:\ProgramData\System4\anti_zombie.ps1"
    $AntiZombieDir = Split-Path -Path $AntiZombieScript -Parent
    if (!(Test-Path $AntiZombieDir)) { New-Item -Path $AntiZombieDir -ItemType Directory -Force | Out-Null }
    $AntiZombieContent = @'
# Light mode: avoids Appx removals during boot/logon (causes Explorer refresh)
Start-Sleep -Seconds 180

& reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>$null | Out-Null
& reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>$null | Out-Null
& reg.exe delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f 2>$null | Out-Null
& reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f 2>$null | Out-Null
& reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "TeamsMachineInstaller" /f 2>$null | Out-Null

if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1 -Force

if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge")) { New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Force | Out-Null }
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "StandaloneHubsSidebarEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "ShowCopilotButton" -Value 0 -Force -ErrorAction SilentlyContinue

Stop-Process -Name "OneDrive","ms-teams","Teams","Copilot","msedge_proxy" -Force -ErrorAction SilentlyContinue
try {
    Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "Copilot" -or $_.TaskPath -match "Copilot" } | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
} catch {}
'@
    Set-Content -Path $AntiZombieScript -Value $AntiZombieContent -Encoding ASCII -Force
    Invoke-SchtasksQuiet '/Delete /TN "System4-AntiZombie-Start" /F'
    Invoke-SchtasksQuiet '/Delete /TN "System4-AntiZombie-Logon" /F'
    Invoke-SchtasksQuiet "/Create /TN `"System4-AntiZombie-Start`" /SC ONSTART /DELAY 0005:00 /RU SYSTEM /TR `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$AntiZombieScript`"`" /F"
    Write-Host "   Anti-zombie task recorded (ONSTART with 5 minute delay, light mode)." -ForegroundColor Gray

    # Prewarm shell via registry - cleaner and more stable than VBS SendKeys
    # EnablePreLaunch tells Windows to preload COM/shell processes at logon
    # Without simulating user input - no conflicts with Start or taskbar
    $ExplorerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
    Set-ItemProperty -Path $ExplorerPath -Name "EnablePreLaunch" -Value 1 -Force -ErrorAction SilentlyContinue

    # Cleaning prewarm residues from previous versions of the script
    Invoke-SchtasksQuiet '/Delete /TN "System4-StartPrewarm" /F'
    $PrewarmVbs = Join-Path $AntiZombieDir "start_prewarm.vbs"
    $PrewarmPs1 = Join-Path $AntiZombieDir "start_prewarm.ps1"
    Remove-Item -Path $PrewarmVbs -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $PrewarmPs1 -Force -ErrorAction SilentlyContinue
    Write-Host "   Shell prewarm: EnablePreLaunch=1 via registro (stabile, no SendKeys)." -ForegroundColor Gray

    Write-Host ("-> Bloatware removed: {0} packages. Copilot/Teams cleaned up, OneDrive management is user-selectable." -f $removed) -ForegroundColor Green
}


# ============================================================
# BLOCK 27: ACCOUNT MICROSOFT & PRIVACY POLICY
# Block MSA requirements reset after updates
# ============================================================
& {
    Write-Host "`n[MODULO] BLOCK Account Microsoft & Privacy..." -ForegroundColor Cyan

    # NOTE: BlockMicrosoftAccounts and NoConnectedUser have been removed.
    # Value 3 breaks PIN/Windows Hello on existing MSA accounts
    # Remove if present from previous versions of the script
    $MsaPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Remove-ItemProperty -Path $MsaPath -Name "NoConnectedUser"        -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $MsaPath -Name "BlockMicrosoftAccounts" -ErrorAction SilentlyContinue
    Write-Host "   Microsoft Accounts: Aggressive policies removed (PIN/Hello preserved)." -ForegroundColor Gray

    # Protects NGC services (PIN / Windows Hello) - must remain active
    foreach ($ngc in @("NgcSvc", "NgcCtnrSvc")) {
        $ngcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ngc"
        if (Test-Path $ngcPath) {
            Set-ItemProperty -Path $ngcPath -Name "Start" -Value 3 -Force -ErrorAction SilentlyContinue
            Write-Host ("   {0}: Start=3 (Manual) - PIN protected." -f $ngc) -ForegroundColor Gray
        }
    }

    # Disable sync settings Microsoft Account
    $SyncPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"
    if (!(Test-Path $SyncPath)) { New-Item -Path $SyncPath -Force | Out-Null }
    Set-ItemProperty -Path $SyncPath -Name "DisableSettingSync"            -Value 2 -Force
    Set-ItemProperty -Path $SyncPath -Name "DisableSettingSyncUserOverride" -Value 1 -Force
    Write-Host "   Settings Sync: Disable." -ForegroundColor Gray

    # Disable Activity History (Timeline)
    $ActPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (!(Test-Path $ActPath)) { New-Item -Path $ActPath -Force | Out-Null }
    Set-ItemProperty -Path $ActPath -Name "EnableActivityFeed"        -Value 0 -Force
    Set-ItemProperty -Path $ActPath -Name "PublishUserActivities"     -Value 0 -Force
    Set-ItemProperty -Path $ActPath -Name "UploadUserActivities"      -Value 0 -Force
    Write-Host "   Activity History/Timeline: Disable." -ForegroundColor Gray

    # Disable Consumer Features (suggested apps, spotlight etc)
    $CfPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (!(Test-Path $CfPath)) { New-Item -Path $CfPath -Force | Out-Null }
    Set-ItemProperty -Path $CfPath -Name "DisableWindowsConsumerFeatures" -Value 1 -Force
    Set-ItemProperty -Path $CfPath -Name "DisableCloudOptimizedContent"   -Value 1 -Force
    Set-ItemProperty -Path $CfPath -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1 -Force
    Write-Host "   Consumer Features/Spotlight: Disable." -ForegroundColor Gray

    # Disable Recall (Win11 Home 26100+)
    $RecallPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    if (!(Test-Path $RecallPath)) { New-Item -Path $RecallPath -Force | Out-Null }
    Set-ItemProperty -Path $RecallPath -Name "DisableAIDataAnalysis"  -Value 1 -Force
    Set-ItemProperty -Path $RecallPath -Name "TurnOffSavingSnapshots" -Value 1 -Force
    Write-Host "   Recall (AI Snapshots): Disable." -ForegroundColor Gray

    # Disable Widgets (News feed taskbar)
    $WidgetPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (!(Test-Path $WidgetPath)) { New-Item -Path $WidgetPath -Force | Out-Null }
    Set-ItemProperty -Path $WidgetPath -Name "AllowNewsAndInterests" -Value 0 -Force
    # Widgets taskbar - HKCU + SID utente attivo + .DEFAULT
    Set-TaskbarDaEverywhere -Value 0
    Write-Host "   Widgets/News feed taskbar: Disable (HKCU + active user + .DEFAULT)." -ForegroundColor Gray

    # Wi-Fi Sense: disable (stops sharing WiFi passwords with contacts)
    $WifiSensePath = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
    if (!(Test-Path $WifiSensePath)) { New-Item -Path $WifiSensePath -Force | Out-Null }
    Set-ItemProperty -Path $WifiSensePath -Name "AutoConnectAllowedOEM" -Value 0 -Force -ErrorAction SilentlyContinue
    Write-Host "   Wi-Fi Sense: disabled (no password sharing)." -ForegroundColor Gray

    Write-Host "-> Microsoft account and privacy policy configured." -ForegroundColor Green
}


# ============================================================
# BLOCK 27b: FEATUREMANAGEMENT OVERRIDES
# Kernel flags not officially documented by Microsoft but
# tested on physical hardware with measurable results on SSD:
# 735209102 = NTFS/Storage cache write-back optimization
# 1853569164 = Improved NVMe/DirectStorage queue depth
# 156965516 = storage subsystem I/O latency optimization
# Source: Direct testing on physical machines - not from public repositories
# ============================================================
& {
    Write-Host "`n[MODULO] FeatureManagement Overrides (SSD performance)..." -ForegroundColor Cyan
    $FmPath = "HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides"
    if (!(Test-Path $FmPath)) { New-Item -Path $FmPath -Force | Out-Null }
    Set-ItemProperty -Path $FmPath -Name "735209102"  -Value 1 -Type DWord -Force  # NTFS write-back cache
    Set-ItemProperty -Path $FmPath -Name "1853569164" -Value 1 -Type DWord -Force  # NVMe queue depth
    Set-ItemProperty -Path $FmPath -Name "156965516"  -Value 1 -Type DWord -Force  # I/O latency subsystem
    Write-Host "   FeatureManagement SSD Overrides applied." -ForegroundColor Gray
    Write-Host "-> FeatureManagement Overrides completed." -ForegroundColor Green
}

# ============================================================
# BLOCK 28: FINAL SEALING & ATOMIC REBOOT
# ============================================================
& {
    Write-Host "`n[MODULO] System Sealing and Final Log Cleaning..." -ForegroundColor Cyan

    & ipconfig /flushdns | Out-Null

    # Sync registro veloce
    & reg.exe export "HKLM\SYSTEM\Select" "$env:TEMP\flush.reg" /y | Out-Null
    Remove-Item -Path "$env:TEMP\flush.reg" -Force -ErrorAction SilentlyContinue

    # Pulizia Event Viewer
    Write-Host "-> Emptying Event Viewer..." -ForegroundColor Gray
    & wevtutil.exe cl System      2>$null
    & wevtutil.exe cl Application 2>$null
    & wevtutil.exe cl Security    2>$null

    Write-Host "`n=== TITANIUM V8 WIN11 HOME 26100 COMPLETED ===" -ForegroundColor Green
    # --------------------------------------------------------
    # RIEPILOGO FINALE NEL LOG
    # --------------------------------------------------------
    $LogEndTime  = Get-Date
    $LogDuration = $LogEndTime - $LogStartTime
    $DurMin      = [math]::Floor($LogDuration.TotalMinutes)
    $DurSec      = $LogDuration.Seconds
    $LogResult   = if ($script:LogErrors -eq 0) { $Lang.FooterSuccess } else { $Lang.FooterWithErrors }

    $footer = @"

$($Lang.FooterSummary)
╔══════════════════════════════════════════════════════════════╗
║  $($Lang.FooterResult): $LogResult
║  $($Lang.FooterDuration): $DurMin $($Lang.FooterMinutes) $DurSec $($Lang.FooterSeconds)
║  $($Lang.FooterOK): $script:LogBlocksOk   $($Lang.FooterWarnings): $script:LogWarnings   $($Lang.FooterErrors): $script:LogErrors
╚══════════════════════════════════════════════════════════════╝

$($Lang.FooterSendFile)
$($Lang.FooterBackupPath) C:\Windows\Logs\$ScriptName\
"@
    Add-Content -Path $LogDesktop -Value $footer -Encoding UTF8 -ErrorAction SilentlyContinue
    Add-Content -Path $LogBackup  -Value $footer -Encoding UTF8 -ErrorAction SilentlyContinue

    Write-Host "`n=== TITANIUM V8 WIN11 PRO - COMPLETED ===" -ForegroundColor Green
    # Note: SummaryTitle hardcoded for Pro (lang key uses HOME variant)
    Write-Host $Lang.SummaryDefender  -ForegroundColor White
    Write-Host $Lang.SummaryBloatware -ForegroundColor White
    Write-Host $Lang.SummaryMSA       -ForegroundColor White
    Write-Host $Lang.SummarySSD       -ForegroundColor White
    Write-Host $Lang.SummaryPerf      -ForegroundColor White
    Write-Host $Lang.SummaryReboot    -ForegroundColor Yellow

    # Final popup readable even by non-technical people
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            ($Lang.PopupBody -f $LogDesktop),
            $Lang.PopupTitle,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {}

    Start-Sleep -Seconds 12
    Remove-Sys4DefenderExclusions
    & shutdown.exe /r /f /t 0
}
