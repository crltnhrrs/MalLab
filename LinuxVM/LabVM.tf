# Configure the Azure Provider
provider "azurerm" {
  subscription_id = ""
  client_id       = ""
  client_secret   = "" #exp 12/22/2019
  tenant_id       = ""

}

# Create a resource group
resource "azurerm_resource_group" "testLab" {
  name     = "testLab"
  location = "eastus"
  tags {
        environment = "TestLab Demo"
    }
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "testLabNet" {
  name                = "LabNet"
  resource_group_name = "${azurerm_resource_group.testLab.name}"
  location            = "${azurerm_resource_group.testLab.location}"
  address_space       = ["10.20.0.0/16"]
  tags {
        environment = "TestLab Demo"
    }
}

# Create Subnets

resource "azurerm_subnet" "testLabsubnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.testLab.name}"
    virtual_network_name = "${azurerm_virtual_network.testLabNet.name}"
    address_prefix       = "10.20.2.0/24"
}

# create Public IP address 

resource "azurerm_public_ip" "testLabPublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = "${azurerm_resource_group.testLab.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "TestLab Demo"
    }
}

# Network Security Group
resource "azurerm_network_security_group" "testLabNsg" {
    name                = "testLabSecurityGroup"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.testLab.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "Terraform Demo"
    }
}
# Network Interface Card settings mapping NIC to publicIP 
resource "azurerm_network_interface" "testLabnic" {
    name                = "myNIC"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.testLab.name}"
    network_security_group_id = "${azurerm_network_security_group.testLabNsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.testLabsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.testLabPublicip.id}"
    }

    tags {
        environment = "testLab Demo"
    }
}
#randomizer 
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.testLab.name}"
    }

    byte_length = 8
}
#create storage account
resource "azurerm_storage_account" "mystorageaccount" {
    name                = "diag${random_id.randomId.hex}"
    resource_group_name = "${azurerm_resource_group.testLab.name}"
    location            = "eastus"
    account_replication_type = "LRS"
    account_tier = "Standard"

    tags {
        environment = "testLab Demo"
    }
}
# Create CentOS Virtual Machine

resource "azurerm_virtual_machine" "testLabvm" {
    name                  = "myVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.testLab.name}"
    network_interface_ids = ["${azurerm_network_interface.testLabnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myvm"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = ""
        }
    }

    boot_diagnostics {
        enabled     = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "testLab Demo"
    }
} #az vm show --resource-group testLab --name myVM -d --query [publicIps] --o tsv