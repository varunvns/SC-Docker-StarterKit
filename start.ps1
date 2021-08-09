#Requires -RunAsAdministrator
param(
  [switch]$Build
)

Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force

$Build = $true
Write-Host "Stopping any active and running containers before starting..." -ForegroundColor DarkYellow
Stop-Docker -TakeDown -PruneSystem
if ($Build) {
  Start-Docker -Url "$(Get-EnvValueByKey "CM_HOST")/sitecore" -Build
}
else {
  Start-Docker -Url "$(Get-EnvValueByKey "CM_HOST")/sitecore"
}
