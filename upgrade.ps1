#Requires -RunAsAdministrator

Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force
Clear-Host
Write-Host "Stopping the environment before upgrading..." -ForegroundColor DarkYellow
Stop-Docker -TakeDown -PruneSystem

$topology = (Get-EnvValueByKey "TOPOLOGY")
$isCDAdded = (Get-EnvValueByKey "ADD_CD")
$isSXAAdded = (Get-EnvValueByKey "ADD_SXA")
$isSPSAdded = (Get-EnvValueByKey "ADD_SPS")
$isSMSAdded = (Get-EnvValueByKey "ADD_SMS")
$isHorizonAdded = (Get-EnvValueByKey "ADD_HORIZON")

Write-Host "You have already setup the Sitecore $topology with Docker preset..." -ForegroundColor Green
if ($isHorizonAdded -or $isSXAAdded -or $isSPSAdded -or $isSMSAdded -or $isCDAdded) {
  Write-Host "We also found that following modules or roles are already included in the Docker preset..."
  if ($isHorizonAdded) {
    Write-Host "   - Horizon" -ForegroundColor Green
  }
  if ($isSXAAdded) {
    Write-Host "   - SXA" -ForegroundColor Green
  }
  if ($isSPSAdded) {
    Write-Host "   - SPS (Sitecore Publishing Service)" -ForegroundColor Green
  }
  if ($isCDAdded) {
    Write-Host "   - CD role" -ForegroundColor Green
  }
}
Write-Host "WARNING: WHILE UPGRADING THE DOCKER PRESET THE DATABASE FILES (.MDF AND .LDF) WILL BE DELETED FROM THE '/docker/data/mssql' DIRECTORY." -ForegroundColor Red
if (!(Confirm -Question "Would you like proceed?")) {
  Write-Host "Never mind..." -ForegroundColor Green
  exit 0
}

if (!$isHorizonAdded) {
  $addHorizon = Confirm -Question "Would you like to add Horizon module?"
}
else {
  $addHorizon = $false
}
if (!$isSPSAdded) {
  $addSPS = Confirm -Question "Would you like to add SPS module?"
}
else {
  $addSPS = $false
}
if (!$isSXAAdded) {
  $addSXA = Confirm -Question "Would you like to add SXA module?"
}
else {
  $addSXA = $false
}
if (!$isCDAdded) {
  $addCD = Confirm -Question "Would you like to add CD role to your docker setup? If you add CD in the XP0 topology it will also add the redis image which is required for CD to work."
}
else {
  $addCD = $false
}
if (!$isSMSAdded) {
  $addSMS = Confirm -Question "Would you like to add Sitecore Management Services module?"
}
else {
  $isSMSAdded = $false
}

Upgrade -Topology $topology -AddHorizon $addHorizon -AddSXA $addSXA -AddSPS $addSPS -AddCD $addCD -AddSMS $addSMS