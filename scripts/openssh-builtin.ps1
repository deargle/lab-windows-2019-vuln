# https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
$state = (Get-WindowsCapability -Online | ? Name -like "*OpenSSH.Server*" | Select -ExpandProperty 'State')

if ($state -eq 'Installed') {
  Write-Host 'OpenSSH Server already installed, exiting.'
  Exit
}


# Install the OpenSSH Client 
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 

# Install the OpenSSH Server 
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

Start-Service sshd

# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'

