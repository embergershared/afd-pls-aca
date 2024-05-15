provider "azurerm" {
  tenant_id       = var.tenant_id
  subscription_id = var.subsc_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  skip_provider_registration = false
  storage_use_azuread        = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azurerm" {
  alias = "s1-management"

  tenant_id       = var.tenant_id
  subscription_id = var.mgmt_subsc_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  skip_provider_registration = false

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}


# provider "azurerm" {
#   alias = "s2-connectivity"

#   tenant_id       = var.tenant_id
#   subscription_id = var.conn_subsc_id
#   client_id       = var.conn_client_id
#   client_secret   = var.conn_client_secret

#   skip_provider_registration = false

#   features {
#     resource_group {
#       prevent_deletion_if_contains_resources = false
#     }
#   }
# }
#*/
