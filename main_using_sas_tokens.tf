#Extract subscription details
data "azurerm_subscription" "current" {}

#Extract resource group details
data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}

#Extract storage account details
data "azurerm_storage_account" "storage_account" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.resource_group.name
}

#Extract existing ml workspaces
data "azurerm_machine_learning_workspace" "workspace" {
  for_each            = toset(var.workspace_list)
  name                = each.key
  resource_group_name = var.resource_group_name
}

# Create storage containers for each ML workspace
resource "azurerm_storage_container" "storage_container" {
  count                = length(var.workspace_list)
  name                 = "storage-container-${var.workspace_list[count.index]}"
  storage_account_name = data.azurerm_storage_account.storage_account.name
  container_access_type = "private"
}

# Generate SAS Token for each workspace
resource "azurerm_storage_blob_container_sas" "sas_token" {
  count                = length(var.workspace_list)
  storage_account_name = data.azurerm_storage_account.storage_account.name
  container_name       = azurerm_storage_container.storage_container[count.index].name
  https_only           = true

  start  = timestamp()
  expiry = timeadd(timestamp(), "672h")

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
  }
}

#Output SAS tokens
output "sas_tokens" {
  value = { for idx, token in azurerm_storage_blob_container_sas.sas_token :
    azurerm_storage_container.storage_container[idx].name => token.sas
  }
  sensitive = true
}

#Create Key Vault to store SAS tokens
resource "azurerm_key_vault" "key_vault" {
  name                = "keyvault-${data.azurerm_storage_account.storage_account.name}"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = var.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_subscription.current.tenant_id
}

#Upload SAS token into key vault
resource "azurerm_key_vault_secret" "sas_token_kv" {
  count        = length(var.workspace_names)
  name         = "sas-token-${var.workspace_list[count.index]}"
  value        = azurerm_storage_blob_container_sas.sas_token[count.index].sas
  key_vault_id = azurerm_key_vault.key_vault.id
}

# Allow access to for each workspace to own SAS token
resource "azurerm_key_vault_access_policy" "workspace_access" {
  count        = length(var.workspace_list)
  key_vault_id = azurerm_key_vault.key_vault.id
  tenant_id    = data.azurerm_subscription.current.tenant_id
  object_id    = data.azurerm_machine_learning_workspace.workspace[var.workspace_list[count.index]].identity[0].principal_id
  secret_permissions = ["Get"]
}
