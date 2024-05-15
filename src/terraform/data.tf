# Get the hidden AKS Internal Load Balancer used by ACA
data "azurerm_lb" "aca_hidden_aks_ilb" {
  name                = "kubernetes-internal"
  resource_group_name = local.aca_env_infra_rg_name
}

#--------------------------------------------------------------
#   Data collection of Hub Landing Zone resources (ST, LAW, KV)
#--------------------------------------------------------------
#   ===========   From Management subscription   ===========
#   / s1-hub-logsdiag | Log Analytics Workspace Main region
data "azurerm_log_analytics_workspace" "main_region_logdiag_law" {
  provider = azurerm.s1-management

  name                = split("/", var.main_region_hub_law_id)[8]
  resource_group_name = split("/", var.main_region_hub_law_id)[4]
}
