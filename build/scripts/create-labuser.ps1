Set-PSDebug -Trace 1
$USERNAME = "Labuser"

# create user if necessary

Try {
  $Secure_String_Pwd = ConvertTo-SecureString "Passw0rd!" -AsPlainText -Force
  New-LocalUser -Name $USERNAME -Password $Secure_String_Pwd -ErrorAction Stop
}
Catch [Microsoft.PowerShell.Commands.UserExistsException] {
  "User $($USERNAME) already exists, skipping." | Write-Host
}

# Make user an admin

Try {
  Add-LocalGroupMember -Group "Administrators" -Member $USERNAME -ErrorAction Stop
}
Catch [Microsoft.Powershell.Commands.MemberExistsException] {
  "User $($USERNAME) already a member of the Administrators group."
}

# set password to never expire
Set-LocalUser -Name $USERNAME -PasswordNeverExpires 1
