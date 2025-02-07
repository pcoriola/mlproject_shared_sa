#Extract RG name
data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
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

(* #Create access policy for workspaces
resource "null_resource" "set_acl" {
  provisioner "local-exec" {
    command = <<EOT
      az storage container policy create \
        --account-name ${azurerm_storage_account.storage_account.name} \
        --container-name ${azurerm_storage_container.storage_container.name} \
        --name "write-access-policy" \
        --start $(date -u -d "now" +%Y-%m-%dT%H:%MZ) \
        --expiry $(date -u -d "1 hour" +%Y-%m-%dT%H:%MZ) \
        --permissions rl
    EOT
  }
} *)

# Generate SAS Token for each workspace
resource "azurerm_storage_blob_container_sas" "sas_token" {
  count                = length(var.workspace_id)
  storage_account_name = azurerm_storage_account.storage_account.name
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

# Outputs - Securely Retrieve SAS Tokens for ML Workspaces
output "sas_token" {
  value = { for idx, token in azurerm_storage_blob_container_sas.sas_token :
    azurerm_storage_container.storage_container[idx].name => sas_token.sas
  }
  sensitive = true
}
