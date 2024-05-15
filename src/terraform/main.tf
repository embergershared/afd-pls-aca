# Description   : This Terraform creates an ACA in an Application Landing Zone
#                 It deploys:
#                   - 1 App Resource Group,
#                   - 1 VNet + 2 subnets
#                   - 1 Azure Container App Environment Internal with VNet integration + a Private Link Service
#                   - 1 Azure Container App in the Container App Environment
#                   - 1 Azure Front Door Profile with 1 Endpoint, 1 Origin Group, 1 Origin, and 1 Route
#                   - 1 Storage account with a private endpoint on the Container App VNet
#
#                 Notes:
#                   - This approach works with a managed by Microsoft Infrastructure resource group for ACA.
#                       If named, the kubernetes-internal Load Balancer is not exposed.
#                   - The Private Endpoint to the AFD origin must be accepted on the PLS.

# Folder/File   : 
# Terraform     : 1.0.+
# Providers     : azurerm 3.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2024-05-15
# Created by    : Emmanuel
# Last Modified : 
# Last Modif by : Emmanuel
# Modif desc.   : 


#--------------------------------------------------------------
#   Basics
#--------------------------------------------------------------
# Timestamp for the Created_on tag
resource "time_static" "this" {}

#--------------------------------------------------------------
#   App Landing Zone
#--------------------------------------------------------------
#   App Landing Zone Main resources
#   / Main region App LZ Resource Group
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.loc_sub}-${var.res_suffix}"
  location = var.location

  tags = local.base_tags
}
#   / Main region App LZ VNet
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.loc_sub}-${var.res_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]

  tags = azurerm_resource_group.this.tags
}
#   / Subnets &NSGs
#     / For ACA Environment
resource "azurerm_subnet" "acaenv_subnet" {
  name                                          = "acaenv-snet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = false
  address_prefixes                              = [replace(var.vnet_address_space, "4.0/22", "4.0/23")] # must be at least /23
}
resource "azurerm_network_security_group" "acaenv_subnet_nsg" {
  name = lower("nsg-${azurerm_subnet.acaenv_subnet.name}")

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = azurerm_resource_group.this.tags
}
resource "azurerm_subnet_network_security_group_association" "acaenv_subnet_to_nsg_association" {
  subnet_id                 = azurerm_subnet.acaenv_subnet.id
  network_security_group_id = azurerm_network_security_group.acaenv_subnet_nsg.id
}

#     / For Private Endpoints
resource "azurerm_subnet" "pe_subnet" {
  name                                          = "pe-snet"
  resource_group_name                           = azurerm_resource_group.this.name
  virtual_network_name                          = azurerm_virtual_network.this.name
  private_endpoint_network_policies             = "Enabled"
  private_link_service_network_policies_enabled = false
  address_prefixes                              = [replace(var.vnet_address_space, "4.0/22", "6.0/28")]
}
resource "azurerm_network_security_group" "pe_subnet_nsg" {
  name = lower("nsg-${azurerm_subnet.pe_subnet.name}")

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  tags = azurerm_resource_group.this.tags
}
#     / Association to Private Endpoints' subnet
resource "azurerm_subnet_network_security_group_association" "pe_subnet_to_nsg_association" {
  subnet_id                 = azurerm_subnet.pe_subnet.id
  network_security_group_id = azurerm_network_security_group.pe_subnet_nsg.id
}
#*/

#--------------------------------------------------------------
#   Azure Container App resources
#--------------------------------------------------------------
###  Internal Azure Container App with VNet integration
resource "azurerm_container_app_environment" "this" {
  name                = "aca-env-${var.res_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  infrastructure_subnet_id       = azurerm_subnet.acaenv_subnet.id # Must be /21 or larger
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = false
  log_analytics_workspace_id     = data.azurerm_log_analytics_workspace.main_region_logdiag_law.id

  # infrastructure_resource_group_name = "${azurerm_resource_group.this.name}-infra-priv"
  # workload_profile {
  #   name                  = "Consumption"
  #   workload_profile_type = "Consumption"
  # }

  tags = azurerm_resource_group.this.tags

  # Id format: "/subscriptions/<subId>/resourceGroups/rgName<>/providers/Microsoft.App/managedEnvironments/afd-aca-pls-aca-env"
}
resource "azurerm_container_app" "this" {
  name                         = substr("aca-app-${var.res_suffix}", 0, 32)
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    container {
      name   = "aca-welcome"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"

    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true # To allow connection from the VNet
    target_port                = 80
    transport                  = "http" # "auto"

    traffic_weight {
      latest_revision = true # required during creation
      percentage      = 100
    }
  }

  # Id format: "/subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.App/containerApps/afd-aca-pls-aca-hello-app"
}
resource "azurerm_private_link_service" "this" {
  name                = "pls-to-aca-env-${var.res_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  load_balancer_frontend_ip_configuration_ids = [data.azurerm_lb.aca_hidden_aks_ilb.frontend_ip_configuration[0].id]

  nat_ip_configuration {
    name                       = "natipconfg-to-acaenv-snet"
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.acaenv_subnet.id
    primary                    = true
  }

  # Id format: "/subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.Network/privateLinkServices/afd-aca-pls-aca-env-pl"
}

#--------------------------------------------------------------
#   Azure Front door resources
#--------------------------------------------------------------
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "afd-${var.res_suffix}"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Premium_AzureFrontDoor"

  response_timeout_seconds = 120

  tags = azurerm_resource_group.this.tags

  # Id format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01"
}
resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = "afd-ep-${var.res_suffix}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  tags = azurerm_resource_group.this.tags

  # Id Format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01/afdEndpoints/afd-aca-pls-fd-endpoint"
  # PowerShell status: while ($true) { Invoke-WebRequest https://hello-aca-gwg4dvgxdaeqadhs.b01.azurefd.net/ ; Start-Sleep -Seconds 5 ; Write-Host "Querying" }
}
resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = "afd-og-${var.res_suffix}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 0

  health_probe {
    interval_in_seconds = 30
    path                = "/"
    protocol            = "Https"
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  # Id Format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01/originGroups/default-origin-group"
}
resource "azurerm_cdn_frontdoor_origin" "aca" {
  name                          = "afd-origin-${var.res_suffix}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                       = true

  certificate_name_check_enabled = true

  host_name          = azurerm_container_app.this.ingress[0].fqdn
  origin_host_header = azurerm_container_app.this.ingress[0].fqdn
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000

  private_link {
    location               = azurerm_private_link_service.this.location
    private_link_target_id = azurerm_private_link_service.this.id
    request_message        = "Request from Frontdoor: ${azurerm_cdn_frontdoor_profile.this.name}, origin: afd-pls-aca-origin"
  }

  # Id format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01/originGroups/afd-aca-pls-fd-og/origins/afd-aca-pls-fd-origin"
}
resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = "afd-route-${var.res_suffix}"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.aca.id, ]
  cdn_frontdoor_rule_set_ids    = []
  cdn_frontdoor_origin_path     = "/"
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true

  # Id format: "/subscriptions/<sub number>/resourceGroups/<rg name>/providers/Microsoft.Cdn/profiles/afd-s4-afd-aca-priv-01/afdEndpoints/afd-aca-pls-fd-endpoint/routes/afd-aca-pls-fd-route"
}
#*/


#--------------------------------------------------------------
#   PaaS resources accessed with Private Endpoint
#--------------------------------------------------------------
/*
resource "azurerm_container_app_job" "this" {
  # In PR: https://github.com/hashicorp/terraform-provider-azurerm/pull/23871
  # Requires "hashicorp/azurerm >= 3.103"
  name                         = substr("aca-job-${var.res_suffix}", 0, 32)
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location

  workload_profile_name      = "Consumption"
  replica_timeout_in_seconds = 1800

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name    = "aca-job-s4-afd-aca-priv-01"
      image   = "docker.io/hello-world:latest"
      cpu     = 0.5
      memory  = "1Gi"
      command = ["/bin/bash", "-c", "echo hello; sleep 100000"]
    }
  }
}
#*/
