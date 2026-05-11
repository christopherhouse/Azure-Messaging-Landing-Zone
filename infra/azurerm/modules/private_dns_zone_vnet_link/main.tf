###############################################################################
# Creates only a virtual network link against a pre-existing Private DNS Zone.
#
# Used when a centrally-managed zone (e.g. in the hub) needs a link from this
# module's VNet.
###############################################################################

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = var.name
  resource_group_name   = var.dns_zone_resource_group_name
  private_dns_zone_name = var.dns_zone_name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}
