Set-PSDebug -Trace 1
if (Test-Path "C:\Program Files (x86)\Icecast2 Win32\Icecast2.exe" -PathType Leaf){
  Write-Host "Icecast looks to be already installed. Exiting."
  Exit
}
cd "C:\Users\vagrant\Downloads"
wget 'https://ftp.osuosl.org/pub/xiph/releases/icecast/icecast2_win32_2.0.1_setup.exe' -out 'icecast_setup.exe'
"icecast_setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" | cmd

# Create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\Labuser\Desktop\Icecast2 Win32.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Icecast2 Win32\Icecast2.exe"
$Shortcut.WorkingDirectory = "C:\Program Files (x86)\Icecast2 Win32"
$Shortcut.save()
