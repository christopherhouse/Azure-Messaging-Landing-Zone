variable "name" {
  description = "Name of the private endpoint subnet."
  type        = string
}

variable "address_prefixes" {
  description = "Address prefixes (CIDR blocks) assigned to the subnet."
  type        = list(string)
}

variable "virtual_network_name" {
  description = "Name of the virtual network that owns the subnet."
  type        = string
}

variable "virtual_network_resource_group_name" {
  description = "Resource group name of the virtual network that owns the subnet (may differ from this module's RG when the VNet is pre-existing)."
  type        = string
}

variable "network_security_group_id" {
  description = "Optional NSG resource ID to associate with the subnet. When null, no association is created."
  type        = string
  default     = null
}
