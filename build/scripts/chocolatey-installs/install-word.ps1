Set-PSDebug -Trace 1
choco feature enable -n allowGlobalConfirmation
choco install microsoft-office-deployment --params="'/Product:WordRetail /DisableUpdate:TRUE'"
choco feature disable -n allowGlobalConfirmation
