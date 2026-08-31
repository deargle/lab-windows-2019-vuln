Set-PSDebug -Trace 1
choco feature enable -n allowGlobalConfirmation
choco install spice-guest-tools
choco feature disable -n allowGlobalConfirmation
