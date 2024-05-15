locals {
  aca_suffix            = split(".", azurerm_container_app_environment.this.default_domain)[0]
  aca_region            = split(".", azurerm_container_app_environment.this.default_domain)[1]
  aca_env_infra_rg_name = "MC_${local.aca_suffix}-rg_${local.aca_suffix}_${local.aca_region}"

  # Base resources Tags
  UTC_to_TZ      = "-5h" # Careful to factor DST
  TZ_suffix      = "EST"
  created_TZtime = timeadd(local.created_now, local.UTC_to_TZ)
  created_now    = time_static.this.rfc3339
  created_nowTZ  = "${formatdate("YYYY-MM-DD hh:mm", local.created_TZtime)} ${local.TZ_suffix}" # 2020-06-16 14:44 EST

  base_tags = tomap({
    "Created_with"     = "Terraform v1.8.2 on windows_amd64",
    "Created_on"       = "${local.created_nowTZ}",
    "Initiated_by"     = "Manually",
    "GiHub_repo"       = "https://github.com/embergershared/aks-pls",
    "Subscription"     = "s4",
    "Terraform_state"  = "tfstates-s4-spokes/aks-pls-aca",
    "Terraform_plan"   = "embergershared/aks-pls-aca/src/terraform/main.tf",
    "Terraform_values" = "embergershared/aks-pls-aca/src/terraform/secret.auto.tfvars",
  })
}
