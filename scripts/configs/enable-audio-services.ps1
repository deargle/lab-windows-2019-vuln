#https://gist.githubusercontent.com/loonison123/11240676/raw/e9c1a62e4eade4a4153624e1ecfb803237c59ab0/audioServicePowerShellCommands.ps1

# Get services related to audio 
#Get-Service | Where {$_.Name -match "audio"} | format-table -autosize

# Start the services
Get-Service | Where {$_.Name -match "audio"} | start-service

# Set the services startup types
Get-Service | Where {$_.Name -match "audio"} | set-service -StartupType "Automatic"

# Validate our startup changes (Should say- StartMode:Auto)
Get-WmiObject -class win32_service -filter "Name='AudioSrv'"
