#Requires -RunAsAdministrator
Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force
Write-Host "Stopping any active and running containers before starting..." -ForegroundColor DarkYellow
Stop-Docker -TakeDown
Start-Docker -Url "$(Get-EnvValueByKey "CM_HOST")/sitecore" -Build