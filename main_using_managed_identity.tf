#Extract subscription details
data "azurerm_subscription" "current" {}

#Extract RG name
data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}

#Extract Key Vault details
data "azurerm_key_vault" "keyvault" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

#Extract storage account name
data "azurerm_storage_account" "storage_account" {
  name                    = var.storage_account
  resource_group_name     = data.azurerm_resource_group.resource_group.name
}
#Create storage containers
resource "azurerm_storage_container" "storage_container" {
  count                 = length(var.workspace_id)
  name                  = "storage-container-${var.workspace_id[count.index]}"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "private"
}

resource "azurerm_machine_learning_workspace" "workspace" {
  count               = length(var.workspace_id)
  name                = "workspace-${var.workspace_id[count.index]}"
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }
}

#Role assignmanet to grant access for MI to storage container
resource "azurerm_role_assignment" "container_access" {
  for_each            = toset(var.workspace_id)
  scope               = azurerm_storage_container.storage_container[each.key].resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id        = azurerm_machine_learning_workspace.workspace[each.key].identity[0].principal_id
}
