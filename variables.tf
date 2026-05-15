variable "resource_group_name" {
  description = "Nom du groupe de ressources"
  type        = string
  default     = "RG-DEMO-ATT"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "norwayeast"
}

variable "vnet_name" {
  description = "Nom du Virtual Network"
  type        = string
  default     = "vnet-prod-fr-sftp"
}

variable "vnet_address_space" {
  description = "Plage d'adresses du VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_firewall_name" {
  description = "Nom du subnet pour Azure Firewall (doit être AzureFirewallSubnet)"
  type        = string
  default     = "AzureFirewallSubnet"
}

variable "subnet_firewall_prefix" {
  description = "CIDR du subnet Azure Firewall"
  type        = string
  default     = "10.0.1.0/26"
}

variable "subnet_pe_name" {
  description = "Nom du subnet pour le Private Endpoint"
  type        = string
  default     = "privateendpoint"
}

variable "subnet_pe_prefix" {
  description = "CIDR du subnet Private Endpoint"
  type        = string
  default     = "10.0.2.0/24"
}

variable "firewall_name" {
  description = "Nom de l'Azure Firewall"
  type        = string
  default     = "vnet-prod-fr-Firewall"
}

variable "firewall_public_ip_name" {
  description = "Nom de l'IP publique du Firewall"
  type        = string
  default     = "public-ip-azfw"
}

variable "storage_account_name" {
  description = "Nom du compte de stockage (doit être unique globalement, minuscules, 3-24 chars)"
  type        = string
  default     = "sftpdemopp"
}

variable "container_name" {
  description = "Nom du container Blob (répertoire SFTP)"
  type        = string
  default     = "ftp"
}

variable "private_endpoint_name" {
  description = "Nom du Private Endpoint"
  type        = string
  default     = "privateendpoint-sftp"
}

variable "sftp_local_user_name" {
  description = "Nom de l'utilisateur local SFTP"
  type        = string
  default     = "test"
}

variable "firewall_policy_name" {
  description = "Nom de la politique du Firewall"
  type        = string
  default     = "fw-policy-sftp"
}

variable "nat_rule_collection_name" {
  description = "Nom de la collection de règles NAT"
  type        = string
  default     = "fw-policy-sftp"
}

variable "nat_rule_name" {
  description = "Nom de la règle NAT DNAT"
  type        = string
  default     = "dnat-rule-sftp"
}

variable "tags" {
  description = "Tags appliqués à toutes les ressources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "SFTP-Azure-Storage"
    ManagedBy   = "Terraform"
  }
}
