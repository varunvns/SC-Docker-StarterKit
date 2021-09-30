#Requires -RunAsAdministrator
param(
  [switch]$Build,
  [switch]$StopBeforeStarting
)

Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force

Write-Host "Stopping any active and running containers before starting..." -ForegroundColor DarkYellow
if ($StopBeforeStarting) {
  Stop-Docker -TakeDown -PruneSystem
}

if ($Build) {
  Start-Docker -Url "$(Get-EnvValueByKey "CM_HOST")/sitecore" -Build
}
else {
  Start-Docker -Url "$(Get-EnvValueByKey "CM_HOST")/sitecore"
}
