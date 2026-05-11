###############################################################################
# Observability — Log Analytics Workspace (conditional: new vs. existing)
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  count = local.create_log_analytics ? 1 : 0

  name                = var.log_analytics.name
  resource_group_name = local.resource_group_name
  location            = var.location
  tags                = local.tags

  sku               = var.log_analytics.sku
  retention_in_days = var.log_analytics.retention_in_days
}
