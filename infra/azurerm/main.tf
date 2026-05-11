###############################################################################
# Resource group (always managed by this root module)
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

###############################################################################
# Networking — Network Security Group (created first so the new VNet's subnet
# can reference it, and so an existing-subnet → NSG association is possible).
###############################################################################

resource "azurerm_network_security_group" "this" {
  count = local.create_nsg ? 1 : 0

  name                = var.network_security_group.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  # No baseline rules opened up by default — Azure's implicit rules apply.
}

###############################################################################
# Networking — Virtual Network (conditional: new vs. existing)
###############################################################################

resource "azurerm_virtual_network" "this" {
  count = local.create_vnet ? 1 : 0

  name                = var.virtual_network.name
  resource_group_name = local.resource_group_name
  location            = var.location
  address_space       = var.virtual_network.address_space
  tags                = local.tags
}

###############################################################################
# Networking — Private Endpoint subnet.
#
# Created either inside the new VNet (this module owns the VNet) or attached
# to a pre-existing VNet via its resource group.
###############################################################################

resource "azurerm_subnet" "private_endpoint" {
  count = local.create_pe_subnet ? 1 : 0

  name                 = var.private_endpoint_subnet.name
  address_prefixes     = var.private_endpoint_subnet.address_prefixes
  resource_group_name  = local.create_vnet ? local.resource_group_name : local.existing_vnet_resource_group_name
  virtual_network_name = local.create_vnet ? azurerm_virtual_network.this[0].name : data.azurerm_virtual_network.existing[0].name

  # Keep PE network policies enabled (Azure default since 2021) so NSGs apply
  # to private endpoint NICs.
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint" {
  count = (local.create_pe_subnet && local.associate_nsg) ? 1 : 0

  subnet_id                 = azurerm_subnet.private_endpoint[0].id
  network_security_group_id = local.nsg_id
}

###############################################################################
# Observability — Log Analytics Workspace (conditional: new vs. existing)
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  count = local.create_log_analytics ? 1 : 0

  name                = var.log_analytics.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  sku               = var.log_analytics.sku
  retention_in_days = var.log_analytics.retention_in_days
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

resource "azurerm_private_dns_zone" "servicebus" {
  count = local.create_servicebus_dns_zone ? 1 : 0

  name                = "privatelink.servicebus.windows.net"
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

# VNet link on a freshly-created zone in this module's RG.
resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  count = (local.create_servicebus_dns_zone && local.link_servicebus_dns_zone_to_vnet) ? 1 : 0

  name                  = local.servicebus_dns_zone_vnet_link_name
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus[0].name
  virtual_network_id    = local.vnet_id
  registration_enabled  = false
  tags                  = local.tags
}

# VNet link on a pre-existing zone in another RG (e.g. hub DNS RG). Only used
# when the caller opted in to letting this module manage the spoke link.
resource "azurerm_private_dns_zone_virtual_network_link" "servicebus_existing" {
  count = (
    !local.create_servicebus_dns_zone &&
    local.has_servicebus_dns_zone &&
    local.link_servicebus_dns_zone_to_vnet
  ) ? 1 : 0

  name                  = local.servicebus_dns_zone_vnet_link_name
  resource_group_name   = element(split("/", var.private_dns_zone_servicebus.existing_resource_id), 4)
  private_dns_zone_name = reverse(split("/", var.private_dns_zone_servicebus.existing_resource_id))[0]
  virtual_network_id    = local.vnet_id
  registration_enabled  = false
  tags                  = local.tags
}

###############################################################################
# Event Hub Namespace (conditional)
#   - Standard or Premium SKU
#   - Public network access disabled
#   - Local (SAS) authentication disabled
#   - Private endpoint on local.pe_subnet_id (subresource = namespace)
###############################################################################

resource "azurerm_eventhub_namespace" "this" {
  count = local.deploy_event_hub ? 1 : 0

  name                = var.event_hub.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  sku                           = var.event_hub.sku
  capacity                      = var.event_hub.capacity
  public_network_access_enabled = false
  local_authentication_enabled  = false
}

resource "azurerm_private_endpoint" "event_hub" {
  count = local.deploy_event_hub ? 1 : 0

  name                = "pep-${var.event_hub.name}"
  resource_group_name = local.resource_group_name
  location            = var.location
  subnet_id           = local.pe_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${var.event_hub.name}"
    private_connection_resource_id = azurerm_eventhub_namespace.this[0].id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  dynamic "private_dns_zone_group" {
    for_each = local.has_servicebus_dns_zone ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = local.servicebus_dns_zone_ids
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "event_hub_namespace" {
  count = (local.deploy_event_hub && local.has_log_analytics) ? 1 : 0

  name                           = "to-law"
  target_resource_id             = azurerm_eventhub_namespace.this[0].id
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
#   - Local (SAS) authentication disabled
#   - Private endpoint on local.pe_subnet_id
###############################################################################

resource "azurerm_servicebus_namespace" "this" {
  count = local.deploy_service_bus ? 1 : 0

  name                = var.service_bus.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  sku                           = "Premium"
  capacity                      = var.service_bus.capacity
  public_network_access_enabled = false
  local_auth_enabled            = false
}

resource "azurerm_private_endpoint" "service_bus" {
  count = local.deploy_service_bus ? 1 : 0

  name                = "pep-${var.service_bus.name}"
  resource_group_name = local.resource_group_name
  location            = var.location
  subnet_id           = local.pe_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${var.service_bus.name}"
    private_connection_resource_id = azurerm_servicebus_namespace.this[0].id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  dynamic "private_dns_zone_group" {
    for_each = local.has_servicebus_dns_zone ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = local.servicebus_dns_zone_ids
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "service_bus_namespace" {
  count = (local.deploy_service_bus && local.has_log_analytics) ? 1 : 0

  name                           = "to-law"
  target_resource_id             = azurerm_servicebus_namespace.this[0].id
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
