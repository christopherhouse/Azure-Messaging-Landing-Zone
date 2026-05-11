resource "azurerm_subnet" "this" {
  name                 = var.name
  address_prefixes     = var.address_prefixes
  resource_group_name  = var.virtual_network_resource_group_name
  virtual_network_name = var.virtual_network_name

  # Keep PE network policies enabled (Azure default since 2021) so NSGs apply
  # to private endpoint NICs.
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet_network_security_group_association" "this" {
  count = var.network_security_group_id != null ? 1 : 0

  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = var.network_security_group_id
}
