terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }
  required_version = ">=0.14.9"
  backend "remote" {
    organization = "none1233"

    workspaces {
      name = "my-workspace"
    }
  }
}

provider "azurerm" {
  features {

  }
}

#virtual network
resource "azurerm_resource_group" "lab_vnet" {
  name     = "lab_vnet"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.lab_vnet.location
  resource_group_name = azurerm_resource_group.lab_vnet.name
}


#window virtual machine 
resource "azurerm_resource_group" "window_vm" {
  name     = "window_vm"
  location = var.location
}

resource "azurerm_subnet" "window_subnet" {
  name                 = "window_subnet_internal"
  resource_group_name  = azurerm_resource_group.lab_vnet.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "window_nic" {
  name                = "window_nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.window_vm.name
  ip_configuration {
    name                          = "windowNicConfig"
    subnet_id                     = azurerm_subnet.window_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.window_public_ip.id
  }
}


##Create window VM
resource "azurerm_virtual_machine" "window_vm" {
  name = "windowVM01"

  location            = var.location
  resource_group_name = azurerm_resource_group.window_vm.name

  network_interface_ids = [azurerm_network_interface.window_nic.id]
  vm_size               = "Standard_F2"

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "windowVM01"
    admin_username = var.account_username
    admin_password = var.account_password
    custom_data    = file("./files/winrm.ps1")
  }

  os_profile_windows_config {
    provision_vm_agent = true
    winrm {
      protocol = "http"
    }

    # Auto-Login's required to configure WinRM
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.account_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.account_username}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = file("./files/FirstLogonCommands.xml")
    }
  }

  connection {
    host     = azurerm_public_ip.window_public_ip.ip_address
    type     = "winrm"
    port     = 5985
    https    = false
    timeout  = "15m"
    user     = var.account_username
    password = var.account_password

  }

  provisioner "file" {
    source      = "files/config.ps1"
    destination = "c:/terraform/config.ps1"
  }

  provisioner "remote-exec" {
    on_failure = continue
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File C:/terraform/config.ps1",
    ]
  }

  provisioner "local-exec" {
    command = "terraform output -json > ./ansible/data/ip.json;"
  }

}

#Create window public ip
resource "azurerm_public_ip" "window_public_ip" {
  name                = "window_public_ip"
  location            = azurerm_resource_group.window_vm.location
  resource_group_name = azurerm_resource_group.window_vm.name
  allocation_method   = "Static"
}

# Create Network Security Group and rule for window
resource "azurerm_network_security_group" "window_nsg" {
  name                = "customWindowNsg"
  location            = azurerm_resource_group.window_vm.location
  resource_group_name = azurerm_resource_group.window_vm.name
  security_rule {
    name                       = "windown-rule"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = [5985, 22, 3389]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ping-rule"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# connect network security group to linux network interface
resource "azurerm_network_interface_security_group_association" "win" {
  network_interface_id      = azurerm_network_interface.window_nic.id
  network_security_group_id = azurerm_network_security_group.window_nsg.id
}


