variable "name" {
  description = "Name of the Log Analytics Workspace."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that will hold the workspace."
  type        = string
}

variable "location" {
  description = "Azure region for the workspace."
  type        = string
}

variable "sku" {
  description = "Workspace SKU."
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "Data retention in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to the workspace."
  type        = map(string)
  default     = {}
}
