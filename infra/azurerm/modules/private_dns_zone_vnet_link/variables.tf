variable "name" {
  description = "Name of the virtual network link."
  type        = string
}

variable "dns_zone_name" {
  description = "Name of the pre-existing Private DNS Zone."
  type        = string
}

variable "dns_zone_resource_group_name" {
  description = "Resource group name of the pre-existing Private DNS Zone."
  type        = string
}

variable "virtual_network_id" {
  description = "Resource ID of the virtual network to link to the zone."
  type        = string
}

variable "tags" {
  description = "Tags to apply to the link."
  type        = map(string)
  default     = {}
}
