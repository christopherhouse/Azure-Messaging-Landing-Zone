###############################################################################
# Core / global
###############################################################################

variable "location" {
  description = "Azure region into which net-new resources will be deployed."
  type        = string
}

variable "workload_name" {
  description = "Short workload identifier used in resource names (e.g. `messaging`)."
  type        = string
}

variable "environment" {
  description = "Environment short name (e.g. `dev`, `staging`, `prod`)."
  type        = string
  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, staging, prod."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group that will hold net-new resources. Created if it does not exist."
  type        = string
}

variable "tags" {
  description = "Additional tags to merge with the mandatory baseline tags."
  type        = map(string)
  default     = {}
}

###############################################################################
# Virtual Network
#
# Set `create = true` to provision a new VNet, or `create = false` and supply
# `existing_resource_id` to reuse one that already exists.
###############################################################################

variable "virtual_network" {
  description = "Virtual network configuration. Either create a new VNet or reference an existing one by resource ID."
  type = object({
    create               = bool
    existing_resource_id = optional(string)
    name                 = optional(string)
    address_space        = optional(list(string))
  })
  default = {
    create = false
  }

  validation {
    condition = (
      (var.virtual_network.create && var.virtual_network.address_space != null) ||
      (!var.virtual_network.create && var.virtual_network.existing_resource_id != null) ||
      (!var.virtual_network.create && var.virtual_network.existing_resource_id == null)
    )
    error_message = "When virtual_network.create = true, address_space must be provided. When create = false and a VNet is required, existing_resource_id must be provided."
  }
}

###############################################################################
# Private endpoint subnet
###############################################################################

variable "private_endpoint_subnet" {
  description = "Subnet used for private endpoints. Either create a new subnet in the (new or existing) VNet, or reference an existing subnet by resource ID."
  type = object({
    create               = bool
    existing_resource_id = optional(string)
    name                 = optional(string)
    address_prefixes     = optional(list(string))
  })
  default = {
    create = false
  }

  validation {
    condition = (
      (var.private_endpoint_subnet.create && var.private_endpoint_subnet.address_prefixes != null) ||
      (!var.private_endpoint_subnet.create && var.private_endpoint_subnet.existing_resource_id != null) ||
      (!var.private_endpoint_subnet.create && var.private_endpoint_subnet.existing_resource_id == null)
    )
    error_message = "When private_endpoint_subnet.create = true, address_prefixes must be provided. When create = false and a subnet is required, existing_resource_id must be provided."
  }
}

###############################################################################
# Network Security Group (optional, attached to the PE subnet)
###############################################################################

variable "network_security_group" {
  description = "Optional NSG associated with the private endpoint subnet. Set `enabled = false` to skip NSG association entirely."
  type = object({
    enabled              = bool
    create               = bool
    existing_resource_id = optional(string)
    name                 = optional(string)
  })
  default = {
    enabled = false
    create  = false
  }

  validation {
    condition = (
      !var.network_security_group.enabled ||
      var.network_security_group.create ||
      var.network_security_group.existing_resource_id != null
    )
    error_message = "When network_security_group.enabled = true, either set create = true or supply existing_resource_id."
  }
}

###############################################################################
# Log Analytics Workspace
###############################################################################

variable "log_analytics" {
  description = "Log Analytics Workspace used for diagnostic settings. Either create a new workspace or reference an existing one by resource ID."
  type = object({
    create               = bool
    existing_resource_id = optional(string)
    name                 = optional(string)
    sku                  = optional(string, "PerGB2018")
    retention_in_days    = optional(number, 30)
  })
  default = {
    create = false
  }

  validation {
    condition = (
      var.log_analytics.create ||
      var.log_analytics.existing_resource_id != null ||
      (!var.log_analytics.create && var.log_analytics.existing_resource_id == null)
    )
    error_message = "Provide existing_resource_id when log_analytics.create = false and diagnostics are required."
  }
}

###############################################################################
# Private DNS Zone (privatelink.servicebus.windows.net)
#
# Both Event Hubs and Service Bus private endpoints resolve through the SAME
# zone — `privatelink.servicebus.windows.net` — so a single zone serves both
# workloads. Either let this module create the zone (and link it to the VNet),
# or supply `existing_resource_id` for a centrally-managed (e.g. hub) zone.
###############################################################################

variable "private_dns_zone_servicebus" {
  description = "Private DNS zone (`privatelink.servicebus.windows.net`) used by Event Hub and Service Bus private endpoints. Create a new zone or reference an existing one by resource ID."
  type = object({
    create               = bool
    existing_resource_id = optional(string)
    # When existing_resource_id is supplied, set this to true to also manage a
    # virtual network link from this module's VNet to the existing zone. Leave
    # false (default) when the zone owner manages links centrally.
    link_existing_to_vnet = optional(bool, false)
    # Name of the virtual network link created on the zone. Only used when a
    # link is being created (either with a new zone or link_existing_to_vnet=true).
    vnet_link_name = optional(string)
  })
  default = {
    create = false
  }

  validation {
    condition = (
      var.private_dns_zone_servicebus.create ||
      var.private_dns_zone_servicebus.existing_resource_id != null ||
      (!var.private_dns_zone_servicebus.create && var.private_dns_zone_servicebus.existing_resource_id == null)
    )
    error_message = "When private_dns_zone_servicebus.create = false and DNS integration is required, existing_resource_id must be provided."
  }
}

###############################################################################
# Event Hub Namespace
###############################################################################

variable "event_hub" {
  description = "Event Hub namespace configuration. Always net-new when deployed. Public access is disabled and a private endpoint is created on the PE subnet."
  type = object({
    deploy   = bool
    name     = optional(string)
    sku      = optional(string, "Standard") # Standard or Premium
    capacity = optional(number, 1)
  })
  default = {
    deploy = false
  }

  validation {
    condition = (
      !var.event_hub.deploy ||
      contains(["Standard", "Premium"], coalesce(var.event_hub.sku, "Standard"))
    )
    error_message = "event_hub.sku must be either 'Standard' or 'Premium'."
  }
}

###############################################################################
# Service Bus Namespace
###############################################################################

variable "service_bus" {
  description = "Service Bus namespace configuration. Premium SKU only. Public access is disabled and a private endpoint is created on the PE subnet."
  type = object({
    deploy   = bool
    name     = optional(string)
    capacity = optional(number, 1) # Premium messaging units: 1, 2, 4, 8, 16
  })
  default = {
    deploy = false
  }

  validation {
    condition = (
      !var.service_bus.deploy ||
      contains([1, 2, 4, 8, 16], coalesce(var.service_bus.capacity, 1))
    )
    error_message = "service_bus.capacity (Premium messaging units) must be one of: 1, 2, 4, 8, 16."
  }
}
