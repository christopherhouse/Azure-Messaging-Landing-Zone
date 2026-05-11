###############################################################################
# Lookups for "use existing" inputs.
#
# The AVM modules consume `resource_group_name` / `location` rather than a
# resource ID for most resources, so we parse the supplied existing IDs to
# pull out the bits we need downstream (e.g. the VNet's RG when we add a new
# subnet to a pre-existing VNet, or the existing Log Analytics workspace
# resource ID for diagnostics).
###############################################################################

# Existing virtual network — only looked up when create=false and an ID was
# supplied. We need the parent_id (== existing VNet resource ID) when
# attaching a new subnet via the subnet submodule.
data "azurerm_virtual_network" "existing" {
  count = (!var.virtual_network.create && var.virtual_network.existing_resource_id != null) ? 1 : 0

  name                = reverse(split("/", var.virtual_network.existing_resource_id))[0]
  resource_group_name = element(split("/", var.virtual_network.existing_resource_id), 4)
}
