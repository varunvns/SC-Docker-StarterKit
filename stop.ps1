#Requires -RunAsAdministrator

#Stops the running Docker containers - its a must to execute this before you shutdown or hibernate your machine
Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force
Write-Host "Stopping the environment..." -ForegroundColor DarkYellow
Stop-Docker -TakeDown -PruneSystem