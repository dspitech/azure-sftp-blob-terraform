# ============================================================
# RESOURCE GROUP
# ============================================================
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ============================================================
# NETWORKING — Virtual Network + Subnets
# ============================================================
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Subnet dédié à l'Azure Firewall (nom imposé par Azure)
resource "azurerm_subnet" "firewall_subnet" {
  name                 = var.subnet_firewall_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_firewall_prefix]
}

# Subnet pour le Private Endpoint du Storage Account
resource "azurerm_subnet" "pe_subnet" {
  name                 = var.subnet_pe_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_pe_prefix]

  private_endpoint_network_policies = "Disabled"
}

# ============================================================
# AZURE FIREWALL — IP publique + instance Standard
# ============================================================
resource "azurerm_public_ip" "firewall_pip" {
  name                = var.firewall_public_ip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "fw_policy" {
  name                = var.firewall_policy_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "firewall" {
  name                = var.firewall_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.fw_policy.id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig-firewall"
    subnet_id            = azurerm_subnet.firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

# ============================================================
# RÈGLE NAT DNAT — Port 22 → Private Endpoint Storage
# ============================================================
resource "azurerm_firewall_policy_rule_collection_group" "nat_rcg" {
  name               = "nat-rcg-sftp"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 100

  nat_rule_collection {
    name     = var.nat_rule_collection_name
    priority = 100
    action   = "Dnat"

    rule {
      name             = var.nat_rule_name
      protocols        = ["TCP", "UDP"]
      source_addresses = ["*"]

      destination_address = azurerm_public_ip.firewall_pip.ip_address
      destination_ports   = ["22"]

      translated_address = azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address
      translated_port    = "22"
    }
  }
}

# ============================================================
# STORAGE ACCOUNT — SFTP activé + Hierarchical Namespace
# ============================================================
resource "azurerm_storage_account" "sftp_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Requis pour activer le SFTP
  is_hns_enabled  = true
  sftp_enabled    = true

  # Accès réseau : désactiver l'accès public
  public_network_access_enabled = true

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = false
  }

  tags = var.tags
}

# ============================================================
# CONTAINER BLOB — Répertoire d'accueil SFTP
# ============================================================
resource "azurerm_storage_container" "sftp_container" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.sftp_storage.name
  container_access_type = "private"
}

# ============================================================
# PRIVATE ENDPOINT — Storage Account (blob / SFTP)
# ============================================================
resource "azurerm_private_dns_zone" "blob_dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_dns_link" {
  name                  = "blob-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "storage_pe" {
  name                = var.private_endpoint_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-storage-sftp"
    private_connection_resource_id = azurerm_storage_account.sftp_storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob_dns.id]
  }
}

# ============================================================
# UTILISATEUR LOCAL SFTP
# ============================================================
resource "azurerm_storage_account_local_user" "sftp_user" {
  name                 = var.sftp_local_user_name
  storage_account_id   = azurerm_storage_account.sftp_storage.id
  ssh_password_enabled = true
  ssh_key_enabled      = false

  home_directory = var.container_name

  permission_scope {
    resource_name = var.container_name
    service       = "blob"

    permissions {
      read             = true
      write            = true
      list             = true
      delete           = true
      create           = true
    }
  }

  depends_on = [azurerm_storage_container.sftp_container]
}
