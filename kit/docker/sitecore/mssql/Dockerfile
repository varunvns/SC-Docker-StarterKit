# escape=`

ARG BASE_IMAGE
ARG SPE_IMAGE
#ARG_SXA_IMAGE
#ARG_HORIZON_RESOURCES_IMAGE
#ARG_SPS_ASSETS


FROM ${SPE_IMAGE} as spe
#FROM_SXA_IMAGE
#FROM_HORIZON_RESOURCES_IMAGE
#FROM_SPS_ASSETS
FROM ${BASE_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Add SPE module
COPY --from=spe \module\db \spe_data
RUN C:\DeployDatabases.ps1 -ResourcesDirectory C:\spe_data; `
    Remove-Item -Path C:\spe_data -Recurse -Force;

#SXA_Module

#Horizon_Module

#Sps_Module