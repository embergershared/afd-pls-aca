# afd-pls-aca

Internet &lt;> Azure Front Door &lt;=Private Link Service=> Internal Container Environment &lt;> Container App

## Overview

This repo exposes Container Apps to the Public internet with a Azure Front Door through a Private Link origin.

It is a rework with terraform (instead of Bicep) of this [sebafo/frontdoor-container-apps](https://github.com/sebafo/frontdoor-container-apps)

It is unclear if this setup is fully supported by Microsoft.



resource Id: /subscriptions/ffeea140-0102-42f8-81be-8d07e272db59/resourceGroups/MC_blackpond-3f96a25d-rg_blackpond-3f96a25d_eastus2/providers/Microsoft.Compute/virtualMachineScaleSets/aks-systempool-29528777-vmss/virtualMachines/1, API version: 2022-03-01, {"code":"InvalidAuthenticationTokenTenant","message":"The access token is from the wrong issuer '<https://sts.windows.net/8c0e4ef1-25fa-4e52-b8da-835de296826e/>'. It must match the tenant '<https://sts.windows.net/33e01921-4d64-4f8c-a055-5bdaffd5e33d/>' associated with this subscription. Please use the authority (URL) '<https://login.windows.net/33e01921-4d64-4f8c-a055-5bdaffd5e33d>' to get the token. Note, if the subscription is transferred to another tenant there is no impact to the services, but information about new tenant could take time to propagate (up to an hour). If you just transferred your subscription and see this error message, please try back later."}
