# ============================================================
# Titanium OS Suite - Language File
# Culture: en-US (English - United States)
# ============================================================
@{
    # ---- SCRIPT NAME (used for log folder and file name) ----
    ScriptName          = "win11_HOME"

    # ---- HEADER LOG ----
    ReportTitle         = "TITANIUM V8 - OPTIMIZATION REPORT"
    LabelDate           = "Date"
    LabelComputer       = "Computer"
    LabelUser           = "User"
    LabelWindows        = "Windows"
    LabelCPU            = "CPU"
    LabelRAM            = "RAM"
    LabelPS             = "PowerShell"
    LabelRunAs          = "Run as"
    LabelRunAsSystem    = "SYSTEM (PowerRun)"
    LabelRunAsAdmin     = "Administrator"
    LabelLogDesktop     = "Log Desktop"
    LabelDetail         = "--- OPERATION DETAIL ---"

    # ---- RESTORE POINT ----
    RestoreCreating     = "[INIT] Creating restore point..."

    # ---- FOOTER ----
    FooterSummary       = "--- FINAL SUMMARY ---"
    FooterResult        = "RESULT"
    FooterSuccess       = "COMPLETED SUCCESSFULLY"
    FooterWithErrors    = "COMPLETED WITH ERRORS"
    FooterDuration      = "Duration"
    FooterMinutes       = "min"
    FooterSeconds       = "sec"
    FooterOK            = "OK"
    FooterWarnings      = "Warnings"
    FooterErrors        = "Errors"
    FooterSendFile      = "In case of problems, send this file to your technician."
    FooterBackupPath    = "Log backup:"

    # ---- FINAL CONSOLE SUMMARY ----
    SummaryTitle        = "=== TITANIUM V8 WIN11 HOME - COMPLETED ==="
    SummaryDefender     = " -> Defender/SmartScreen/Tamper Protection: DISABLED."
    SummaryBloatware    = " -> Bloatware Xbox/Teams/OneDrive/Recall: REMOVED."
    SummaryMSA          = " -> Microsoft Account and Consumer Features: BLOCKED."
    SummarySSD          = " -> SSD/NVMe: TRIM active, unnecessary writes eliminated."
    SummaryPerf         = " -> GPU/CPU/I/O Performance Engine: APPLIED."
    SummaryReboot       = " -> The system will reboot in 12 seconds."

    # ---- FINAL POPUP (MessageBox) ----
    PopupTitle          = "Titanium V8 - Completed"
    PopupBody           = "Optimization complete!`n`nA report has been saved to the Desktop:`n{0}`n`nIn case of problems, send this file to your technician.`n`nThe PC will restart in a few seconds."

    # ---- SEARCH INFO BOX (Block 12 - Home only) ----
    SearchInfoTitle     = "INFORMATION - Windows Search"
    SearchInfoLine1     = "The script is about to disable the Windows Search"
    SearchInfoLine2     = "box and the connection to the Microsoft cloud."
    SearchInfoLine3     = "File search on your PC will continue to work"
    SearchInfoLine4     = "via the EVERYTHING program (to be installed)."
    SearchInfoLine5     = "Will be disabled:"
    SearchInfoLine6     = "- Bing search from the taskbar"
    SearchInfoLine7     = "- Microsoft cloud suggestions"
    SearchInfoLine8     = "- Search box in the taskbar"
    SearchInfoLine9     = "- WebView2 Search (background process)"
    SearchInfoEnter     = "Press ENTER to continue..."

    # ---- WSEARCH CONFIRM (Block 16 - Home only) ----
    WSearchTitle        = "WARNING - Windows Search (WSearch)"
    WSearchLine1        = "The SEARCH YOUR FILES feature will be DISABLED."
    WSearchLine2        = "After disabling you will need to use EVERYTHING"
    WSearchLine3        = "to search for files on your PC."
    WSearchOptY         = "Y = Disable WSearch (recommended with Everything)"
    WSearchOptN         = "N = Keep WSearch active"
    WSearchPrompt       = "Disable Windows Search? (Y/N)"
    WSearchDisabled     = "WSearch: DISABLED. Use Everything to search files."
    WSearchKept         = "WSearch: KEPT on user request."
    WSearchNote1        = "NOTE: to search files use EVERYTHING"
    WSearchNote2        = "from the script folder: Everything\everything.exe"
    WSearchNote3        = "Launch it and drag the icon to the taskbar."

    # ---- ONEDRIVE POPUP (Block 26 - Home only) ----
    OneDriveTitle       = "Titanium V8 - OneDrive"
    OneDriveMsg         = "Do you want to disable OneDrive?`nIf you choose No, OneDrive remains operational."
    OneDriveDisabled    = "OneDrive: disabled on user request."
    OneDriveKept        = "OneDrive: kept active on user request."
}

