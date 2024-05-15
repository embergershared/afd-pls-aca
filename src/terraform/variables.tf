###########   Hub Landing Zone access   ###########
variable "tenant_id" {}

# Subscription with Management resource(s) (Jumpboxes, Key vault, LAW) (S1)
variable "mgmt_subsc_id" {}
variable "main_region_hub_law_id" {}


###########   Workload settings   ###########

# Subscription to deploy to
variable "subsc_id" {}
variable "client_id" {}
variable "client_secret" {}

# Base settings
variable "res_suffix" {}
variable "loc_sub" {}
variable "location" {}

variable "vnet_address_space" {}

