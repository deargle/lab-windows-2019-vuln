# ---------------------------------------------------------------------------
# verify-desktop-apps.ps1
#
# Build gate: confirm the desktop-facing fixes baked into this box actually
# work - Chrome has a Public-Desktop shortcut that resolves to a real exe, and
# the SPICE guest agent (clipboard support) is installed and running. Exit 0
# iff both checks pass.
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Continue"

$exitCode = 0

# --- Chrome: exe present + Public-Desktop shortcut resolves to it ----------
$chromePaths = @(
  "C:\Program Files\Google\Chrome\Application\chrome.exe",
  "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
)
$chrome = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
$shortcutPath = "C:\Users\Public\Desktop\Google Chrome.lnk"
$shortcutExists = Test-Path $shortcutPath

$shortcutTarget = $null
$shortcutOk = $false
if ($shortcutExists) {
  $WshShell = New-Object -comObject WScript.Shell
  $shortcutTarget = $WshShell.CreateShortcut($shortcutPath).TargetPath
  $shortcutOk = [bool]$chrome -and ($shortcutTarget -eq $chrome)
}

Write-Host "verify-desktop-apps: chrome.exe=$chrome"
Write-Host "verify-desktop-apps: shortcut=$shortcutPath exists=$shortcutExists target=$shortcutTarget"

$chromeOk = [bool]$chrome -and $shortcutExists -and $shortcutOk
if ($chromeOk) {
  Write-Host "verify-desktop-apps: PASS - Chrome installed and Public-Desktop shortcut resolves."
} else {
  Write-Host "verify-desktop-apps: FAIL - chromeExe=$([bool]$chrome) shortcutExists=$shortcutExists shortcutResolves=$shortcutOk"
  $exitCode = 1
}

# --- SPICE guest agent: service present and Running ------------------------
$spiceSvc = Get-Service -Name "vdservice" -ErrorAction SilentlyContinue
if (-not $spiceSvc) { $spiceSvc = Get-Service -Name "spice-vdagent" -ErrorAction SilentlyContinue }

if ($spiceSvc) {
  Write-Host "verify-desktop-apps: spice service=$($spiceSvc.Name) status=$($spiceSvc.Status)"
}

$spiceOk = [bool]$spiceSvc -and ($spiceSvc.Status -eq "Running")
if ($spiceOk) {
  Write-Host "verify-desktop-apps: PASS - SPICE guest agent ($($spiceSvc.Name)) is running."
} else {
  Write-Host "verify-desktop-apps: FAIL - SPICE guest agent (vdservice/spice-vdagent) not found or not running."
  $exitCode = 1
}

if ($exitCode -eq 0) {
  Write-Host "verify-desktop-apps: PASS"
} else {
  Write-Error "verify-desktop-apps: FAIL - see above for details."
}
exit $exitCode
