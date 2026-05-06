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

  # Diagnostic settings map shared by Event Hub and Service Bus modules.
  # Empty when no Log Analytics workspace was supplied or created.
  diagnostic_settings = local.log_analytics_id == null ? {} : {
    to_law = {
      name                  = "to-law"
      workspace_resource_id = local.log_analytics_id
    }
  }
}
