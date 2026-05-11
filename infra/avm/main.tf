###############################################################################
# Resource group (always managed by this root module)
###############################################################################

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.4"

  name     = var.resource_group_name
  location = var.location
  tags     = local.tags

  enable_telemetry = false
}

###############################################################################
# Networking — Network Security Group (created first so the new VNet's subnet
# can reference it, and so an existing-subnet → NSG association is possible).
###############################################################################

module "network_security_group" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "~> 0.5"
  count   = local.create_nsg ? 1 : 0

  name                = var.network_security_group.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  # No baseline rules opened up by default — Azure's implicit rules apply.
  security_rules = {}

  enable_telemetry = false
}

###############################################################################
# Networking — Virtual Network (conditional: new vs. existing).
#
# When the PE subnet is also being created, it is defined inline in the
# `subnets` map so the VNet module manages it (and applies any NSG association).
###############################################################################

module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.17"
  count   = local.create_vnet ? 1 : 0

  name          = var.virtual_network.name
  parent_id     = module.resource_group.resource_id
  location      = var.location
  address_space = var.virtual_network.address_space
  tags          = local.tags

  subnets = local.create_pe_subnet ? {
    (local.pe_subnet_key) = {
      name             = var.private_endpoint_subnet.name
      address_prefixes = var.private_endpoint_subnet.address_prefixes

      # Keep PE network policies enabled (Azure default since 2021) so NSGs
      # apply to private endpoint NICs.
      private_endpoint_network_policies = "Enabled"

      network_security_group = local.associate_nsg ? {
        id = local.nsg_id
      } : null
    }
  } : {}

  enable_telemetry = false
}

###############################################################################
# Networking — Private Endpoint subnet on a pre-existing VNet.
#
# Only used when the VNet already exists but a new subnet must still be
# created. Uses the AVM virtual network module's `subnet` submodule.
###############################################################################

module "private_endpoint_subnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm//modules/subnet"
  version = "~> 0.17"
  count   = (local.create_pe_subnet && !local.create_vnet) ? 1 : 0

  name             = var.private_endpoint_subnet.name
  parent_id        = data.azurerm_virtual_network.existing[0].id
  address_prefixes = var.private_endpoint_subnet.address_prefixes

  private_endpoint_network_policies = "Enabled"

  network_security_group = local.associate_nsg ? {
    id = local.nsg_id
  } : null
}

###############################################################################
# Observability — Log Analytics Workspace (conditional: new vs. existing)
###############################################################################

module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.5"
  count   = local.create_log_analytics ? 1 : 0

  name                = var.log_analytics.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  log_analytics_workspace_sku               = var.log_analytics.sku
  log_analytics_workspace_retention_in_days = var.log_analytics.retention_in_days

  enable_telemetry = false
}

###############################################################################
# Private DNS Zone — privatelink.servicebus.windows.net
#
# Shared by Event Hub and Service Bus private endpoints (both services use the
# same `privatelink.servicebus.windows.net` zone). When `create = true`, the
# zone is also linked to this module's VNet so PE A-records resolve correctly
# from inside the spoke. When pointing at an existing (e.g. hub-managed) zone,
# the link is opt-in via `link_existing_to_vnet`.
###############################################################################

module "private_dns_zone_servicebus" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "~> 0.5"
  count   = local.create_servicebus_dns_zone ? 1 : 0

  domain_name = "privatelink.servicebus.windows.net"
  parent_id   = module.resource_group.resource_id
  tags        = local.tags

  virtual_network_links = local.link_servicebus_dns_zone_to_vnet ? {
    spoke = {
      name                 = coalesce(var.private_dns_zone_servicebus.vnet_link_name, "${var.workload_name}-${var.environment}-link")
      virtual_network_id   = local.vnet_id
      registration_enabled = false
    }
  } : {}

  enable_telemetry = false
}

###############################################################################
# Virtual network link to a pre-existing (e.g. hub) Private DNS Zone.
#
# Only used when the caller supplied an existing zone resource ID *and* opted
# in to having this module manage the spoke link. The AVM zone module owns the
# vnet-link submodule, so we call it directly against the existing zone.
###############################################################################

module "private_dns_zone_servicebus_existing_link" {
  source  = "Azure/avm-res-network-privatednszone/azurerm//modules/private_dns_virtual_network_link"
  version = "~> 0.5"
  count = (
    !local.create_servicebus_dns_zone &&
    local.has_servicebus_dns_zone &&
    local.link_servicebus_dns_zone_to_vnet
  ) ? 1 : 0

  name                 = coalesce(var.private_dns_zone_servicebus.vnet_link_name, "${var.workload_name}-${var.environment}-link")
  parent_id            = var.private_dns_zone_servicebus.existing_resource_id
  virtual_network_id   = local.vnet_id
  registration_enabled = false
  tags                 = local.tags
}

###############################################################################
# Event Hub Namespace (conditional)
#   - Standard or Premium SKU
#   - Public network access disabled
#   - Private endpoint on local.pe_subnet_id (subresource = namespace)
###############################################################################

module "event_hub_namespace" {
  source  = "Azure/avm-res-eventhub-namespace/azurerm"
  version = "~> 0.1"
  count   = local.deploy_event_hub ? 1 : 0

  name                = var.event_hub.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  sku                           = var.event_hub.sku
  capacity                      = var.event_hub.capacity
  public_network_access_enabled = false
  local_authentication_enabled  = false

  private_endpoints = {
    primary = {
      subnet_resource_id            = local.pe_subnet_id
      subresource_name              = "namespace"
      private_dns_zone_resource_ids = local.servicebus_dns_zone_ids
    }
  }

  # NOTE: `diagnostic_settings` is intentionally NOT passed here.
  # The avm-res-eventhub-namespace v0.1.0 module declares the input but does
  # not actually create an `azurerm_monitor_diagnostic_setting` resource from
  # it (no diag-settings file in the module). We manage it directly below
  # via `azurerm_monitor_diagnostic_setting.event_hub_namespace` until a
  # newer module version wires it up.

  enable_telemetry = false
}

###############################################################################
# Event Hub Namespace — diagnostic settings (workaround)
#
# Manually authored because avm-res-eventhub-namespace v0.1.0 ignores its own
# `diagnostic_settings` input. Mirrors what the Service Bus AVM module emits:
# all log categories + AllMetrics, dedicated destination type.
###############################################################################

resource "azurerm_monitor_diagnostic_setting" "event_hub_namespace" {
  count = (local.deploy_event_hub && local.has_log_analytics) ? 1 : 0

  name                           = "to-law"
  target_resource_id             = module.event_hub_namespace[0].resource_id
  log_analytics_workspace_id     = local.log_analytics_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

###############################################################################
# Service Bus Namespace (conditional)
#   - Premium SKU only
#   - Public network access disabled
#   - Private endpoint on local.pe_subnet_id
###############################################################################

module "service_bus_namespace" {
  source  = "Azure/avm-res-servicebus-namespace/azurerm"
  version = "~> 0.4"
  count   = local.deploy_service_bus ? 1 : 0

  name                = var.service_bus.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  sku                           = "Premium"
  capacity                      = var.service_bus.capacity
  public_network_access_enabled = false
  local_auth_enabled            = false

  # Premium namespaces require infrastructure encryption to be paired with a
  # customer-managed key; disable since we are not wiring CMK in this module.
  infrastructure_encryption_enabled = false

  private_endpoints = {
    primary = {
      subnet_resource_id            = local.pe_subnet_id
      private_dns_zone_resource_ids = local.servicebus_dns_zone_ids
    }
  }

  diagnostic_settings = local.diagnostic_settings

  enable_telemetry = false
}
