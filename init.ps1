#Requires -RunAsAdministrator

Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force

Clear-Host

Write-Host "Stopping the environment..." -ForegroundColor DarkYellow
Stop-Docker -TakeDown -PruneSystem

# Initialize-Folder-Structure

$solutionName = Read-ValueFromHost -Question "Please enter a valid solution name`n(Capital first letter, letters and numbers only, min. 3 char)" -ValidationRegEx "^[A-Z]([a-z]|[A-Z]|[0-9]){2}([a-z]|[A-Z]|[0-9])*$" -required
Remove-Item ".\*.sln" -Force
if (Test-Path ".\Directory.build.props") {
    Remove-Item ".\Directory.build.*" -Force
}
if (Test-Path ".\Docker.pubxml") {
    Remove-Item ".\Docker.pubxml" -Force
}

# $topology = Select-SitecoreTopology

$topology = "xp0"

Write-Host "$($topology) topology applied by default. XP1 will be added in future" -ForegroundColor Magenta

$addHorizon = Confirm -Question "Would you like to add Horizon module to your docker setup?"
$addSXA = Confirm -Question "Would you like to add SXA module to your docker setup?"
$addSPS = Confirm -Question "Would you like to add Sitecore Publishing Service module to your docker setup?"
$addSMS = Confirm -Question "Would you like to add Sitecore Management Services module to your docker setup?"

$addCD = $False
if ($topology -eq "xp0") {
    $addCD = Confirm -Question "Would you like to add CD role to your docker setup? If you add CD in the XP0 topology it will also add the redis image which is required for CD to work."
}

# Write-Host $addCD

Install-Kit -Topology $topology -AddHorizon $addHorizon -AddSXA $addSXA -AddSPS $addSPS -AddCD $addCD -AddSMS $addSMS
Rename-SolutionFile $solutionName
Install-SitecoreDockerTools

$hostDomain = "$($solutionName.ToLower()).localhost"
$hostDomain = Read-ValueFromHost -Question "Domain hostname (press enter for $($hostDomain))" -DefaultValue $hostDomain -Required

do {
    $licenseFolderPath = Read-ValueFromHost -Question "Path to a folder that contains your Sitecore license.xml file `n- must contain a file named license.xml file (press enter for c:\sitecore\)" -DefaultValue "c:\sitecore\" -Required
} while (!(Test-Path (Join-Path $licenseFolderPath "license.xml")))

Copy-Item (Join-Path $licenseFolderPath "license.xml") ".\docker\license\"
Write-Host "Copied license.xml to .\docker\license\" -ForegroundColor Magenta
Initialize-EnvFile -SolutionName $solutionName -HostDomain $hostDomain -Topology $topology -AddHorizon $addHorizon -AddSXA $addSXA -AddSPS $AddSPS -AddCD $addCD -AddSMS $addSMS

Initialize-HostNames $hostDomain

Write-Host "ENVIRONMENT INITIALIZATION IS COMPLETED. PLEASE USE THE .\start.ps1 TO START THE DOCKER ENVIRONMENT..." -ForegroundColor DarkGreen