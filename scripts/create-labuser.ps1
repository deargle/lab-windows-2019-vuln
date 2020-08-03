Set-PSDebug -Trace 1
$USERNAME = "Labuser"

Try {
  $Secure_String_Pwd = ConvertTo-SecureString "Passw0rd!" -AsPlainText -Force
  New-LocalUser -Name $USERNAME -Password $Secure_String_Pwd -ErrorAction Stop
}
Catch [Microsoft.PowerShell.Commands.UserExistsException] {
  "User $($USERNAME) already exists, skipping." | Write-Host
}
Try {
Add-LocalGroupMember -Group "Administrators" -Member $USERNAME -ErrorAction Stop
}
Catch [Microsoft.Powershell.Commands.MemberExistsException] {
  "User $($USERNAME) already a member of the Administrators group."
}

