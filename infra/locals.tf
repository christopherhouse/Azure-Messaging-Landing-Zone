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
  create_vnet           = var.virtual_network.create
  create_pe_subnet      = var.private_endpoint_subnet.create
  create_nsg            = var.network_security_group.enabled && var.network_security_group.create
  associate_nsg         = var.network_security_group.enabled
  create_log_analytics  = var.log_analytics.create
  deploy_event_hub      = var.event_hub.deploy
  deploy_service_bus    = var.service_bus.deploy

  # Resolved IDs — populated either from a freshly-created module instance or
  # from the `existing_resource_id` input. Stubbed to null until the AVM
  # module wiring lands; downstream resources should consume these locals.
  vnet_id = (
    local.create_vnet
    ? null # TODO: module.virtual_network[0].resource_id
    : var.virtual_network.existing_resource_id
  )

  pe_subnet_id = (
    local.create_pe_subnet
    ? null # TODO: module.private_endpoint_subnet[0].resource_id
    : var.private_endpoint_subnet.existing_resource_id
  )

  nsg_id = (
    !var.network_security_group.enabled
    ? null
    : local.create_nsg
      ? null # TODO: module.network_security_group[0].resource_id
      : var.network_security_group.existing_resource_id
  )

  log_analytics_id = (
    local.create_log_analytics
    ? null # TODO: module.log_analytics[0].resource_id
    : var.log_analytics.existing_resource_id
  )
}
