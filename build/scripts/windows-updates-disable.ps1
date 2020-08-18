Set-PSDebug -Trace 1
Clear-Host

$WindowsUpdatePath = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\"
$AutoUpdatePath = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

If(Test-Path -Path $WindowsUpdatePath) {
Remove-Item -Path $WindowsUpdatePath -Recurse
}

New-Item $WindowsUpdatePath -Force
New-Item $AutoUpdatePath -Force

Set-ItemProperty -Path $AutoUpdatePath -Name NoAutoUpdate -Value 1

Get-ScheduledTask -TaskPath "\Microsoft\Windows\WindowsUpdate\" | Disable-ScheduledTask

takeown /F C:\Windows\System32\Tasks\Microsoft\Windows\UpdateOrchestrator /A /R
icacls C:\Windows\System32\Tasks\Microsoft\Windows\UpdateOrchestrator /grant Administrators:F /T

Get-ScheduledTask -TaskPath "\Microsoft\Windows\UpdateOrchestrator\" | Disable-ScheduledTask

Stop-Service wuauserv
Set-Service wuauserv -StartupType Disabled

# We disable WindowsUpdate folder again, because wuauserv service could have enabled it meanwhile
Get-ScheduledTask -TaskPath "\Microsoft\Windows\WindowsUpdate\" | Disable-ScheduledTask

Write-Output "All Windows Updates were disabled"
