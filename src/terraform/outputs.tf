# output "aca-aenv-default-domain" {
#   value = azurerm_container_app_environment.priv_env.default_domain
# }

# output "aca-aenv-infrastructure-rg-name" {
#   value = local.aca_env_infra_rg_name
# }

output "Message" {
  value = "Access the Container App through Frond door: https://${azurerm_cdn_frontdoor_endpoint.this.host_name}"
}
