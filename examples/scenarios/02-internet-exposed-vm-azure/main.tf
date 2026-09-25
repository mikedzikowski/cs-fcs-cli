###############################################################################
# SCENARIO: Internet-exposed Windows/Linux VM on Azure
#
# A VM with a public IP, an NSG allowing RDP/SSH/WinRM from the Internet tag,
# password authentication with a hardcoded password, no disk encryption, boot
# diagnostics off, and a system-assigned identity holding subscription Owner.
#
# Attack path this models:
#   internet -> NSG allows :3389 from Internet -> password spray
#            -> VM identity has Owner -> subscription takeover
#
# DO NOT APPLY.
###############################################################################

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "exposed" {
  name     = "scenario-exposed-vm-rg"
  location = "eastus"
}

resource "azurerm_virtual_network" "exposed" {
  name                = "scenario-exposed-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.exposed.location
  resource_group_name = azurerm_resource_group.exposed.name
}

resource "azurerm_subnet" "exposed" {
  name                 = "scenario-exposed-subnet"
  resource_group_name  = azurerm_resource_group.exposed.name
  virtual_network_name = azurerm_virtual_network.exposed.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Static public IP directly on the VM, no bastion, no load balancer
# Category: Networking and Firewall
resource "azurerm_public_ip" "exposed" {
  name                = "scenario-exposed-pip"
  location            = azurerm_resource_group.exposed.location
  resource_group_name = azurerm_resource_group.exposed.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NSG exposing every remote-management port to the internet
# Category: Networking and Firewall
resource "azurerm_network_security_group" "exposed" {
  name                = "scenario-exposed-nsg"
  location            = azurerm_resource_group.exposed.location
  resource_group_name = azurerm_resource_group.exposed.name

  security_rule {
    name                       = "AllowRDPFromInternet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSHFromInternet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowWinRMFromInternet"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowEverythingElse"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# The scanner's azurerm NSG rules match standalone azurerm_network_security_rule
# resources rather than the inline security_rule blocks above, so the same
# exposure is also declared here to make the detections fire.
# Category: Networking and Firewall
resource "azurerm_network_security_rule" "ssh_from_internet" {
  name                        = "StandaloneAllowSSH"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.exposed.name
  network_security_group_name = azurerm_network_security_group.exposed.name
}

resource "azurerm_network_security_rule" "rdp_from_internet" {
  name                        = "StandaloneAllowRDP"
  priority                    = 210
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.exposed.name
  network_security_group_name = azurerm_network_security_group.exposed.name
}

resource "azurerm_network_security_rule" "all_ports_from_internet" {
  name                        = "StandaloneAllowEverything"
  priority                    = 220
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.exposed.name
  network_security_group_name = azurerm_network_security_group.exposed.name
}

resource "azurerm_network_interface" "exposed" {
  name                = "scenario-exposed-nic"
  location            = azurerm_resource_group.exposed.location
  resource_group_name = azurerm_resource_group.exposed.name
  # IP forwarding lets the host route traffic deeper into the VNet
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.exposed.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.exposed.id
  }
}

resource "azurerm_network_interface_security_group_association" "exposed" {
  network_interface_id      = azurerm_network_interface.exposed.id
  network_security_group_id = azurerm_network_security_group.exposed.id
}

# The exposed VM: password auth, hardcoded credentials, unencrypted disk
# Categories: Access Control, Secret Management, Encryption, Observability
resource "azurerm_linux_virtual_machine" "exposed" {
  name                = "scenario-exposed-vm"
  resource_group_name = azurerm_resource_group.exposed.name
  location            = azurerm_resource_group.exposed.location
  size                = "Standard_D2s_v3"

  admin_username                  = "azureuser"
  admin_password                  = "Password123!"
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.exposed.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    # No disk encryption set configured
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # VM identity granted subscription Owner below
  identity {
    type = "SystemAssigned"
  }

  # Boot diagnostics disabled, so there is no console record
  # Category: Observability
}

# VM's managed identity holds Owner on the whole subscription
# Category: Access Control
resource "azurerm_role_assignment" "vm_owner" {
  scope                = "/subscriptions/00000000-0000-0000-0000-000000000000"
  role_definition_name = "Owner"
  principal_id         = azurerm_linux_virtual_machine.exposed.identity[0].principal_id
}
