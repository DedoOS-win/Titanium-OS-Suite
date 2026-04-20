<#
.SYNOPSIS
Adobe_Titanium_IoT.ps1
Target: Photoshop, Illustrator, After Effects, Acrobat
AUTO-DETECT mode:
  - Licensed version:  blocks telemetry only, preserves license and AI services
  - Portable version:  blocks everything, no license services needed
#>

if ([Security.Principal.WindowsIdentity]::GetCurrent().Name -ne "NT AUTHORITY\SYSTEM") {
    Write-Host "ERROR: Run as SYSTEM via PowerRun!" -ForegroundColor Red
    Pause; exit
}

Write-Host "`n=== ADOBE TITANIUM: IOT AUTO-DETECT MODE ===`n" -ForegroundColor Cyan

# ============================================================
# AUTO-DETECTION: LICENSED vs PORTABLE
# Criteria:
# 1. Creative Cloud installed (HKLM or Program Files)
# 2. AGSService active (Genuine Service)
# 3. OOBE/PDApp folder present (official installer)
# ============================================================
Write-Host "[DETECT] Detecting Adobe installation type..." -ForegroundColor Cyan

$isLicensed = $false

# Criterion 1: Creative Cloud installed
if (Test-Path "C:\Program Files (x86)\Adobe\Adobe Creative Cloud\ACC\Creative Cloud.exe") {
    $isLicensed = $true
}

# Criterion 2: AGSService present and not manually disabled
if (!$isLicensed) {
    $ags = Get-Service -Name "AGSService" -ErrorAction SilentlyContinue
    if ($ags -and $ags.StartType -ne "Disabled") { $isLicensed = $true }
}

# Criterion 3: Official Adobe installer folder
if (!$isLicensed) {
    if (Test-Path "C:\Program Files (x86)\Common Files\Adobe\OOBE\PDApp") {
        $isLicensed = $true
    }
}

if ($isLicensed) {
    Write-Host "   Detected: LICENSED VERSION" -ForegroundColor Green
    Write-Host "   Profile: Telemetry block - License and AI services preserved`n" -ForegroundColor Green
} else {
    Write-Host "   Detected: PORTABLE VERSION" -ForegroundColor Yellow
    Write-Host "   Profile: Full block - No license services needed`n" -ForegroundColor Yellow
}

# ============================================================
# 1. WEBVIEW2 INTEGRITY CHECK
# ============================================================
Write-Host "[1/5] Checking WebView2 components..." -ForegroundColor Yellow

$wv2Found = (Test-Path "C:\Program Files (x86)\Microsoft\EdgeWebView\Application") -or
            (Test-Path "C:\Program Files (x86)\Microsoft\EdgeCore")

if ($wv2Found) {
    Write-Host "   DONE: WebView2 found. Modern UI panels working." -ForegroundColor Green
} else {
    Write-Host "   WARN: WebView2 not found. Some UI panels may not open." -ForegroundColor Red
    Write-Host "   Install WebView2 Redistributable from Microsoft." -ForegroundColor Yellow
}

# ============================================================
# 2. ADOBE SERVICES MANAGEMENT
# Licensed: disable only updates and telemetry
# Portable: disable everything
# ============================================================
Write-Host "`n[2/5] Managing Adobe services..." -ForegroundColor Yellow

# Always disabled (useless in both cases)
$alwaysDisable = @(
    "AdobeUpdateService",   # Automatic updates
    "AdobeARMservice",      # Background updates
    "AdobeIPCBroker"        # Creative Cloud IPC
)
foreach ($svc in $alwaysDisable) {
    Set-Service  $svc -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service $svc -Force               -ErrorAction SilentlyContinue
}

if ($isLicensed) {
    # LICENSED VERSION: preserve services needed for license and AI
    # AGSService: Genuine Service - required for license validation
    Set-Service "AGSService" -StartupType Manual -ErrorAction SilentlyContinue
    # AdobeActiveLUService: local license management - required
    Set-Service "AdobeActiveLUService" -StartupType Manual -ErrorAction SilentlyContinue
    Write-Host "   Licensed: AGSService and AdobeActiveLUService preserved (Manual)." -ForegroundColor Green
} else {
    # PORTABLE VERSION: disable everything
    Set-Service  "AGSService"           -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service "AGSService"           -Force                -ErrorAction SilentlyContinue
    Set-Service  "AdobeActiveLUService" -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service "AdobeActiveLUService" -Force                -ErrorAction SilentlyContinue
    Write-Host "   Portable: AGSService and AdobeActiveLUService disabled." -ForegroundColor Yellow
}

Write-Host "   DONE: Services managed correctly." -ForegroundColor Green

# ============================================================
# 3. HOSTS BLOCK
# Licensed: block pure telemetry only, preserve license and AI domains
# Portable: also block genuine and license domains (useless)
# ============================================================
Write-Host "`n[3/5] HOSTS hardening..." -ForegroundColor Yellow

$Hosts = "$env:SystemRoot\System32\drivers\etc\hosts"

# Always blocked: pure telemetry (safe in both profiles)
$alwaysBlock = @(
    @{ Pattern = "ardownload.adobe.com";  Entry = "127.0.0.1 ardownload.adobe.com" },
    @{ Pattern = "ardownload2.adobe.com"; Entry = "127.0.0.1 ardownload2.adobe.com" },
    @{ Pattern = "agsservice.adobe.com";  Entry = "127.0.0.1 agsservice.adobe.com" }
)

# Portable only: genuine and license domains
$portableOnly = @(
    @{ Pattern = "genuine.adobe.com";        Entry = "127.0.0.1 genuine.adobe.com" },
    @{ Pattern = "lcs-cops.adobe.io";        Entry = "127.0.0.1 lcs-cops.adobe.io" },
    @{ Pattern = "adobe-identity.adobe.com"; Entry = "127.0.0.1 adobe-identity.adobe.com" }
)

$toBlock = $alwaysBlock
if (!$isLicensed) { $toBlock += $portableOnly }

foreach ($h in $toBlock) {
    if (!(Select-String -Path $Hosts -Pattern $h.Pattern -Quiet)) {
        Add-Content -Path $Hosts -Value "`n$($h.Entry)" -ErrorAction SilentlyContinue
        Write-Host "   Blocked: $($h.Pattern)" -ForegroundColor Gray
    } else {
        Write-Host "   Already present: $($h.Pattern)" -ForegroundColor Gray
    }
}

Write-Host "   DONE: HOSTS configured." -ForegroundColor Green

# ============================================================
# 4. CPU & I/O PRIORITY
# Photoshop, Illustrator, After Effects, Acrobat
# ============================================================
Write-Host "`n[4/5] CPU & I/O Priority tuning..." -ForegroundColor Cyan

$apps = @(
    @{ Exe = "Photoshop.exe";   Cpu = 3; Io = 3 },
    @{ Exe = "Illustrator.exe"; Cpu = 3; Io = 3 },
    @{ Exe = "AfterFX.exe";     Cpu = 4; Io = 3 },
    @{ Exe = "Acrobat.exe";     Cpu = 3; Io = 3 },
    @{ Exe = "AcroRd32.exe";    Cpu = 3; Io = 3 }
)

foreach ($app in $apps) {
    $baseKey = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($app.Exe)"
    $perfKey = "$baseKey\PerfOptions"
    & reg.exe add $baseKey -v "IoPriority"       -t REG_DWORD -d $app.Io  -f | Out-Null
    & reg.exe add $perfKey -v "CpuPriorityClass" -t REG_DWORD -d $app.Cpu -f | Out-Null
    Write-Host "   $($app.Exe): CPU=$($app.Cpu) IO=$($app.Io)" -ForegroundColor Gray
}

Write-Host "   DONE: CPU/IO priorities applied." -ForegroundColor Green

# ============================================================
# 5. SSD CACHE, FIREWALL & TASK CLEANUP
# ============================================================
Write-Host "`n[5/5] Cache, Firewall & Task cleanup..." -ForegroundColor Cyan

# NTFS cache for large files (PSD, AI, AEP)
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "NtfsMemoryUsage" -Value 2 -Force -ErrorAction SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
    -Name "LargeSystemCache" -Value 1 -Force -ErrorAction SilentlyContinue

# Firewall EdgeUpdate
$EdgeUpdateExe = "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
if (Test-Path $EdgeUpdateExe) {
    New-NetFirewallRule -DisplayName "Block EdgeUpdate Core" `
        -Direction Outbound -Program $EdgeUpdateExe -Action Block `
        -ErrorAction SilentlyContinue | Out-Null
    Write-Host "   Firewall: EdgeUpdate blocked." -ForegroundColor Gray
}

# Adobe Updater Firewall (only if present = installed version)
$AdobeUpdateExe = "C:\Program Files (x86)\Common Files\Adobe\OOBE\PDApp\UWA\updater.exe"
if (Test-Path $AdobeUpdateExe) {
    New-NetFirewallRule -DisplayName "Block Adobe Updater" `
        -Direction Outbound -Program $AdobeUpdateExe -Action Block `
        -ErrorAction SilentlyContinue | Out-Null
    Write-Host "   Firewall: Adobe Updater blocked." -ForegroundColor Gray
}

# Adobe Task Scheduler
$adobeTasks = @(
    "AdobeGCInvoker-1.0",
    "AdobeAAMUpdater-1.0",
    "Adobe Acrobat Update Task",
    "MicrosoftEdgeUpdateTaskMachineCore",
    "MicrosoftEdgeUpdateTaskMachineUA"
)
foreach ($t in $adobeTasks) {
    Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
}

# Run keys - autostart removal
& reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AdobeGCInvoker-1.0"   /f 2>$null
& reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "AdobeCCXProcess"      /f 2>$null
& reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "CCXProcess"           /f 2>$null
& reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "Adobe Creative Cloud" /f 2>$null

Write-Host "   DONE: Cache, Firewall and Tasks completed." -ForegroundColor Green

# ============================================================
# FINAL SUMMARY
# ============================================================
Write-Host "`n=== ADOBE TITANIUM COMPLETED ===" -ForegroundColor Cyan
if ($isLicensed) {
    Write-Host "   Applied profile  : LICENSED" -ForegroundColor Green
    Write-Host "   Generative AI     : Available (requires Adobe ID on first use)" -ForegroundColor Green
    Write-Host "   License services : Preserved" -ForegroundColor Green
} else {
    Write-Host "   Applied profile  : PORTABLE" -ForegroundColor Yellow
    Write-Host "   Generative AI     : Not available (requires Adobe ID)" -ForegroundColor Yellow
    Write-Host "   License services : Disabled" -ForegroundColor Yellow
}
Write-Host ""
Pause
