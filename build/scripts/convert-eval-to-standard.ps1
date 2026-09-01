# ---------------------------------------------------------------------------
# convert-eval-to-standard.ps1
#
# The base box (peru/windows-server-2019-standard-x64-eval) ships a Server 2019
# EVALUATION SKU. That eval is 180 days from the base image's build date, and
# the newest base version still published is 20240201.01 - already years past
# expiry. So every box built from it inherits a hard-expired eval, which puts
# Windows in Notification mode and forces an hourly shutdown via WLMS. Rebasing
# does not help: there is no un-expired version of that box to rebase onto.
#
# `slmgr /rearm` does NOT recover an eval this far past expiry (the rearm count
# stays available but no grace is restored). The supported way off an expired
# evaluation is Microsoft's edition conversion: swap the Eval SKU for the full
# edition using the PUBLIC generic KMS client setup key. That retires the eval
# timer entirely - WLMS is removed, so the hourly shutdown goes away. The box is
# then simply an unactivated Standard install (desktop watermark, no shutdown),
# which is fine for an offline lab VM.
#
# Idempotent: converts only when the current edition is still an Eval SKU.
#
# NOTE: the key below is not a license. It is Microsoft's published GVLK for
# Server 2019 Standard, used to identify the edition during conversion.
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Continue"

$GVLK_SERVER_2019_STANDARD = "N69G4-B89J2-4G8F4-WWYCC-J464C"

$current = (& dism.exe /online /Get-CurrentEdition |
            Select-String 'Current Edition\s*:\s*(\S+)').Matches.Groups[1].Value
Write-Host "convert-eval-to-standard: current edition = $current"

if ($current -notmatch 'Eval') {
  Write-Host "convert-eval-to-standard: already a non-eval edition, nothing to do."
  exit 0
}

$targets = (& dism.exe /online /Get-TargetEditions | Select-String 'Target Edition') -join ' '
Write-Host "convert-eval-to-standard: target editions = $targets"
if ($targets -notmatch 'ServerStandard') {
  Write-Error "convert-eval-to-standard: FAIL - ServerStandard is not an available target edition."
  exit 1
}

# /NoRestart so Vagrant owns the reboot (see the reboot provisioner that follows
# this one). DISM returns 3010 = success, restart required; treat it as success.
& dism.exe /online /Set-Edition:ServerStandard /ProductKey:$GVLK_SERVER_2019_STANDARD /AcceptEula /NoRestart
$rc = $LASTEXITCODE
Write-Host "convert-eval-to-standard: dism exit = $rc"

if ($rc -ne 0 -and $rc -ne 3010) {
  Write-Error "convert-eval-to-standard: FAIL - dism /Set-Edition returned $rc."
  exit 1
}

Write-Host "convert-eval-to-standard: conversion staged; reboot required to apply."
exit 0
