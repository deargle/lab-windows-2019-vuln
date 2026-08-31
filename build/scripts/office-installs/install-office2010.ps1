Set-PSDebug -Trace 1
# ---------------------------------------------------------------------------
# install-office2010.ps1  (self-contained)
#
# Silently install Microsoft Office Professional Plus 2010 (Word only, no
# product key -> ~30-day grace) from the X16-52536 media, then apply the lab
# registry tuning (macros on, VBA object model on, first-run suppressed).
#
# SELF-CONTAINED on purpose: Vagrant's `shell` provisioner with `path:` uploads
# only THIS one file to the guest, so the setup config and the registry tuning
# are generated inline here rather than read from sibling files. Used two ways:
#   * BUILD TIME (normal path): baked in via build/Vagrantfile (BAKE_OFFICE=1).
#   * LAB START (fallback): `vagrant provision --provision-with install-word`,
#     for a box that was not built with BAKE_OFFICE=1.
#
# MEDIA SOURCE, looked for in order:
#   1. A CD/DVD drive containing \setup.exe and \ProPlus.WW  (attach the ISO as
#      a libvirt cdrom - fast, no copy).
#   2. A local .iso at $env:OFFICE_ISO_PATH or C:\ProgramData\lab-assets\office2010.iso
#      (mounted with Mount-DiskImage).
#   3. A URL in $env:OFFICE_ISO_URL (lab-start fallback install; must be
#      reachable without gcloud creds - signed URL / public object / mirror).
#
# Media: gs://security-assignments-vagrant-boxes/lab-isos/office2010-proplus-x86-X16-52536.iso
#        sha1 9f1d385a8989c4d4951b55f0edfaea9066b8f54e
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

function Apply-LabRegkeys {
  # Zero-click readiness for the student's Labuser account and the build user:
  #   * HKLM policy  -> machine-wide (covers Labuser + the vagrant build user)
  #   * Default hive -> new profiles (Labuser) inherit the first-run suppression
  $pol = "HKLM:\SOFTWARE\Policies\Microsoft\Office\14.0"
  New-Item -Path "$pol\Common\General" -Force | Out-Null
  New-Item -Path "$pol\Word\Security"  -Force | Out-Null
  Set-ItemProperty -Path "$pol\Common\General" -Name "ShownFirstRunOptin" -Type DWord -Value 1
  Set-ItemProperty -Path "$pol\Common\General" -Name "qmenable"           -Type DWord -Value 0
  Set-ItemProperty -Path "$pol\Word\Security"  -Name "VBAWarnings"        -Type DWord -Value 1
  Set-ItemProperty -Path "$pol\Word\Security"  -Name "AccessVBOM"         -Type DWord -Value 1

  $def = "C:\Users\Default\NTUSER.DAT"
  if (Test-Path $def) {
    $tag = "OFFICELAB_DEF"
    & reg load "HKU\$tag" $def | Out-Null
    try {
      & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Common\General" /v ShownFirstRunOptin /t REG_DWORD /d 1 /f | Out-Null
      & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Common\General" /v qmenable           /t REG_DWORD /d 0 /f | Out-Null
      & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Word\Security"  /v VBAWarnings        /t REG_DWORD /d 1 /f | Out-Null
      & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Word\Security"  /v AccessVBOM         /t REG_DWORD /d 1 /f | Out-Null
    } finally {
      [gc]::Collect(); Start-Sleep -Seconds 1
      & reg unload "HKU\$tag" | Out-Null
    }
    Write-Host "regkeys: stamped Default User hive."
  } else {
    Write-Host "regkeys: no Default hive; HKLM policy only."
  }
}

# Idempotency: skip the install if Word is already present.
$winword = @(
  "$env:ProgramFiles\Microsoft Office\Office14\WINWORD.EXE",
  "${env:ProgramFiles(x86)}\Microsoft Office\Office14\WINWORD.EXE"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($winword) {
  Write-Host "install-office2010: Word already at $winword - applying regkeys only."
  Apply-LabRegkeys
  exit 0
}

# Locate media: any drive (cdrom or mounted ISO) holding the Office media, else
# a local/downloaded ISO to mount. Scans ALL drive types because a hot-plugged
# libvirt cdrom sometimes enumerates as a non-type-5 volume.
function Find-MediaRoot {
  $disks = Get-WmiObject Win32_LogicalDisk
  Write-Host ("Find-MediaRoot: drives seen -> " + (($disks | ForEach-Object { "$($_.DeviceID)(type$($_.DriveType))" }) -join ", "))
  foreach ($d in $disks) {
    if ($d.DeviceID -and (Test-Path "$($d.DeviceID)\setup.exe") -and (Test-Path "$($d.DeviceID)\ProPlus.WW")) {
      Write-Host "Find-MediaRoot: media found on $($d.DeviceID)"
      return "$($d.DeviceID)\"
    }
  }
  return $null
}

$mediaRoot = Find-MediaRoot
$mountedImage = $null
if (-not $mediaRoot) {
  $isoPath = $env:OFFICE_ISO_PATH
  if (-not $isoPath -or -not (Test-Path $isoPath)) { $isoPath = "C:\ProgramData\lab-assets\office2010.iso" }
  if (-not (Test-Path $isoPath)) {
    $url = $env:OFFICE_ISO_URL
    if (-not $url) { throw "No Office media: no cdrom, no ISO at $isoPath, no OFFICE_ISO_URL. See office-installs/README.md." }
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

# Write the silent, no-key, Word-only setup config to a temp file.
$configPath = Join-Path $env:TEMP "office2010-word-only.xml"
@'
<Configuration Product="ProPlus">
  <Display Level="none" CompletionNotice="no" SuppressModal="yes" AcceptEula="yes" />
  <Logging Type="standard" Path="%temp%" Template="Office2010Setup(*).txt" />
  <OptionState Id="WORDFiles"      State="Local"  Children="force" />
  <OptionState Id="EXCELFiles"     State="Absent" Children="force" />
  <OptionState Id="OUTLOOKFiles"   State="Absent" Children="force" />
  <OptionState Id="PPTFiles"       State="Absent" Children="force" />
  <OptionState Id="ACCESSFiles"    State="Absent" Children="force" />
  <OptionState Id="ONENOTEFiles"   State="Absent" Children="force" />
  <OptionState Id="PubPrimary"     State="Absent" Children="force" />
  <OptionState Id="InfoPathFiles"  State="Absent" Children="force" />
  <OptionState Id="GrooveFiles"    State="Absent" Children="force" />
  <OptionState Id="SHAREDFiles"    State="Local" />
  <OptionState Id="TOOLSFiles"     State="Local" />
  <Setting Id="SETUP_REBOOT" Value="Never" />
</Configuration>
'@ | Set-Content -Path $configPath -Encoding ASCII

$setup = Join-Path $mediaRoot "setup.exe"
if (-not (Test-Path $setup)) { throw "setup.exe not found at $setup" }

try {
  Write-Host "install-office2010: running silent setup (several minutes)..."
  $p = Start-Process -FilePath $setup -ArgumentList "/config `"$configPath`"" -Wait -PassThru
  if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
    throw "Office setup failed, exit $($p.ExitCode). See %temp%\Office2010Setup(*).txt"
  }
  Write-Host "install-office2010: setup exit code $($p.ExitCode)."
} finally {
  if ($mountedImage) { Dismount-DiskImage -ImagePath $mountedImage.ImagePath | Out-Null; Write-Host "install-office2010: dismounted media." }
}

Apply-LabRegkeys
Write-Host "install-office2010: DONE. Word 2010 installed in no-key grace period."
