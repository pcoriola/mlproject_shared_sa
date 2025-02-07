#Resource group name
variable "resource_group_name" {
  description = "Resource Group"
  type        = string
}

#Location
variable "location" {
  description = "Region"
  type        = string
  default     = "West Europe"
}

#Storage Account Name
variable "storage_account_name" {
  description = "Storage Account"
  type        = string
}

#Key Vault
variable "key_vault_name" {
  description = "Key Vault for storing SAS tokens"
  type        = string
}

#List of ML workspaces
variable "workspace_list" {
  description = "List of ML workspaces"
  type        = list(string)
  default     = ["workspace1", "workspace2", "workspace3"]
}

#Tenant_id
variable "tenant_id" {
  description = "Tenant ID"
  type        = string
}

#Workspace ID
#variable "workspace_id" {
#  description = "ML Project Workspace IDs"
#  type        = list(string)
#}
