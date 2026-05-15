# ============================================================
# terraform.tfvars — Personnalisez ces valeurs avant de déployer
# ============================================================

resource_group_name = "RG-DEMO-ATT"
location            = "norwayeast"

# Réseau
vnet_name              = "vnet-prod-fr-sftp"
vnet_address_space     = ["10.0.0.0/16"]
subnet_firewall_prefix = "10.0.1.0/26"
subnet_pe_prefix       = "10.0.2.0/24"

# Firewall
firewall_name           = "vnet-prod-fr-Firewall"
firewall_public_ip_name = "public-ip-azfw"
firewall_policy_name    = "fw-policy-sftp"

# NAT
nat_rule_collection_name = "fw-policy-sftp"
nat_rule_name            = "dnat-rule-sftp"

# Storage — DOIT être unique globalement (3-24 chars, minuscules/chiffres uniquement)
storage_account_name = "sftpdemoatt2024"
container_name       = "ftp"
private_endpoint_name = "privateendpoint-sftp"

# Utilisateur SFTP
sftp_local_user_name = "test"

# Tags
tags = {
  Environment = "Demo"
  Project     = "SFTP-Azure-Storage"
  ManagedBy   = "Terraform"
}
