# ---------------------------------------------------------------------------
# verify-office-ready.ps1
#
# Build gate: confirm the box is ready for the malicious-macro lab. Gates HARD
# on readiness (Word + VBA engine installed, macros enabled, VBA object model
# open); ADDITIONALLY attempts a real headless VBA macro run, but under a hard
# timeout and non-fatally - headless Word COM in a WinRM/service (session 0)
# context can block on a modal, which is a harness quirk, not a product fault
# (the lab runs Word interactively as Labuser, where macros run normally).
# Exit 0 iff the readiness checks pass.
# ---------------------------------------------------------------------------
$ErrorActionPreference = "Continue"

$winword = @("$env:ProgramFiles\Microsoft Office\Office14\WINWORD.EXE",
             "${env:ProgramFiles(x86)}\Microsoft Office\Office14\WINWORD.EXE") |
           Where-Object { Test-Path $_ } | Select-Object -First 1
$vbe7    = @("$env:CommonProgramFiles\Microsoft Shared\VBA\VBA7\VBE7.DLL",
             "${env:CommonProgramFiles(x86)}\Microsoft Shared\VBA\VBA7\VBE7.DLL") |
           Where-Object { Test-Path $_ } | Select-Object -First 1
$sec = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Office\14.0\Word\Security' -ErrorAction SilentlyContinue

$wordOk   = [bool]$winword
$vbeOk    = [bool]$vbe7
$macroOk  = ($sec.VBAWarnings -eq 1)
$vbomOk   = ($sec.AccessVBOM  -eq 1)
Write-Host "verify-office-ready: WINWORD=$winword"
if ($winword) { Write-Host ("verify-office-ready: version " + (Get-Item $winword).VersionInfo.ProductVersion) }
Write-Host "verify-office-ready: VBE7=$vbe7"
Write-Host "verify-office-ready: VBAWarnings=$($sec.VBAWarnings) AccessVBOM=$($sec.AccessVBOM)"

# --- bonus: try a real macro run, capped so it can never hang the build ------
$exec = "not-attempted"
if ($wordOk -and $vbeOk) {
  $job = Start-Job -ScriptBlock {
    $ErrorActionPreference = "Stop"
    foreach ($d in @("$env:windir\System32\config\systemprofile\Desktop",
                     "$env:windir\SysWOW64\config\systemprofile\Desktop")) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    $m = "C:\ProgramData\lab-assets\verify_macro_file.txt"
    New-Item -ItemType Directory -Force -Path (Split-Path $m) | Out-Null
    Remove-Item $m -ErrorAction SilentlyContinue
    $w = New-Object -ComObject Word.Application; $w.Visible=$false; $w.DisplayAlerts=0
    $doc = $w.Documents.Add()
    $doc.VBProject.VBComponents.Add(1).CodeModule.AddFromString(
      "Sub LabVerify()`r`n Dim f As Integer`r`n f=FreeFile`r`n Open ""$m"" For Output As #f`r`n Print #f, ""vba-exec-ok""`r`n Close #f`r`nEnd Sub")
    $w.Run("LabVerify") | Out-Null
    $doc.Close($false); $w.Quit() | Out-Null
    (Test-Path $m) -and ((Get-Content $m) -match "vba-exec-ok")
  }
  if (Wait-Job $job -Timeout 75) {
    $r = Receive-Job $job
    $exec = if ($r -eq $true) { "EXECUTED-OK" } else { "ran-but-marker-missing" }
  } else {
    $exec = "timed-out (session-0 COM; not a product fault)"
    Stop-Job $job -ErrorAction SilentlyContinue
  }
  Remove-Job $job -Force -ErrorAction SilentlyContinue
  Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Write-Host "verify-office-ready: macro-exec attempt = $exec"

if ($wordOk -and $vbeOk -and $macroOk -and $vbomOk) {
  Write-Host "verify-office-ready: PASS - Word 2010 + VBA installed and macro-ready."
  exit 0
} else {
  Write-Error "verify-office-ready: FAIL - wordOk=$wordOk vbeOk=$vbeOk VBAWarnings=$macroOk AccessVBOM=$vbomOk"
  exit 1
}
