Set-PSDebug -Trace 1
# ---------------------------------------------------------------------------
# office-rearm.ps1
#
# Reset Office 2010's no-key grace period back to a fresh ~30 days. The student
# runs this at lab start (Path A) so a box that has been on the shelf - and may
# already be in reduced-functionality mode - comes back fully functional.
#
# This rearms OFFICE, which is separate from Windows' own `slmgr /rearm`.
# Office 2010 allows up to 5 rearms per install. A REBOOT is required after,
# which the Vagrant provisioner triggers (reboot: true).
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

$osppRearm = @(
  "${env:CommonProgramFiles(x86)}\Microsoft Shared\OfficeSoftwareProtectionPlatform\OSPPREARM.EXE",
  "$env:CommonProgramFiles\Microsoft Shared\OfficeSoftwareProtectionPlatform\OSPPREARM.EXE"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $osppRearm) {
  throw "OSPPREARM.EXE not found. Is Office 2010 installed? (Path A ships it baked in.)"
}

Write-Host "office-rearm: running $osppRearm ..."
$p = Start-Process -FilePath $osppRearm -Wait -PassThru -NoNewWindow
Write-Host "office-rearm: OSPPREARM exit code $($p.ExitCode)."

# Show remaining grace / rearm status for visibility (best effort).
$ospp = @(
  "${env:ProgramFiles(x86)}\Microsoft Office\Office14\ospp.vbs",
  "$env:ProgramFiles\Microsoft Office\Office14\ospp.vbs"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ospp) {
  Write-Host "office-rearm: license status ---------------------------------"
  & cscript //Nologo $ospp /dstatus
  Write-Host "-------------------------------------------------------------"
}

Write-Host "office-rearm: DONE. Rebooting to apply the fresh grace period."
