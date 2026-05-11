###############################################################################
# Lookups for "use existing" inputs.
#
# When the caller points at a pre-existing virtual network we need to know its
# resource group name so a new subnet can be attached to it. The existing
# resource ID is parsed below; the data source confirms the network exists at
# plan time.
###############################################################################

data "azurerm_virtual_network" "existing" {
  count = (!var.virtual_network.create && var.virtual_network.existing_resource_id != null) ? 1 : 0

  name                = reverse(split("/", var.virtual_network.existing_resource_id))[0]
  resource_group_name = element(split("/", var.virtual_network.existing_resource_id), 4)
}
