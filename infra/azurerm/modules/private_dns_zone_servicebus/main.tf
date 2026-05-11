###############################################################################
# Private DNS Zone — privatelink.servicebus.windows.net
#
# Shared by Event Hub and Service Bus private endpoints (both services resolve
# through the same `privatelink.servicebus.windows.net` zone). Optionally also
# manages a VNet link from the supplied virtual network.
###############################################################################

resource "azurerm_private_dns_zone" "this" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count = var.vnet_link != null ? 1 : 0

  name                  = var.vnet_link.name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.vnet_link.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}
