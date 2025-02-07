variable "resource_group_name" {
  description = "Resource Group"
  type        = string
}

variable "storage_account_name" {
  description = "Storage Account"
  type        = string
}

variable "location" {
  description = "Region"
  type        = string
  default     = "West Europe"
}

variable "workspace_id" {
  description = "ML Project Workspace IDs"
  type        = list(string)
}
