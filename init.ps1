#Requires -RunAsAdministrator

Import-Module -Name (Join-Path $PSScriptRoot "tools\cli") -Force

Clear-Host

Write-Host "Stopping the environment..." -ForegroundColor DarkYellow
Stop-Docker -TakeDown

# Initialize-Folder-Structure

$solutionName = Read-ValueFromHost -Question "Please enter a valid solution name`n(Capital first letter, letters and numbers only, min. 3 char)" -ValidationRegEx "^[A-Z]([a-z]|[A-Z]|[0-9]){2}([a-z]|[A-Z]|[0-9])*$" -required
Remove-Item ".\*.sln" -Force
$topology = Select-SitecoreTopology

Write-Host "$($topology) selected..." -ForegroundColor Magenta

$addHorizon = Confirm -Question "Would you like to add Horizon to your docker setup?"
$addSXA = Confirm -Question "Would you like to add SXA to your docker setup?"
$addSPS = Confirm -Question "Would you like to add Sitecore Publishing Service to your docker setup?"

Install-Kit -Topology $topology -AddHorizon $addHorizon -AddSXA $addSXA -AddSPS $addSPS
Rename-SolutionFile $solutionName
Install-SitecoreDockerTools

$hostDomain = "$($solutionName.ToLower()).localhost"
$hostDomain = Read-ValueFromHost -Question "Domain hostname (press enter for $($hostDomain))" -DefaultValue $hostDomain -Required

do {
    $licenseFolderPath = Read-ValueFromHost -Question "Path to a folder that contains your Sitecore license.xml file `n- must contain a file named license.xml file (press enter for .\License\)" -DefaultValue ".\License\" -Required
} while (!(Test-Path (Join-Path $licenseFolderPath "license.xml")))

Copy-Item (Join-Path $licenseFolderPath "license.xml") ".\docker\license\"
Write-Host "Copied license.xml to .\docker\license\" -ForegroundColor Magenta
Initialize-EnvFile -SolutionName $solutionName -HostDomain $hostDomain -Topology $topology -AddHorizon $addHorizon -AddSXA $addSXA -AddSPS $AddSPS

Initialize-HostNames $hostDomain

Write-Host "ENVIRONMENT INITIALIZATION IS COMPLETED. PLEASE USE THE .\start.ps1 TO START THE DOCKER ENVIRONMENT..." -ForegroundColor DarkGreen