#Requires -RunAsAdministrator
param(
  [switch]$Build,
  [switch]$StopBeforeStarting
)

Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force

# Use this switch when you have already running containers and for some reason you want to restart the entire set of containers, 
# first you need to stop the running one.
if ($StopBeforeStarting) {
  Write-Host "Stopping any active and running containers before starting..." -ForegroundColor DarkYellow
  Stop-Docker -TakeDown -PruneSystem
}

# Use this switch when you want to rebuild the images after making changes to the Docker file associated with any of the Sitecore role
if ($Build) {
  Start-Docker -Url "$(Get-EnvValueByKey "CM_HOST")/sitecore" -Build
}
else {
  Start-Docker -Url "$(Get-EnvValueByKey "CM_HOST")/sitecore"
}
