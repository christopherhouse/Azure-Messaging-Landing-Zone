###############################################################################
# Root module — composes per-service child modules under ./modules.
#
# Each child module owns a single Azure resource (or a tight resource group:
# namespace + private endpoint + diagnostic setting). Conditional behaviour
# (create vs. use-existing, deploy vs. skip) lives here in the composition
# layer via `count` on the module blocks. Resolved IDs flow through
# `locals.tf`.
###############################################################################

module "resource_group" {
  source = "./modules/resource_group"

  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

module "network_security_group" {
  source = "./modules/network_security_group"
  count  = local.create_nsg ? 1 : 0

  name                = var.network_security_group.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags
}

module "virtual_network" {
  source = "./modules/virtual_network"
  count  = local.create_vnet ? 1 : 0

  name                = var.virtual_network.name
  resource_group_name = local.resource_group_name
  location            = var.location
  address_space       = var.virtual_network.address_space
  tags                = local.tags
}

module "private_endpoint_subnet" {
  source = "./modules/private_endpoint_subnet"
  count  = local.create_pe_subnet ? 1 : 0

  name                                = var.private_endpoint_subnet.name
  address_prefixes                    = var.private_endpoint_subnet.address_prefixes
  virtual_network_name                = local.create_vnet ? module.virtual_network[0].name : local.existing_vnet_name
  virtual_network_resource_group_name = local.create_vnet ? local.resource_group_name : local.existing_vnet_resource_group_name
  network_security_group_id           = local.associate_nsg ? local.nsg_id : null
}

module "log_analytics" {
  source = "./modules/log_analytics"
  count  = local.create_log_analytics ? 1 : 0

  name                = var.log_analytics.name
  resource_group_name = local.resource_group_name
  location            = var.location
  sku                 = var.log_analytics.sku
  retention_in_days   = var.log_analytics.retention_in_days
  tags                = local.tags
}

module "private_dns_zone_servicebus" {
  source = "./modules/private_dns_zone_servicebus"
  count  = local.create_servicebus_dns_zone ? 1 : 0

  resource_group_name = local.resource_group_name
  tags                = local.tags
  vnet_link           = local.servicebus_dns_zone_self_vnet_link
}

module "private_dns_zone_vnet_link" {
  source = "./modules/private_dns_zone_vnet_link"
  count  = local.link_to_existing_dns_zone ? 1 : 0

  name                         = local.servicebus_dns_zone_vnet_link_name
  dns_zone_name                = reverse(split("/", var.private_dns_zone_servicebus.existing_resource_id))[0]
  dns_zone_resource_group_name = element(split("/", var.private_dns_zone_servicebus.existing_resource_id), 4)
  virtual_network_id           = local.vnet_id
  tags                         = local.tags
}

module "event_hub" {
  source = "./modules/event_hub"
  count  = local.deploy_event_hub ? 1 : 0

  name                       = var.event_hub.name
  resource_group_name        = local.resource_group_name
  location                   = var.location
  sku                        = var.event_hub.sku
  capacity                   = var.event_hub.capacity
  private_endpoint_subnet_id = local.pe_subnet_id
  private_dns_zone_ids       = local.servicebus_dns_zone_ids
  log_analytics_workspace_id = local.has_log_analytics ? local.log_analytics_id : null
  tags                       = local.tags
}

module "service_bus" {
  source = "./modules/service_bus"
  count  = local.deploy_service_bus ? 1 : 0

  name                       = var.service_bus.name
  resource_group_name        = local.resource_group_name
  location                   = var.location
  capacity                   = var.service_bus.capacity
  private_endpoint_subnet_id = local.pe_subnet_id
  private_dns_zone_ids       = local.servicebus_dns_zone_ids
  log_analytics_workspace_id = local.has_log_analytics ? local.log_analytics_id : null
  tags                       = local.tags
}
