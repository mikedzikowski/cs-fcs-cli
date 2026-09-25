###############################################################################
# Platform: Terraform (azurerm provider)
# Purpose:  Azure-specific misconfigurations for FCS CLI IaC detections.
###############################################################################

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "demo" {
  name     = "fcs-demo-rg"
  location = "eastus"
}

# Storage account: HTTP allowed, public blob access, no min TLS, public network
# Categories: Encryption, Access Control, Networking and Firewall
resource "azurerm_storage_account" "insecure" {
  name                            = "fcsdemoinsecuresa"
  resource_group_name             = azurerm_resource_group.demo.name
  location                        = azurerm_resource_group.demo.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  enable_https_traffic_only       = false
  min_tls_version                 = "TLS1_0"
  allow_nested_items_to_be_public = true
  public_network_access_enabled   = true
}

resource "azurerm_storage_container" "public" {
  name                  = "fcs-demo-public"
  storage_account_name  = azurerm_storage_account.insecure.name
  container_access_type = "container"
}

# NSG: SSH and RDP open to Internet
# Category: Networking and Firewall
resource "azurerm_network_security_group" "wide_open" {
  name                = "fcs-demo-nsg"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  security_rule {
    name                       = "AllowSSHFromInternet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRDPFromInternet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

# SQL Server: weak admin password, public access, no auditing, no TDE
# Categories: Access Control, Observability, Encryption
resource "azurerm_mssql_server" "insecure" {
  name                          = "fcs-demo-sql"
  resource_group_name           = azurerm_resource_group.demo.name
  location                      = azurerm_resource_group.demo.location
  version                       = "12.0"
  administrator_login           = "sqladmin"
  administrator_login_password  = "Password123!"
  minimum_tls_version           = "1.0"
  public_network_access_enabled = true
}

resource "azurerm_mssql_firewall_rule" "allow_all" {
  name             = "AllowAllIPs"
  server_id        = azurerm_mssql_server.insecure.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# AKS: no RBAC, public API server, no network policy, no monitoring
# Categories: Access Control, Networking and Firewall, Observability
resource "azurerm_kubernetes_cluster" "insecure" {
  name                              = "fcs-demo-aks"
  location                          = azurerm_resource_group.demo.location
  resource_group_name               = azurerm_resource_group.demo.name
  dns_prefix                        = "fcsdemo"
  role_based_access_control_enabled = false
  private_cluster_enabled           = false
  local_account_disabled            = false

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
  }
}

# Key Vault: no purge protection, no soft delete retention, public access
# Categories: Backup, Access Control
resource "azurerm_key_vault" "insecure" {
  name                          = "fcs-demo-kv"
  location                      = azurerm_resource_group.demo.location
  resource_group_name           = azurerm_resource_group.demo.name
  tenant_id                     = "00000000-0000-0000-0000-000000000000"
  sku_name                      = "standard"
  purge_protection_enabled      = false
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }
}
