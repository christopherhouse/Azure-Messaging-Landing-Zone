###############################################################################
# Resource group (always managed by this root module)
###############################################################################

# TODO: replace with Azure/avm-res-resources-resourcegroup/azurerm
# module "resource_group" {
#   source  = "Azure/avm-res-resources-resourcegroup/azurerm"
#   version = "~> 0.2"
#
#   name     = var.resource_group_name
#   location = var.location
#   tags     = local.tags
# }

###############################################################################
# Networking — Virtual Network (conditional: new vs. existing)
###############################################################################

# TODO: replace with Azure/avm-res-network-virtualnetwork/azurerm
# module "virtual_network" {
#   source  = "Azure/avm-res-network-virtualnetwork/azurerm"
#   version = "~> 0.4"
#   count   = local.create_vnet ? 1 : 0
#
#   name                = var.virtual_network.name
#   resource_group_name = module.resource_group.name
#   location            = var.location
#   address_space       = var.virtual_network.address_space
#   tags                = local.tags
# }

###############################################################################
# Networking — Private Endpoint subnet (conditional: new vs. existing)
###############################################################################

# Subnets are typically created via the virtual_network AVM module's `subnets`
# argument or as a standalone azurerm_subnet resource when reusing an existing
# VNet. This will be wired up alongside the VNet module.
#
# TODO: subnet creation block, gated on local.create_pe_subnet.

###############################################################################
# Networking — NSG (conditional, optional)
###############################################################################

# TODO: replace with Azure/avm-res-network-networksecuritygroup/azurerm
# module "network_security_group" {
#   source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
#   version = "~> 0.2"
#   count   = local.create_nsg ? 1 : 0
#
#   name                = var.network_security_group.name
#   resource_group_name = module.resource_group.name
#   location            = var.location
#   tags                = local.tags
# }

# TODO: subnet ↔ NSG association when local.associate_nsg is true.

###############################################################################
# Observability — Log Analytics Workspace (conditional: new vs. existing)
###############################################################################

# TODO: replace with Azure/avm-res-operationalinsights-workspace/azurerm
# module "log_analytics" {
#   source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
#   version = "~> 0.4"
#   count   = local.create_log_analytics ? 1 : 0
#
#   name                       = var.log_analytics.name
#   resource_group_name        = module.resource_group.name
#   location                   = var.location
#   log_analytics_workspace_sku = var.log_analytics.sku
#   log_analytics_workspace_retention_in_days = var.log_analytics.retention_in_days
#   tags                       = local.tags
# }

###############################################################################
# Event Hub Namespace (conditional)
#   - Standard or Premium SKU
#   - Public network access disabled
#   - Private endpoint on local.pe_subnet_id
###############################################################################

# TODO: replace with Azure/avm-res-eventhub-namespace/azurerm
# module "event_hub_namespace" {
#   source  = "Azure/avm-res-eventhub-namespace/azurerm"
#   version = "~> 0.2"
#   count   = local.deploy_event_hub ? 1 : 0
#
#   name                          = var.event_hub.name
#   resource_group_name           = module.resource_group.name
#   location                      = var.location
#   sku                           = var.event_hub.sku
#   capacity                      = var.event_hub.capacity
#   public_network_access_enabled = false
#
#   private_endpoints = {
#     primary = {
#       subnet_resource_id = local.pe_subnet_id
#       subresource_name   = "namespace"
#     }
#   }
#
#   diagnostic_settings = local.log_analytics_id == null ? {} : {
#     to_law = {
#       workspace_resource_id = local.log_analytics_id
#     }
#   }
#
#   tags = local.tags
# }

###############################################################################
# Service Bus Namespace (conditional)
#   - Premium SKU only
#   - Public network access disabled
#   - Private endpoint on local.pe_subnet_id
###############################################################################

# TODO: replace with Azure/avm-res-servicebus-namespace/azurerm
# module "service_bus_namespace" {
#   source  = "Azure/avm-res-servicebus-namespace/azurerm"
#   version = "~> 0.3"
#   count   = local.deploy_service_bus ? 1 : 0
#
#   name                          = var.service_bus.name
#   resource_group_name           = module.resource_group.name
#   location                      = var.location
#   sku                           = "Premium"
#   capacity                      = var.service_bus.capacity
#   public_network_access_enabled = false
#
#   private_endpoints = {
#     primary = {
#       subnet_resource_id = local.pe_subnet_id
#       subresource_name   = "namespace"
#     }
#   }
#
#   diagnostic_settings = local.log_analytics_id == null ? {} : {
#     to_law = {
#       workspace_resource_id = local.log_analytics_id
#     }
#   }
#
#   tags = local.tags
# }
