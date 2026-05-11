variable "name" {
  description = "Name of the Service Bus namespace."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that will hold the namespace and its private endpoint."
  type        = string
}

variable "location" {
  description = "Azure region for the namespace and its private endpoint."
  type        = string
}

variable "capacity" {
  description = "Premium messaging units. Must be one of 1, 2, 4, 8, 16."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2, 4, 8, 16], var.capacity)
    error_message = "capacity (Premium messaging units) must be one of: 1, 2, 4, 8, 16."
  }
}

variable "private_endpoint_subnet_id" {
  description = "Resource ID of the subnet hosting the private endpoint."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "List of Private DNS Zone resource IDs to attach to the private endpoint's DNS zone group. Pass an empty list to omit the zone group."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Optional Log Analytics Workspace resource ID for diagnostic settings. When null, no diagnostic setting is created."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the namespace, private endpoint, and diagnostic setting."
  type        = map(string)
  default     = {}
}
