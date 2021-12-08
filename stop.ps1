#Requires -RunAsAdministrator
Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force
Write-Host "Stopping the environment..." -ForegroundColor DarkYellow
Stop-Docker -TakeDown -PruneSystem