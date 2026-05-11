###############################################################################
# Resource group (always managed by this root module)
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}
