Set-PSDebug -Trace 1
choco feature enable -n allowGlobalConfirmation
choco install hashdeep
choco feature disable -n allowGlobalConfirmation
