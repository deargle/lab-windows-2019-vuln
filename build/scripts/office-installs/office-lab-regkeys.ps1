Set-PSDebug -Trace 1
# ---------------------------------------------------------------------------
# office-lab-regkeys.ps1
#
# Make Office 2010 "ready to be exploited" with ZERO clicks for the student:
#   1. Suppress the Office 2010 first-run / privacy / activation-nag dialogs.
#   2. Enable all VBA macros with no prompt (VBAWarnings=1).
#   3. Allow programmatic access to the VBA project model (AccessVBOM=1) so the
#      headless verification (verify-office-macro.ps1) can inject+run a macro,
#      and so nothing blocks the lab's macro flow.
#
# The lab is performed as the local "Labuser" account, but provisioning runs as
# "vagrant" over WinRM. So we set:
#   * HKLM policy keys  -> apply machine-wide to EVERY user (covers Labuser and
#                          the vagrant build session that runs verification).
#   * the Default User hive -> so Labuser's profile inherits the first-run
#                          suppression when it is first created at logon.
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

# --- 1 + 2 + 3 : machine-wide Office policy (wins over per-user settings) ----
$pol = "HKLM:\SOFTWARE\Policies\Microsoft\Office\14.0"
New-Item -Path "$pol\Common\General"  -Force | Out-Null
New-Item -Path "$pol\Word\Security"   -Force | Out-Null

# Suppress first-run opt-in / customer experience / activation nag
Set-ItemProperty -Path "$pol\Common\General" -Name "ShownFirstRunOptin" -Type DWord -Value 1
Set-ItemProperty -Path "$pol\Common\General" -Name "qmenable"           -Type DWord -Value 0

# Enable all macros without notification, and allow VBA object-model access
Set-ItemProperty -Path "$pol\Word\Security" -Name "VBAWarnings"  -Type DWord -Value 1
Set-ItemProperty -Path "$pol\Word\Security" -Name "AccessVBOM"   -Type DWord -Value 1

# --- Also stamp the Default User hive so new profiles (Labuser) inherit -------
$def = "C:\Users\Default\NTUSER.DAT"
if (Test-Path $def) {
  $tag = "OFFICELAB_DEF"
  & reg load "HKU\$tag" $def | Out-Null
  try {
    foreach ($sub in @("Software\Microsoft\Office\14.0\Common\General",
                       "Software\Microsoft\Office\14.0\Word\Security")) {
      & reg add "HKU\$tag\$sub" /f | Out-Null
    }
    & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Common\General" /v ShownFirstRunOptin /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Common\General" /v qmenable           /t REG_DWORD /d 0 /f | Out-Null
    & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Word\Security"  /v VBAWarnings        /t REG_DWORD /d 1 /f | Out-Null
    & reg add "HKU\$tag\Software\Microsoft\Office\14.0\Word\Security"  /v AccessVBOM         /t REG_DWORD /d 1 /f | Out-Null
  }
  finally {
    [gc]::Collect(); Start-Sleep -Seconds 1
    & reg unload "HKU\$tag" | Out-Null
  }
  Write-Host "office-lab-regkeys: stamped Default User hive."
} else {
  Write-Host "office-lab-regkeys: C:\Users\Default\NTUSER.DAT not found; relying on HKLM policy only."
}

Write-Host "office-lab-regkeys: done."
