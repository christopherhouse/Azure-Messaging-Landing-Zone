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
