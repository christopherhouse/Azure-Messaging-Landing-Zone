variable "resource_group_name" {
  description = "Resource group that will hold the Private DNS Zone."
  type        = string
}

variable "tags" {
  description = "Tags to apply to the zone and any associated VNet link."
  type        = map(string)
  default     = {}
}

variable "vnet_link" {
  description = "Optional virtual network link to create against the new zone. Set to null to skip."
  type = object({
    name               = string
    virtual_network_id = string
  })
  default = null
}
