choco feature enable -n allowGlobalConfirmation
choco install libreoffice-still
choco feature disable -n allowGlobalConfirmation

# Set Macro options to allow macros
$RegistryKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\LibreOffice\org.openoffice.Office.Common\Security\Scripting\MacroSecurityLevel"
$RegistryEntry = "Value"

if ( -Not ( Test-Path "$Key")){New-Item -Path "$Key" -ItemType RegistryKey -Force}

Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "2"

