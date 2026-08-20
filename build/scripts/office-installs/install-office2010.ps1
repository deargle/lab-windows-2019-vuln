Set-PSDebug -Trace 1
# ---------------------------------------------------------------------------
# install-office2010.ps1
#
# Silently install Microsoft Office Professional Plus 2010 (Word only, no
# product key -> 30-day grace) from the X16-52536 media, then apply the lab
# registry tuning. Used two ways:
#
#   * BUILD TIME  (Path A): run during the box build so Word is baked in.
#   * LAB START   (Path B): run by the student via
#                 `vagrant provision --provision-with install-word`.
#
# MEDIA SOURCE - the script looks, in order, for:
#   1. An attached CD/DVD drive that contains \setup.exe and \ProPlus.WW
#      (the fast, no-copy option: attach the ISO as a libvirt cdrom at build).
#   2. A local .iso at $env:OFFICE_ISO_PATH or C:\ProgramData\lab-assets\office2010.iso
#      (mounted with Mount-DiskImage).
#   3. A download URL in $env:OFFICE_ISO_URL or office-iso-url.txt next to this
#      script (used for the student Path B; the URL must be reachable without
#      gcloud creds - a signed URL, a public object, or a course mirror).
#
# The genuine media is:
#   gs://security-assignments-vagrant-boxes/lab-isos/office2010-proplus-x86-X16-52536.iso
#   sha1 9f1d385a8989c4d4951b55f0edfaea9066b8f54e   md5 80c74952d1601690e22d461057f157df
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Idempotency: skip if Word is already present.
$winword = @(
  "$env:ProgramFiles\Microsoft Office\Office14\WINWORD.EXE",
  "${env:ProgramFiles(x86)}\Microsoft Office\Office14\WINWORD.EXE"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($winword) {
  Write-Host "install-office2010: Word already installed at $winword - skipping install."
  & "$scriptDir\office-lab-regkeys.ps1"
  exit 0
}

function Find-MediaRoot {
  # 1. CD/DVD drives
  foreach ($cd in (Get-WmiObject Win32_LogicalDisk -Filter "DriveType=5")) {
    if ($cd.DeviceID -and (Test-Path "$($cd.DeviceID)\setup.exe") -and (Test-Path "$($cd.DeviceID)\ProPlus.WW")) {
      return "$($cd.DeviceID)\"
    }
  }
  return $null
}

$mediaRoot = Find-MediaRoot
$mountedImage = $null

if (-not $mediaRoot) {
  # 2/3. Locate an ISO file (local or downloaded), then mount it.
  $isoPath = $env:OFFICE_ISO_PATH
  if (-not $isoPath -or -not (Test-Path $isoPath)) {
    $isoPath = "C:\ProgramData\lab-assets\office2010.iso"
  }
  if (-not (Test-Path $isoPath)) {
    $url = $env:OFFICE_ISO_URL
    $urlFile = Join-Path $scriptDir "office-iso-url.txt"
    if (-not $url -and (Test-Path $urlFile)) {
      $url = (Get-Content $urlFile | Where-Object { $_ -and -not $_.StartsWith('#') } | Select-Object -First 1).Trim()
    }
    if (-not $url) {
      throw "No Office media found: no cdrom, no ISO at $isoPath, and no OFFICE_ISO_URL / office-iso-url.txt. See office-installs/README.md."
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $isoPath) | Out-Null
    Write-Host "install-office2010: downloading media from $url ..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object Net.WebClient).DownloadFile($url, $isoPath)
  }
  Write-Host "install-office2010: mounting $isoPath ..."
  $mountedImage = Mount-DiskImage -ImagePath $isoPath -PassThru
  $vol = ($mountedImage | Get-Volume).DriveLetter
  $mediaRoot = "${vol}:\"
}

Write-Host "install-office2010: media root = $mediaRoot"
$setup  = Join-Path $mediaRoot "setup.exe"
$config = Join-Path $scriptDir "config-word-only.xml"
if (-not (Test-Path $setup))  { throw "setup.exe not found at $setup" }
if (-not (Test-Path $config)) { throw "config-word-only.xml not found at $config" }

try {
  Write-Host "install-office2010: running silent setup (this takes several minutes)..."
  $p = Start-Process -FilePath $setup -ArgumentList "/config `"$config`"" -Wait -PassThru
  # Office setup returns 0 (ok) or 3010 (ok, reboot required).
  if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
    throw "Office setup failed with exit code $($p.ExitCode). See %temp%\Office2010Setup(*).txt"
  }
  Write-Host "install-office2010: setup exit code $($p.ExitCode)."
}
finally {
  if ($mountedImage) {
    Dismount-DiskImage -ImagePath $mountedImage.ImagePath | Out-Null
    Write-Host "install-office2010: dismounted media."
  }
}

# Apply the lab registry tuning (macros on, VBA object model on, no first-run).
& "$scriptDir\office-lab-regkeys.ps1"

Write-Host "install-office2010: DONE. Word 2010 installed in no-key grace period."
