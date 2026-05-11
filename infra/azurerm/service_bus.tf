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
