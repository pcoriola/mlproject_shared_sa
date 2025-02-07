#Extract resource group details
data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}

#Extract storage account details
data "azurerm_storage_account" "storage_account" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.resource_group.name
}

#Extract workspace details
data "azurerm_machine_learning_workspace" "workspace" {
  for_each            = toset(var.workspace_name)
  name                = each.key
  resource_group_name = var.resource_group_name
}

#Create storage containers
resource "azurerm_storage_container" "storage_container" {
  count                = length(var.workspace_names)
  name                 = "storage-container-${var.workspace_names[count.index]}"
  storage_account_name = data.azurerm_storage_account.storage_account.name
  container_access_type = "private"
}

#Enable system-assigned managed identity on workspaces
resource "azurerm_machine_learning_workspace" "workspace" {
  count               = length(var.workspace_names)
  name                = var.workspace_names[count.index]
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }
}

#Perform role assignment to allow each ml workspace to access only its storage container
resource "azurerm_role_assignment" "container_access" {
  count               = length(var.workspace_names)
  scope               = azurerm_storage_container.storage_container[count.index].resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id        = data.azurerm_machine_learning_workspace.workspace[var.workspace_names[count.index]].identity[0].principal_id
}
