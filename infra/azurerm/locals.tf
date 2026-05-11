locals {
  # Mandatory baseline tags merged with any caller-supplied tags.
  base_tags = {
    environment = var.environment
    workload    = var.workload_name
    managed-by  = "terraform"
  }

  tags = merge(local.base_tags, var.tags)

  # Convenience flags so the conditional `count = ... ? 1 : 0` expressions in
  # main.tf read clearly.
  create_vnet          = var.virtual_network.create
  create_pe_subnet     = var.private_endpoint_subnet.create
  create_nsg           = var.network_security_group.enabled && var.network_security_group.create
  associate_nsg        = var.network_security_group.enabled
  create_log_analytics = var.log_analytics.create
  deploy_event_hub     = var.event_hub.deploy
  deploy_service_bus   = var.service_bus.deploy

  # Private DNS zone (shared by Event Hub + Service Bus PEs).
  create_servicebus_dns_zone = var.private_dns_zone_servicebus.create
  has_servicebus_dns_zone = (
    var.private_dns_zone_servicebus.create ||
    var.private_dns_zone_servicebus.existing_resource_id != null
  )
  # Link this module's VNet to the zone when:
  #   * we created the zone (always), OR
  #   * caller opted in via link_existing_to_vnet on an existing zone.
  link_servicebus_dns_zone_to_vnet = (
    local.has_servicebus_dns_zone &&
    local.vnet_id != null &&
    (local.create_servicebus_dns_zone || var.private_dns_zone_servicebus.link_existing_to_vnet)
  )

  # Resource group is always managed by this root module.
  resource_group_name = azurerm_resource_group.this.name

  # When attaching a subnet to a pre-existing VNet we need its RG name (not
  # the RG containing this module's resources).
  existing_vnet_resource_group_name = (
    !local.create_vnet && var.virtual_network.existing_resource_id != null
    ? data.azurerm_virtual_network.existing[0].resource_group_name
    : null
  )

  # Resolved IDs / names — populated either from a freshly-created resource or
  # from the `existing_resource_id` input.
  vnet_id = (
    local.create_vnet
    ? azurerm_virtual_network.this[0].id
    : var.virtual_network.existing_resource_id
  )

  pe_subnet_id = (
    local.create_pe_subnet
    ? azurerm_subnet.private_endpoint[0].id
    : var.private_endpoint_subnet.existing_resource_id
  )

  nsg_id = (
    !var.network_security_group.enabled
    ? null
    : local.create_nsg
    ? azurerm_network_security_group.this[0].id
    : var.network_security_group.existing_resource_id
  )

  log_analytics_id = (
    local.create_log_analytics
    ? azurerm_log_analytics_workspace.this[0].id
    : var.log_analytics.existing_resource_id
  )

  servicebus_dns_zone_id = (
    local.create_servicebus_dns_zone
    ? azurerm_private_dns_zone.servicebus[0].id
    : var.private_dns_zone_servicebus.existing_resource_id
  )

  # Resource IDs handed to private endpoint DNS zone groups. Empty list when
  # no zone is wired up, so the PE has no zone group attached.
  servicebus_dns_zone_ids = local.has_servicebus_dns_zone ? [local.servicebus_dns_zone_id] : []

  # Gate that must be known at plan time for diagnostic setting conditionals.
  has_log_analytics = local.create_log_analytics || var.log_analytics.existing_resource_id != null

  # Resolved name for the spoke VNet link on the private DNS zone.
  servicebus_dns_zone_vnet_link_name = coalesce(
    var.private_dns_zone_servicebus.vnet_link_name,
    "${var.workload_name}-${var.environment}-link"
  )
}
