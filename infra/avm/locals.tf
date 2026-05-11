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

  # Internal subnet key used inside the VNet module's subnets map when both
  # the VNet and the PE subnet are created together.
  pe_subnet_key = "pe"

  # Resource group is always managed by this root module.
  resource_group_name = module.resource_group.name

  # Resolved IDs — populated either from a freshly-created module instance or
  # from the `existing_resource_id` input.
  vnet_id = (
    local.create_vnet
    ? module.virtual_network[0].resource_id
    : var.virtual_network.existing_resource_id
  )

  # Subnet resolution matrix:
  #   create_vnet=true,  create_pe_subnet=true  -> subnet defined in vnet module
  #   create_vnet=false, create_pe_subnet=true  -> subnet submodule against existing vnet
  #   create_vnet=*,     create_pe_subnet=false -> existing_resource_id (or null)
  pe_subnet_id = (
    local.create_pe_subnet
    ? (
      local.create_vnet
      ? module.virtual_network[0].subnets[local.pe_subnet_key].resource_id
      : module.private_endpoint_subnet[0].resource_id
    )
    : var.private_endpoint_subnet.existing_resource_id
  )

  nsg_id = (
    !var.network_security_group.enabled
    ? null
    : local.create_nsg
    ? module.network_security_group[0].resource_id
    : var.network_security_group.existing_resource_id
  )

  log_analytics_id = (
    local.create_log_analytics
    ? module.log_analytics[0].resource_id
    : var.log_analytics.existing_resource_id
  )

  servicebus_dns_zone_id = (
    local.create_servicebus_dns_zone
    ? module.private_dns_zone_servicebus[0].resource_id
    : var.private_dns_zone_servicebus.existing_resource_id
  )

  # Resource IDs handed to AVM modules' `private_dns_zone_resource_ids`.
  # Empty list when no zone is wired up, so the PE has no zone group attached.
  servicebus_dns_zone_ids = local.has_servicebus_dns_zone ? [local.servicebus_dns_zone_id] : []

  # Diagnostic settings map shared by Event Hub and Service Bus modules.
  # Empty when no Log Analytics workspace was supplied or created.
  #
  # IMPORTANT: the gate must be known at plan time, otherwise downstream
  # `for_each = var.diagnostic_settings` inside the AVM modules fails with
  # "Invalid for_each argument" because the map's keys would depend on a
  # value known only after apply (the workspace resource_id).
  has_log_analytics = local.create_log_analytics || var.log_analytics.existing_resource_id != null
  diagnostic_settings = local.has_log_analytics ? {
    to_law = {
      name                  = "to-law"
      workspace_resource_id = local.log_analytics_id
    }
  } : {}
}
