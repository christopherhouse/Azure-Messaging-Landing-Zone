resource "azurerm_network_security_group" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # No baseline rules opened up by default — Azure's implicit rules apply.
}
