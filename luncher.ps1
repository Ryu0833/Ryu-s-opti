# Ryu's Opti Launcher Script
# Automatically downloads and executes the remote launcher from GitHub

$url = "https://raw.githubusercontent.com/Ryu0833/Ryu-s-opti/master/launcher.ps1"
Write-Host "Downloading and executing Ryu's Opti launcher..." -ForegroundColor Cyan
Invoke-Expression (Invoke-WebRequest -Uri $url -UseBasicParsing).Content