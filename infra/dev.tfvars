###############################################################################
# Dev environment tfvars — consumed by .github/workflows/terraform-dev.yml
# (passed via `terraform plan -var-file="dev.tfvars"`).
#
# Do NOT put secrets here. This file is committed to the repo. Store secrets
# in Key Vault and reference them from Terraform.
###############################################################################

location            = "eastus2"
workload_name       = "messaging"
environment         = "dev"
resource_group_name = "rg-messaging-dev"

tags = {
  cost-center = "TBD"
  owner       = "platform-team"
}

# ---- Networking: create a fresh VNet + PE subnet ----------------------------
virtual_network = {
  create        = true
  name          = "vnet-messaging-dev"
  address_space = ["10.50.0.0/16"]
}

private_endpoint_subnet = {
  create           = true
  name             = "snet-pe-messaging-dev"
  address_prefixes = ["10.50.1.0/24"]
}

# ---- Optional NSG on the PE subnet ------------------------------------------
network_security_group = {
  enabled = true
  create  = true
  name    = "nsg-pe-messaging-dev"
}

# ---- Log Analytics ----------------------------------------------------------
log_analytics = {
  create            = true
  name              = "log-messaging-dev"
  retention_in_days = 30
}

# ---- Messaging workloads ----------------------------------------------------
event_hub = {
  deploy   = true
  name     = "evhns-messaging-dev"
  sku      = "Standard"
  capacity = 1
}

service_bus = {
  deploy   = true
  name     = "sb-messaging-dev"
  capacity = 1
}
