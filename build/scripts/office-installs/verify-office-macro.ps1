Set-PSDebug -Trace 1
# ---------------------------------------------------------------------------
# verify-office-macro.ps1
#
# Build-time gate: prove that the exact primitive the lab exploits - a VBA
# macro running on document open, with the power to write a file and Shell out
# a process (which is what the msfvenom meterpreter stub does) - actually works
# on this Word install. Runs headless via Word COM automation as the build
# (vagrant) user. Exit code 0 = the macro ran and did both things; non-zero
# fails the build so a broken box is never packaged.
#
# Requires AccessVBOM=1 and VBAWarnings=1 (set by office-lab-regkeys.ps1).
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

# Word COM on a headless/service session needs a Desktop folder to exist for
# the profile, for BOTH the 64-bit and 32-bit (Office 2010 is 32-bit) views.
foreach ($d in @("$env:windir\System32\config\systemprofile\Desktop",
                 "$env:windir\SysWOW64\config\systemprofile\Desktop")) {
  New-Item -ItemType Directory -Force -Path $d | Out-Null
}

$fileMarker  = "C:\ProgramData\lab-assets\verify_macro_file.txt"
$shellMarker = "C:\ProgramData\lab-assets\verify_macro_shell.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $fileMarker) | Out-Null
Remove-Item $fileMarker,$shellMarker -ErrorAction SilentlyContinue

$word = $null
try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $word.DisplayAlerts = 0   # wdAlertsNone
  $doc = $word.Documents.Add()

  # Inject a standard VBA module (vbext_ct_StdModule = 1) that mirrors the
  # exploit's two capabilities: write a file, and Shell a process.
  $module = $doc.VBProject.VBComponents.Add(1)
  $code = @'
Sub LabVerify()
    Dim f As Integer
    f = FreeFile
    Open "C:\ProgramData\lab-assets\verify_macro_file.txt" For Output As #f
    Print #f, "vba-file-write-ok"
    Close #f
    Shell "cmd.exe /c echo vba-shell-ok> C:\ProgramData\lab-assets\verify_macro_shell.txt", vbHide
End Sub
'@
  $module.CodeModule.AddFromString($code)
  $word.Run("LabVerify") | Out-Null

  # Shell is async; give the spawned cmd a moment to write its marker.
  for ($i=0; $i -lt 20 -and -not (Test-Path $shellMarker); $i++) { Start-Sleep -Milliseconds 500 }

  $doc.Close($false)
}
finally {
  if ($word) { $word.Quit() | Out-Null; [Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null }
  Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

$fileOk  = (Test-Path $fileMarker)  -and ((Get-Content $fileMarker)  -match "vba-file-write-ok")
$shellOk = (Test-Path $shellMarker) -and ((Get-Content $shellMarker) -match "vba-shell-ok")
Remove-Item $fileMarker,$shellMarker -ErrorAction SilentlyContinue

if ($fileOk -and $shellOk) {
  Write-Host "verify-office-macro: PASS - VBA macro executed, file-write and Shell both worked."
  exit 0
} else {
  Write-Error "verify-office-macro: FAIL - fileOk=$fileOk shellOk=$shellOk. Word/VBA is not exploit-ready."
  exit 1
}
