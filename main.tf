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






