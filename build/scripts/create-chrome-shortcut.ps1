Set-PSDebug -Trace 1
# ---------------------------------------------------------------------------
# create-chrome-shortcut.ps1
#
# `choco install googlechrome` installs Chrome machine-wide but drops no
# Public-Desktop shortcut, so students see no working Chrome desktop link.
# Create one, pointing at whichever install path Chrome actually used.
# ---------------------------------------------------------------------------

$chrome = @(
  "C:\Program Files\Google\Chrome\Application\chrome.exe",
  "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) {
  throw "create-chrome-shortcut: chrome.exe not found in either Program Files location."
}

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Google Chrome.lnk")
$Shortcut.TargetPath = $chrome
$Shortcut.WorkingDirectory = Split-Path $chrome
$Shortcut.save()

Write-Host "create-chrome-shortcut: shortcut created -> $chrome"
