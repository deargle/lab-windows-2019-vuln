Set-PSDebug -Trace 1
choco feature enable -n allowGlobalConfirmation
choco install aria2
choco feature disable -n allowGlobalConfirmation
