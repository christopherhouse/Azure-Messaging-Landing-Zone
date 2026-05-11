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
