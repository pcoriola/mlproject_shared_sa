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

#Create Key Vault
resource "azurerm_key_vault" "key_vault" {
  name                = "keyvault-${data.azurerm_storage_account.storage_account.name}"
  resource_group_name = data.azurerm_resource_group.resource_group.name
  location            = var.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_subscription.current.tenant_id
}

#Upload sas token into KV
resource "azurerm_key_vault_secret" "sas_token_kv" {
  count        = length(var.workspace_id)
  name         = "sas-token-kv-${var.workspace_id[count.index]}"
  value        = azurerm_storage_blob_container_sas.sas_token[count.index].sas
  key_vault_id = azurerm_key_vault.ml_key_vault.id
}

# Allow ml workspace access to SAS token
resource "azurerm_key_vault_access_policy" "workspace_access" {
  count        = length(var.workspace_id)
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id = data.azurerm_subscription.current.tenant_id
  object_id = var.workspace_id[count.index]
  secret_permissions = ["Get"]
}

