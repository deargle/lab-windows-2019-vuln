Set-PSDebug -Trace 1
if (Test-Path "C:\Program Files (x86)\Icecast2 Win32\Icecast2.exe" -PathType Leaf){
  Write-Host "Icecast looks to be already installed. Skipping..."
} else {
  cd "C:\Users\vagrant\Downloads"
  wget 'https://ftp.osuosl.org/pub/xiph/releases/icecast/icecast2_win32_2.0.1_setup.exe' -out 'icecast_setup.exe'
  "icecast_setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" | cmd
}

$USERNAME = "Labuser"

# Create desktop directory if not exists
$path = "C:\Users\$USERNAME\Desktop"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

# Create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$path\Icecast2 Win32.lnk")
$Shortcut.TargetPath = "C:\Program Files (x86)\Icecast2 Win32\Icecast2.exe"
$Shortcut.WorkingDirectory = "C:\Program Files (x86)\Icecast2 Win32"
$Shortcut.save()
