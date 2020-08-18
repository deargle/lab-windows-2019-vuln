Set-PSDebug -Trace 1
choco feature enable -n allowGlobalConfirmation
choco install libreoffice-still
choco feature disable -n allowGlobalConfirmation

# Set Macro options to allow macros
$RegistryKey = "HKLM:\SOFTWARE\Policies\LibreOffice\org.openoffice.Office.Common\Security\Scripting\MacroSecurityLevel"
$RegistryEntry = "Value"

if ( -Not ( Test-Path "$RegistryKey")){New-Item -Path "$RegistryKey" -ItemType RegistryKey -Force}

Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "2"
