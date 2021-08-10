using namespace System.Management.Automation.Host

Set-StrictMode -Version Latest

function Write-SuccessMessage {
    param(
        [string]
        $message
    )
    Write-Host $message -ForegroundColor Green
}

function Write-ErrorMessage {
    param(
        [string]
        $message
    )
    Write-Host $message -ForegroundColor Red
}

function Test-IsEnvInitialized {
    $name = Get-EnvValueByKey "COMPOSED_PROJECT_NAME"
    return ($null -ne $name -and $name -ne "")
}

function Get-EnvValueByKey {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $key,
        [ValidateNotNullOrEmpty()]
        [string]
        $filePath = ".env",
        [ValidateNotNullOrEmpty()]
        [string]
        $dockerRoot = ".\docker"
    )
    if (!(Test-Path $filePath)) {
        $filePath = Join-Path $dockerRoot $filePath
    }
    # If .env file is not found, then return empty string
    if (!(Test-Path $filePath)) {
        return ""
    }
    select-string -Path $filePath -Pattern "^$key=(.+)$" | % { $_.Matches.Groups[1].Value }
}

function Install-SitecoreDockerTools {
    Import-Module PowerShellGet
    $sitecoreGallery = Get-PSRepository | Where-Object { $_.SourceLocation -eq "https://sitecore.myget.org/F/sc-powershell/api/v2" }
    if (-not $sitecoreGallery) {
        Write-SuccessMessage "Adding Sitecore PowerShell Gallery..."
        Register-PSRepository -Name SitecoreGallery -SourceLocation https://sitecore.myget.org/F/sc-powershell/api/v2 -InstallationPolicy Trusted
        $SitecoreGallery = Get-PSRepository -Name SitecoreGallery
    }

    $dockerToolsVersion = "10.1.4"
    Remove-Module SitecoreDockerTools -ErrorAction SilentlyContinue
    if (-not (Get-InstalledModule -Name SitecoreDockerTools -RequiredVersion $dockerToolsVersion -ErrorAction SilentlyContinue)) {
        Write-SuccessMessage -Message "Installing SitecoreDockerTools..."
        Install-Module SitecoreDockerTools -RequiredVersion $dockerToolsVersion -Scope CurrentUser -Repository $sitecoreGallery.Name
    }
    Write-SuccessMessage -Message "Importing SitecoreDockerTools..."
    Import-Module SitecoreDockerTools -RequiredVersion $dockerToolsVersion
}

function Initialize-HostNames {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $hostDomain
    )
    Write-SuccessMessage -Message "Adding hosts file entries..."

    Add-HostsEntry "cm.$($hostDomain)"
    Add-HostsEntry "cd.$($hostDomain)"
    Add-HostsEntry "id.$($hostDomain)"
    Add-HostsEntry "www.$($hostDomain)"

    if (!(Test-Path ".\docker\traefik\certs\cert.pem")) {
        & ".\tools\mkcert.ps1" -FullHostName $hostDomain
    }
}

function Read-ValueFromHost {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Question,
        [ValidateNotNullOrEmpty()]
        [string]
        $DefaultValue,
        [ValidateNotNullOrEmpty()]
        [string]
        $ValidationRegEx,
        [switch]$Required
    )
    Write-Host ""
    do {
        Write-PrePrompt
        $value = Read-Host $question
        if ($value -eq "" -band $defaultValue -ne "") { $value = $defaultValue }
        $invalid = ($required -and $value -eq "")
    }while ($invalid -bor $value -eq "q")
    $value
}

function Write-PrePrompt {
    Write-Host "> " -NoNewline -ForegroundColor Yellow
}

function Confirm {    
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $Question,
        [switch] 
        $DefaultYes
    )
    $options = [ChoiceDescription[]](
        [ChoiceDescription]::new("&Yes"), 
        [ChoiceDescription]::new("&No")
    )
    $defaultOption = 1;
    if ($DefaultYes) { $defaultOption = 0 }
    Write-Host ""
    Write-PrePrompt
    $result = $host.ui.PromptForChoice("", $Question, $options, $defaultOption)
    switch ($result) {
        0 { return $true }
        1 { return $false }
    }
}

function Remove-EnvHostsEntry {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $Key,
        [Switch]
        $Build        
    )
    $hostName = Get-EnvValueByKey $Key
    if ($null -ne $hostName -and $hostName -ne "") {
        Remove-HostsEntry $hostName
    }
}

function Select-SitecoreTopology {
    # $topology = "xp0"

    $options = [ChoiceDescription[]](
        [ChoiceDescription]::new("XP&0 (default)"),
        [ChoiceDescription]::new("XP&1")
    )

    Write-PrePrompt
    $result = $host.ui.PromptForChoice("", "Select the topology you want to setup.", $options, 0)
    switch ($result) {
        0 { "xp0" }
        1 { "xp1" }
    }
}

function Install-Kit {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Topology,
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit",
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [bool]$AddHorizon,
        [bool]$AddSXA,
        [bool]$AddSPS,
        [bool]$AddCD,
        [bool]$AddSMS
    )

    # $foldersRoot = Join-Path $StarterKitRoot "\docker\build\base"
    $solutionFiles = Join-Path $StarterKitRoot "\solution\*"

    if (Test-Path $DestinationFolder) {
        Remove-Item $DestinationFolder -Force -Recurse
    }
    New-Item $DestinationFolder -ItemType directory

    if ((Test-Path $solutionFiles)) {
        Write-SuccessMessage "Copying solution and msbuild files for local docker setup..."
        Copy-Item $solutionFiles ".\" -Recurse -Force

        Rename-Item ".\Directory.build.props.sample" "Directory.build.props" -Force
        Rename-Item ".\Directory.build.targets.sample" "Directory.build.targets"
        Rename-Item ".\Docker.pubxml.sample" "Docker.pubxml"
    }

    if ($Topology -eq "xp0") {
        Copy-XP0Kit -DestinationFolder $DestinationFolder -AddCD $AddCD
        Update-Files -DestinationFolder $DestinationFolder -AddHorizon $AddHorizon -AddSXA $AddSXA -AddSPS $AddSPS -AddCD $AddCD -AddSMS $AddSMS
    }
}

function Upgrade {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Topology,
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit",
        [bool]$AddHorizon,
        [bool]$AddSXA,
        [bool]$AddSPS,
        [bool]$AddCD,
        [bool]$AddSMS
    )
    Write-Host "Upgrading your existing docker preset..." -ForegroundColor Green
    Remove-DataFiles
    if ($AddHorizon) {
        Add-Horizon -DestinationFolder $DestinationFolder -StarterKitRoot $StarterKitRoot
        Push-Location ".\docker"
        $hostDomain = Get-EnvValueByKey "HOST_DOMAIN"
        Set-EnvFileVariable "ADD_HORIZON" -Value "true"
        Set-EnvFileVariable "HRZ_HOST" -Value "hrz.$($hostDomain)"
        Pop-Location
    }
    if ($AddCD) {
        $hasSXA = $false
        if ($AddSXA -or (Get-EnvValueByKey "ADD_SXA" -eq "true")) {
            $hasSXA = $true
        }
        Add-CD -HasSXA $hasSXA
        Push-Location ".\docker"
        $hostDomain = Get-EnvValueByKey "HOST_DOMAIN"
        Set-EnvFileVariable "ADD_CD" -Value "true"
        Set-EnvFileVariable "CD_HOST" -Value "cd.$($hostDomain)"
        Pop-Location
    }
    if ($AddSXA) {
        Write-Host "Adding SXA module to the docker preset..." -ForegroundColor Green
        Add-SXA -HorizonAdded $AddHorizon -AddCD $AddCD
        Set-EnvFileVariable "ADD_SXA" -Value "true"
    }
    if ($AddSPS) {
        Write-Host "Adding SPS module to the docker preset..." -ForegroundColor Green
        Add-SPS
        Set-EnvFileVariable "ADD_SPS" -Value "true"
    }
    if ($AddSMS) {
        Write-Host "Adding SMS (Sitecore Management Services) module to the docker preset..." -ForegroundColor Green
        Add-SMS
        Set-EnvFileVariable "ADD_SMS" -Value "true"
    }
    Write-Host "Upgrade is done..." -ForegroundColor Green
}

function Add-CD {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit",
        [bool]$HasSXA = $false
    )
    Write-Host "Adding CD role to the docker preset..." -ForegroundColor Green
    $foldersRoot = Join-Path $StarterKitRoot "\docker\sitecore\"
    $buildDirectoryPath = "$DestinationFolder\build"
    $path = "$((Join-Path $foldersRoot "cd"))"
    Write-Host "Copying $($path) to $buildDirectoryPath" -ForegroundColor Green
    Copy-Item $path $buildDirectoryPath -Force -Recurse
    $cdCompose = "$((Join-Path $StarterKitRoot "\docker\docker-compose.xp0-cd.override.yml"))"
    Copy-Item $cdCompose $DestinationFolder -Force

    if ($HasSXA) {
        Update-CDFiles
    }
}

function Update-Files {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit",
        [bool]$AddHorizon,
        [bool]$AddSXA,
        [bool]$AddSPS,
        [bool]$AddCD,
        [bool]$AddSMS
    )
    if ($AddCD) {
        $cdCompose = "$((Join-Path $StarterKitRoot "\docker\docker-compose.xp0-cd.override.yml"))"
        Copy-Item $cdCompose $DestinationFolder -Force
    }
    if ($AddHorizon) {
        Add-Horizon -DestinationFolder $DestinationFolder -StarterKitRoot $StarterKitRoot
    }
    if ($AddSXA) {
        Add-SXA -HorizonAdded $AddHorizon -DestinationFolder $DestinationFolder -StarterKitRoot $StarterKitRoot -AddCD $AddCD
    }
    if ($AddSPS) {
        Add-SPS -DestinationFolder $DestinationFolder -StarterKitRoot $StarterKitRoot
    }
    if ($AddSMS) {
        Add-SMS -DestinationFolder $DestinationFolder -StarterKitRoot $StarterKitRoot
    }
}

function Add-SMS {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit"
    )
    Write-Host "Adding the Sitecore Management Services module in the setup..." -ForegroundColor Green
    $fileToUpdate = Join-Path $DestinationFolder "\build\cm\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_SMS_IMAGE", "ARG SMS_IMAGE") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_SMS_IMAGE", "FROM `${SMS_IMAGE} as sms") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#Sms_Module", "# Add SMS module`nCOPY --from=sms \module\cm\content .\") | Set-Content -Path $fileToUpdate

    $fileToUpdate = Join-Path $DestinationFolder "\docker-compose.override.yml"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SMS_IMAGE", "SMS_IMAGE: `${SITECORE_MODULE_REGISTRY}sitecore-management-services-xp1-assets:`${SMS_VERSION:-latest}") | Set-Content -Path $fileToUpdate
}

function Add-SPS {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit"
    )
    Write-Host "Adding the Sitecore Publishing Service in the setup..." -ForegroundColor Green
    $fileToUpdate = Join-Path $DestinationFolder "\build\cm\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_SPS_ASSETS", "ARG SPS_ASSETS") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_SPS_ASSETS", "FROM `${SPS_ASSETS} as sps") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#Sps_Module", "# Add SPS module`nCOPY --from=sps \module\cm\content .\") | Set-Content -Path $fileToUpdate

    $fileToUpdate = Join-Path $DestinationFolder "\build\mssql\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_SPS_ASSETS", "ARG SPS_ASSETS") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_SPS_ASSETS", "FROM `${SPS_ASSETS} as sps") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#Sps_Module", "# Add SPS module`nCOPY --from=sps \module\db \sps_data`nRUN C:\DeployDatabases.ps1 -ResourcesDirectory C:\sps_data; `Remove-Item -Path C:\sps_data -Recurse -Force;") | Set-Content -Path $fileToUpdate

    $fileToUpdate = Join-Path $DestinationFolder "\docker-compose.override.yml"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SPS_ClientHost", "Sitecore_Publishing_Service_Url: ""http://sps/""") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SPS_ASSETS", "SPS_ASSETS: `${SITECORE_MODULE_REGISTRY}sitecore-sps-integration-xp1-assets:`${SPS_VERSION}") | Set-Content -Path $fileToUpdate

    $hrzCompose = "$((Join-Path $StarterKitRoot "\docker\docker-compose.sps.override.yml"))"
    Copy-Item $hrzCompose $DestinationFolder -Force
}

function Add-Horizon {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit"
    )
    Write-Host "Adding the Horizon module in the setup..." -ForegroundColor Green
    $fileToUpdate = Join-Path $DestinationFolder "\build\cm\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_HORIZON_RESOURCES_IMAGE", "ARG HORIZON_RESOURCES_IMAGE") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_HORIZON_RESOURCES_IMAGE", "FROM `${HORIZON_RESOURCES_IMAGE} as horizon_resources") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#Horizon_Module", "# Add horizon module`nCOPY --from=horizon_resources \module\cm\content \inetpub\wwwroot") | Set-Content -Path $fileToUpdate

    $fileToUpdate = Join-Path $DestinationFolder "\build\mssql\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_HORIZON_RESOURCES_IMAGE", "ARG HORIZON_RESOURCES_IMAGE") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_HORIZON_RESOURCES_IMAGE", "FROM `${HORIZON_RESOURCES_IMAGE} as horizon_resources") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#Horizon_Module", "# Add Horizon module`nCOPY --from=horizon_resources \module\db \horizon_integration_data`nRUN C:\DeployDatabases.ps1 -ResourcesDirectory C:\horizon_integration_data; `Remove-Item -Path C:\horizon_integration_data -Recurse -Force; ") | Set-Content -Path $fileToUpdate

    $fileToUpdate = Join-Path $DestinationFolder "\docker-compose.override.yml"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#HORIZON_RESOURCES_IMAGE", "HORIZON_RESOURCES_IMAGE: `${SITECORE_MODULE_REGISTRY}horizon-integration-xp0-assets:`${HORIZON_ASSET_VERSION}") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#hrz_allowed_origin", "Sitecore_Sitecore__IdentityServer__Clients__DefaultClient__AllowedCorsOrigins__AllowedCorsOriginsGroup2: https://`${HRZ_HOST}") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#Sitecore_Horizon_ClientHost", "Sitecore_Horizon_ClientHost: https://`${HRZ_HOST}") | Set-Content -Path $fileToUpdate

    $hrzCompose = "$((Join-Path $StarterKitRoot "\docker\docker-compose.hrz.override.yml"))"
    Copy-Item $hrzCompose $DestinationFolder -Force
}

function Update-CDFiles {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit"
    )
    $fileToUpdate = Join-Path $DestinationFolder "\build\cd\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_SXA_IMAGE", "ARG SXA_IMAGE") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_SXA_IMAGE", "FROM `${SXA_IMAGE} as sxa") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SXA_Module", "# Add SXA module`nCOPY --from=sxa \module\cd\content .\`nCOPY --from=sxa \module\tools \module\tools`nRUN C:\module\tools\Initialize-Content.ps1 -TargetPath .\; `Remove-Item -Path C:\module -Recurse -Force;") | Set-Content -Path $fileToUpdate
    $fileToUpdate = Join-Path $DestinationFolder "\docker-compose.xp0-cd.override.yml"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SXA_IMAGE", "SXA_IMAGE: `${SITECORE_MODULE_REGISTRY}sxa-xp1-assets:`${SXA_VERSION}") | Set-Content -Path $fileToUpdate
}

function Add-SXA {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [ValidateNotNullOrEmpty()]
        [string]
        $StarterKitRoot = ".\kit",
        [bool]$HorizonAdded,
        [bool]$AddCD
    )
    Write-Host "Adding the SXA module in the setup..." -ForegroundColor Green
    $fileToUpdate = Join-Path $DestinationFolder "\build\cm\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_SXA_IMAGE", "ARG SXA_IMAGE") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_SXA_IMAGE", "FROM `${SXA_IMAGE} as sxa") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SXA_Module", "# Add SXA module`nCOPY --from=sxa \module\cm\content .\`nCOPY --from=sxa \module\tools \module\tools`nRUN C:\module\tools\Initialize-Content.ps1 -TargetPath .\; `Remove-Item -Path C:\module -Recurse -Force;") | Set-Content -Path $fileToUpdate

    if ($AddCD) {
        Update-CDFiles
    }

    $fileToUpdate = Join-Path $DestinationFolder "\build\mssql\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_SXA_IMAGE", "ARG SXA_IMAGE") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_SXA_IMAGE", "FROM `${SXA_IMAGE} as sxa") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SXA_Module", "# Add SXA module`nCOPY --from=sxa \module\db \sxa_data`nRUN C:\DeployDatabases.ps1 -ResourcesDirectory C:\sxa_data; `Remove-Item -Path C:\sxa_data -Recurse -Force;") | Set-Content -Path $fileToUpdate

    $fileToUpdate = Join-Path $DestinationFolder "\build\solr-init\Dockerfile"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#ARG_SXA_IMAGE", "ARG SXA_IMAGE") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#FROM_SXA_IMAGE", "FROM `${SXA_IMAGE} as sxa") | Set-Content -Path $fileToUpdate
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SXA_Module", "# Add SXA module`nCOPY --from=sxa C:\module\solr\cores-sxa.json C:\data\cores-sxa.json") | Set-Content -Path $fileToUpdate

    $fileToUpdate = Join-Path $DestinationFolder "\docker-compose.override.yml"
    ((Get-Content -Path $fileToUpdate -Raw) -replace "#SXA_IMAGE", "SXA_IMAGE: `${SITECORE_MODULE_REGISTRY}sxa-xp1-assets:`${SXA_VERSION}") | Set-Content -Path $fileToUpdate

    $hrzCompose = "$((Join-Path $StarterKitRoot "\docker\docker-compose.solr-init.override.yml"))"
    Copy-Item $hrzCompose $DestinationFolder -Force

    if ($HorizonAdded) {
        Write-Host "Horizon is included in the setup and hence activating Sitecore plugins filter for SXA in Horizon..." -ForegroundColor Green
        $hrzCompose = "$((Join-Path $DestinationFolder "\docker-compose.hrz.override.yml"))"
        ((Get-Content -Path $hrzCompose -Raw) -replace "#Sitecore_Plugins__Filters__ExperienceAccelerator", "Sitecore_Plugins__Filters__ExperienceAccelerator: +SXA") | Set-Content -Path $hrzCompose
    }
}

function Copy-XP0Kit {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [bool]$AddCD
    )
    $foldersRoot = Join-Path $StarterKitRoot "\docker\sitecore\"

    $xp0Services = "cm,id,mssql,dotnetsdk,xconnect,xdbsearchworker,xdbautomationworker,cortexprocessingworker,solr-init"

    if ($AddCD) {
        $xp0Services = $xp0Services + ",cd"
    }

    if (Test-Path $DestinationFolder) {
        Remove-Item $DestinationFolder -Force
    }
    New-Item $DestinationFolder -ItemType directory

    $buildDirectoryPath = "$DestinationFolder\build"

    New-Item $buildDirectoryPath -ItemType directory

    foreach ($folder in $xp0Services.Split(",")) {
        $path = "$((Join-Path $foldersRoot $folder))"
        Write-Host "Copying $($path) to $buildDirectoryPath" -ForegroundColor Green
        Copy-Item $path $buildDirectoryPath -Force -Recurse
    }

    Copy-CommonFolders -DestinationFolder $DestinationFolder

    $composeFilesPath = Join-Path $StarterKitRoot "\docker\sitecore-xp0\*"
    $dockerFilePath = Join-Path $StarterKitRoot "\docker\Dockerfile"
    $sampleEnvFilePath = Join-Path $StarterKitRoot "\docker\.env.sample"
    $envFilePath = Join-Path $DestinationFolder "\.env"

    Copy-Item $composeFilesPath $DestinationFolder -Force
    Write-SuccessMessage "Creating .env file at $envFilePath..."
    Copy-Item $sampleEnvFilePath $envFilePath -Force
    Write-SuccessMessage "Copying Dockerfile..."
    Copy-Item $dockerFilePath ".\" -Force
}

function Copy-CommonFolders {
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker\"
    )

    $foldersRoot = Join-Path $StarterKitRoot "\docker\"

    Write-SuccessMessage "Creating $($foldersRoot)data folder..."
    Copy-Item "$($foldersRoot)data" $DestinationFolder -Recurse -Force
    Write-SuccessMessage "Creating $($foldersRoot)deploy folder..."
    Copy-Item "$($foldersRoot)deploy" $DestinationFolder -Recurse -Force
    Write-SuccessMessage "Creating $($foldersRoot)traefik folder..."
    Copy-Item "$($foldersRoot)traefik" $DestinationFolder -Recurse -Force
    Write-SuccessMessage "Creating $($foldersRoot)license folder..."
    Copy-Item "$($foldersRoot)license" $DestinationFolder -Recurse -Force
}

function Rename-SolutionFile {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $SolutionName,
        [ValidateNotNullOrEmpty()]
        [string] 
        $FileToRename = ".\_kit.sln"
    )
    if ((Test-Path $FileToRename) -and !(Test-Path ".\$($SolutionName).sln")) {
        Write-Host "Creating solution file: $($SolutionName).sln" -ForegroundColor Green
        Move-Item $FileToRename ".\$($SolutionName).sln"
    }
}

function Initialize-EnvFile {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $SolutionName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $HostDomain,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $Topology,
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationFolder = ".\docker",
        [bool]$AddHorizon,
        [bool]$AddSXA,
        [bool]$AddSPS,
        [bool]$AddCD,
        [bool]$AddSMS
    )
    Push-Location ".\docker"
    Set-EnvFileVariable "COMPOSE_PROJECT_NAME" -Value $SolutionName.ToLower()
    Set-EnvFileVariable "HOST_LICENSE_FOLDER" -Value ".\license"
    Set-EnvFileVariable "HOST_DOMAIN"  -Value $hostDomain
    Set-EnvFileVariable "CM_HOST" -Value "cm.$($hostDomain)"
    Set-EnvFileVariable "TOPOLOGY" -Value $Topology
    if ($Topology -eq "xp1") {
        Set-EnvFileVariable "CD_HOST" -Value "cd.$($hostDomain)"
    }
    Set-EnvFileVariable "ID_HOST" -Value "id.$($hostDomain)"
    if ($AddHorizon) {
        Set-EnvFileVariable "ADD_HORIZON" -Value "true"
        Set-EnvFileVariable "HRZ_HOST" -Value "hrz.$($hostDomain)"
    }
    if ($AddSXA) {
        Set-EnvFileVariable "ADD_SXA" -Value "true"
    }
    if ($AddSPS) {
        Set-EnvFileVariable "ADD_SPS" -Value "true"
    }
    if ($AddSMS) {
        Set-EnvFileVariable "ADD_SMS" -Value "true"
    }
    if ($AddCD) {
        Set-EnvFileVariable "ADD_CD" -Value "true"
        Set-EnvFileVariable "CD_HOST" -Value "cd.$($hostDomain)"
    }
    # Set-EnvFileVariable "RENDERING_HOST" -Value "www.$($hostDomain)"
    Set-EnvFileVariable "REPORTING_API_KEY" -Value (Get-SitecoreRandomString 128 -DisallowSpecial)
    Set-EnvFileVariable "TELERIK_ENCRYPTION_KEY" -Value (Get-SitecoreRandomString 128)
    Set-EnvFileVariable "MEDIA_REQUEST_PROTECTION_SHARED_SECRET" -Value (Get-SitecoreRandomString 64 -DisallowSpecial)
    Set-EnvFileVariable "SITECORE_IDSECRET" -Value (Get-SitecoreRandomString 64 -DisallowSpecial)
    $idCertPassword = Get-SitecoreRandomString 8 -DisallowSpecial
    Set-EnvFileVariable "SITECORE_ID_CERTIFICATE" -Value (Get-SitecoreCertificateAsBase64String -DnsName "localhost" -Password (ConvertTo-SecureString -String $idCertPassword -Force -AsPlainText))
    Set-EnvFileVariable "SITECORE_ID_CERTIFICATE_PASSWORD" -Value $idCertPassword
    Set-EnvFileVariable "SQL_SA_PASSWORD" -Value (Get-SitecoreRandomString 19 -DisallowSpecial -EnforceComplexity)
    Set-EnvFileVariable "SITECORE_VERSION" -Value (Read-ValueFromHost -Question "Sitecore image version`n(10.1-ltsc2019, 10.1-1909, 10.1-2004, 10.1-20H2 - press enter for 10.1-ltsc2019)" -DefaultValue "10.1-ltsc2019" -Required)
    Set-EnvFileVariable "SITECORE_ADMIN_PASSWORD" -Value (Read-ValueFromHost -Question "Sitecore admin password (press enter for 'b')" -DefaultValue "b" -Required)

    if (Confirm -Question "Would you like to adjust common environment settings?") {
        Set-EnvFileVariable "SPE_VERSION" -Value (Read-ValueFromHost -Question "Sitecore Powershell Extensions version (press enter for 6.2-1809)" -DefaultValue "6.2-1809" -Required)
        Set-EnvFileVariable "REGISTRY" -Value (Read-ValueFromHost -Question "Local container registry (leave empty if none, must end with /)")
        Set-EnvFileVariable "ISOLATION" -Value (Read-ValueFromHost -Question "Container isolation mode (press enter for default)" -DefaultValue "default" -Required)
    }

    if (Confirm -Question "Would you like to adjust container memory limits?") {
        Set-EnvFileVariable "MEM_LIMIT_SQL" -Value (Read-ValueFromHost -Question "SQL Server memory limit (default: 4GB)" -DefaultValue "4GB" -Required)
        Set-EnvFileVariable "MEM_LIMIT_SOLR" -Value (Read-ValueFromHost -Question "Solr memory limit (default: 2GB)" -DefaultValue "2GB" -Required)
        Set-EnvFileVariable "MEM_LIMIT_CM" -Value (Read-ValueFromHost -Question "CM Server memory limit (default: 4GB)" -DefaultValue "4GB" -Required)
        if ($Topology -eq "xp1") {
            Set-EnvFileVariable "MEM_LIMIT_CD" -Value (Read-ValueFromHost -Question "CD Server memory limit (default: 4GB)" -DefaultValue "4GB" -Required)
        }
    }
    Pop-Location
}

function Start-Docker {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] 
        $Url,
        [ValidateNotNullOrEmpty()]
        [string] 
        $DockerRoot = ".\docker",
        [Switch]
        $Build
    )
    if (!(Test-Path ".\docker-compose.ym.")) {
        Push-Location $DockerRoot
    }
    if ($Build) {
        docker-compose build
    }
    $command = "docker-compose -f docker-compose.yml -f docker-compose.override.yml"
    if ((Get-EnvValueByKey "ADD_CD") -eq "true") {
        $command = $command + " -f docker-compose.xp0-cd.override.yml"
    }
    if ((Get-EnvValueByKey "ADD_HORIZON") -eq "true") {
        $command = $command + " -f docker-compose.hrz.override.yml"
    }
    if ((Get-EnvValueByKey "ADD_SXA") -eq "true") {
        $command = $command + " -f docker-compose.solr-init.override.yml"
    }
    if ((Get-EnvValueByKey "ADD_SPS") -eq "true") {
        $command = $command + " -f docker-compose.sps.override.yml"
    }
    
    $command = $command + " up -d"
    Write-Host "Command being executed: " $command
    Invoke-Expression $command
    Pop-Location

    Write-Host "...now wait for about 20 to 25 seconds to make sure Traefik is ready...`n`n`n" -ForegroundColor DarkYellow
    Write-Host "`ndon't forget to ""Populate Solr Managed Schema"" from the Control Panel`n`n`n" -ForegroundColor Yellow
    Write-Host "`nIf the request fails with a 404 on the first attempt then the dance wasn't long enough - just hit refresh..`n`n" -ForegroundColor DarkGray
    Start-Process "https://$url"
}

function Stop-Docker {
    param(
        [ValidateNotNullOrEmpty()]
        [string] 
        $DockerRoot = ".\docker",
        [Switch]$TakeDown,
        [Switch]$PruneSystem
    )
    if (!(Test-Path $DockerRoot)) {
        Write-Host "Docker environment not found and hence nothing to stop..." -ForegroundColor DarkMagenta
        return
    }
    if (!(Test-Path ".\docker-compose.yml")) {
        Push-Location $DockerRoot
    }
    if (Test-Path ".\docker-compose.yml") {
        $command = "docker-compose -f docker-compose.yml -f docker-compose.override.yml"
        if ((Get-EnvValueByKey "ADD_HORIZON") -eq "true") {
            $command = $command + " -f docker-compose.hrz.override.yml"
        }
        if ((Get-EnvValueByKey "ADD_SXA") -eq "true") {
            $command = $command + " -f docker-compose.solr-init.override.yml"
        }
        if ((Get-EnvValueByKey "ADD_SPS") -eq "true") {
            $command = $command + " -f docker-compose.sps.override.yml"
        }
        if ((Get-EnvValueByKey "ADD_CD") -eq "true") {
            $command = $command + " -f docker-compose.xp0-cd.override.yml"
        }
        if ($TakeDown) {
            $command = $command + " down"
        }
        else {
            $command = $command + " stop"
        }
        Write-Host "Command: $command"
        Invoke-Expression $command
        if ($PruneSystem) {
            docker system prune -f
        }
    }
    Pop-Location
}

function Remove-DataFiles {
    param(
        [ValidateNotNullOrEmpty()]
        [string] 
        $DockerRoot = ".\docker"
    )
    Write-Host "Deleting database files from $DockerRoot\data\mssql directory..." -ForegroundColor Red
    $mssqlPath = Join-Path $DockerRoot "\data\mssql\*"
    Remove-Item $mssqlPath -Exclude ".gitkeep" -Force
}