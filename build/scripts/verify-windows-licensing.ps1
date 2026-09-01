# ---------------------------------------------------------------------------
# verify-windows-licensing.ps1
#
# Build gate for the eval-expiry fix (see convert-eval-to-standard.ps1). Run
# AFTER the post-conversion reboot. Exit 0 iff the box is off the evaluation
# SKU and the eval shutdown enforcement is gone.
#
# Two checks, and the second is the one that matters:
#   1. Current edition is not an Eval SKU.
#   2. WLMS (Windows Licensing Monitoring Service) is ABSENT. WLMS is what
#      enforces the expired-eval hourly forced shutdown; edition conversion
#      removes it.
#
# Deliberately does NOT gate on `slmgr /xpr`. That prints "Notification mode"
# both before and after conversion - an expired eval and an unactivated full
# Standard share the string but not the behaviour (shutdown vs. watermark).
# Gating on it would fail a correctly-converted box.
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Continue"

$exitCode = 0

$edition = (& dism.exe /online /Get-CurrentEdition |
            Select-String 'Current Edition\s*:\s*(\S+)').Matches.Groups[1].Value
Write-Host "verify-windows-licensing: edition=$edition"
if ($edition -match 'Eval') {
  Write-Host "verify-windows-licensing: FAIL - still on an evaluation SKU ($edition)."
  $exitCode = 1
} else {
  Write-Host "verify-windows-licensing: PASS - off the evaluation SKU."
}

$wlms = Get-Service wlms -ErrorAction SilentlyContinue
Write-Host ("verify-windows-licensing: wlms=" + $(if ($wlms) { "PRESENT ($($wlms.Status))" } else { "ABSENT" }))
if ($wlms) {
  Write-Host "verify-windows-licensing: FAIL - WLMS still present; eval shutdown enforcement remains."
  $exitCode = 1
} else {
  Write-Host "verify-windows-licensing: PASS - WLMS absent; no eval shutdown enforcement."
}

# Informational only - see the header on why this is not a gate.
Write-Host ("verify-windows-licensing: xpr = " +
            ((& cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr) -join ' '))

if ($exitCode -eq 0) {
  Write-Host "verify-windows-licensing: PASS"
} else {
  Write-Error "verify-windows-licensing: FAIL - see above for details."
}
exit $exitCode
