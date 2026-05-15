# ============================================================
# OUTPUTS
# ============================================================

output "resource_group_name" {
  description = "Nom du groupe de ressources déployé"
  value       = azurerm_resource_group.rg.name
}

output "vnet_name" {
  description = "Nom du Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "firewall_public_ip" {
  description = "Adresse IP publique de l'Azure Firewall (point d'entrée SFTP)"
  value       = azurerm_public_ip.firewall_pip.ip_address
}

output "storage_account_name" {
  description = "Nom du compte de stockage Azure"
  value       = azurerm_storage_account.sftp_storage.name
}

output "storage_account_primary_endpoint" {
  description = "Endpoint Blob principal du compte de stockage"
  value       = azurerm_storage_account.sftp_storage.primary_blob_endpoint
}

output "private_endpoint_ip" {
  description = "Adresse IP privée du Private Endpoint (cible NAT)"
  value       = azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address
}

output "sftp_connection_string" {
  description = "Commande de connexion SFTP (depuis un client externe)"
  value       = "sftp ${var.sftp_local_user_name}.${azurerm_storage_account.sftp_storage.name}@${azurerm_public_ip.firewall_pip.ip_address}"
}

output "sftp_user_name" {
  description = "Nom d'utilisateur SFTP (format storage.user)"
  value       = "${azurerm_storage_account.sftp_storage.name}.${azurerm_storage_account_local_user.sftp_user.name}"
}

output "sftp_container_name" {
  description = "Nom du container Blob utilisé comme répertoire SFTP"
  value       = azurerm_storage_container.sftp_container.name
}

output "nat_rule_summary" {
  description = "Résumé de la règle DNAT configurée"
  value = {
    policy_name      = var.nat_rule_collection_name
    rule_name        = var.nat_rule_name
    source           = "*"
    destination_ip   = azurerm_public_ip.firewall_pip.ip_address
    destination_port = "22"
    translated_ip    = azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address
    translated_port  = "22"
  }
}
