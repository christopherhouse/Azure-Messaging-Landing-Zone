locals {
  # Mandatory baseline tags merged with any caller-supplied tags.
  base_tags = {
    environment = var.environment
    workload    = var.workload_name
    managed-by  = "terraform"
  }

  tags = merge(local.base_tags, var.tags)

  # Convenience flags driving the module `count` arguments in main.tf.
  create_vnet          = var.virtual_network.create
  create_pe_subnet     = var.private_endpoint_subnet.create
  create_nsg           = var.network_security_group.enabled && var.network_security_group.create
  associate_nsg        = var.network_security_group.enabled
  create_log_analytics = var.log_analytics.create
  deploy_event_hub     = var.event_hub.deploy
  deploy_service_bus   = var.service_bus.deploy

  create_servicebus_dns_zone = var.private_dns_zone_servicebus.create
  has_servicebus_dns_zone = (
    var.private_dns_zone_servicebus.create ||
    var.private_dns_zone_servicebus.existing_resource_id != null
  )

  # Resource group is always managed by this root module.
  resource_group_name = module.resource_group.name

  # When attaching a subnet to a pre-existing VNet we need its name and RG.
  existing_vnet_resource_group_name = (
    !local.create_vnet && var.virtual_network.existing_resource_id != null
    ? data.azurerm_virtual_network.existing[0].resource_group_name
    : null
  )

  existing_vnet_name = (
    !local.create_vnet && var.virtual_network.existing_resource_id != null
    ? data.azurerm_virtual_network.existing[0].name
    : null
  )

  # Resolved IDs / names — populated either from a child module output or from
  # the matching `existing_resource_id` input.
  vnet_id = (
    local.create_vnet
    ? module.virtual_network[0].id
    : var.virtual_network.existing_resource_id
  )

  pe_subnet_id = (
    local.create_pe_subnet
    ? module.private_endpoint_subnet[0].id
    : var.private_endpoint_subnet.existing_resource_id
  )

  nsg_id = (
    !var.network_security_group.enabled
    ? null
    : local.create_nsg
    ? module.network_security_group[0].id
    : var.network_security_group.existing_resource_id
  )

  log_analytics_id = (
    local.create_log_analytics
    ? module.log_analytics[0].id
    : var.log_analytics.existing_resource_id
  )

  servicebus_dns_zone_id = (
    local.create_servicebus_dns_zone
    ? module.private_dns_zone_servicebus[0].id
    : var.private_dns_zone_servicebus.existing_resource_id
  )

  # Resource IDs handed to private endpoint DNS zone groups. Empty list when
  # no zone is wired up so the PE has no zone group attached.
  servicebus_dns_zone_ids = local.has_servicebus_dns_zone ? [local.servicebus_dns_zone_id] : []

  # Plan-time gate for diagnostic settings inside the namespace modules.
  has_log_analytics = local.create_log_analytics || var.log_analytics.existing_resource_id != null

  # Resolved name for the spoke VNet link on the Private DNS Zone.
  servicebus_dns_zone_vnet_link_name = coalesce(
    var.private_dns_zone_servicebus.vnet_link_name,
    "${var.workload_name}-${var.environment}-link"
  )

  # When the zone is freshly created in this module, also link this module's
  # VNet via the same dns-zone module (passed through its `vnet_link`).
  servicebus_dns_zone_self_vnet_link = (
    local.create_servicebus_dns_zone && local.vnet_id != null
    ? {
      name               = local.servicebus_dns_zone_vnet_link_name
      virtual_network_id = local.vnet_id
    }
    : null
  )

  # When the zone is pre-existing AND the caller asked us to manage the link
  # from this module's VNet, the dedicated vnet-link module is invoked.
  link_to_existing_dns_zone = (
    !local.create_servicebus_dns_zone &&
    local.has_servicebus_dns_zone &&
    var.private_dns_zone_servicebus.link_existing_to_vnet &&
    local.vnet_id != null
  )
}
