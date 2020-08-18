Set-PSDebug -Trace 1
choco feature enable -n allowGlobalConfirmation
choco install googlechrome
choco feature disable -n allowGlobalConfirmation
