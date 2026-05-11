variable "name" {
  description = "Name of the network security group."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that will hold the NSG."
  type        = string
}

variable "location" {
  description = "Azure region for the NSG."
  type        = string
}

variable "tags" {
  description = "Tags to apply to the NSG."
  type        = map(string)
  default     = {}
}
