resource "azurerm_resource_group" "testLab" {
 name     = "acctestLabrg"
 location = "West US 2"
}

resource "azurerm_virtual_network" "testLab" {
 name                = "acctvn"
 address_space       = ["10.0.0.0/16"]
 location            = "${azurerm_resource_group.testLab.location}"
 resource_group_name = "${azurerm_resource_group.testLab.name}"
}

resource "azurerm_subnet" "testLab" {
 name                 = "acctsub"
 resource_group_name  = "${azurerm_resource_group.testLab.name}"
 virtual_network_name = "${azurerm_virtual_network.testLab.name}"
 address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "testLab" {
 name                         = "publicIPForLB"
 location                     = "${azurerm_resource_group.testLab.location}"
 resource_group_name          = "${azurerm_resource_group.testLab.name}"
 public_ip_address_allocation = "static"
}

resource "azurerm_lb" "testLab" {
 name                = "loadBalancer"
 location            = "${azurerm_resource_group.testLab.location}"
 resource_group_name = "${azurerm_resource_group.testLab.name}"

 frontend_ip_configuration {
   name                 = "publicIPAddress"
   public_ip_address_id = "${azurerm_public_ip.testLab.id}"
 }
}

resource "azurerm_lb_backend_address_pool" "testLab" {
 resource_group_name = "${azurerm_resource_group.testLab.name}"
 loadbalancer_id     = "${azurerm_lb.testLab.id}"
 name                = "BackEndAddressPool"
}

resource "azurerm_network_interface" "testLab" {
 count               = 12
 name                = "acctni${count.index}"
 location            = "${azurerm_resource_group.testLab.location}"
 resource_group_name = "${azurerm_resource_group.testLab.name}"

 ip_configuration {
   name                          = "testLabConfiguration"
   subnet_id                     = "${azurerm_subnet.testLab.id}"
   private_ip_address_allocation = "dynamic"
   load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.testLab.id}"]
 }
}

resource "azurerm_managed_disk" "testLab" {
 count                = 12
 name                 = "datadisk_existing_${count.index}"
 location             = "${azurerm_resource_group.testLab.location}"
 resource_group_name  = "${azurerm_resource_group.testLab.name}"
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

resource "azurerm_availability_set" "avset" {
 name                         = "avset"
 location                     = "${azurerm_resource_group.testLab.location}"
 resource_group_name          = "${azurerm_resource_group.testLab.name}"
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "testLab" {
 count                 = 12
 name                  = "acctvm${count.index}"
 location              = "${azurerm_resource_group.testLab.location}"
 availability_set_id   = "${azurerm_availability_set.avset.id}"
 resource_group_name   = "${azurerm_resource_group.testLab.name}"
 network_interface_ids = ["${element(azurerm_network_interface.testLab.*.id, count.index)}"]
 vm_size               = "Standard_DS1_v2"

 # Uncomment this line to delete the OS disk automatically when deleting the VM
 # delete_os_disk_on_termination = true

 # Uncomment this line to delete the data disks automatically when deleting the VM
 # delete_data_disks_on_termination = true

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latestLab"
 }

 storage_os_disk {
   name              = "myosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 # Optional data disks
 storage_data_disk {
   name              = "datadisk_new_${count.index}"
   managed_disk_type = "Standard_LRS"
   create_option     = "Empty"
   lun               = 0
   disk_size_gb      = "1023"
 }

 storage_data_disk {
   name            = "${element(azurerm_managed_disk.testLab.*.name, count.index)}"
   managed_disk_id = "${element(azurerm_managed_disk.testLab.*.id, count.index)}"
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = "${element(azurerm_managed_disk.testLab.*.disk_size_gb, count.index)}"
 }

 os_profile {
   computer_name  = "hostname"
   admin_username = "testLabadmin"
   admin_password = "Password1234!"
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags {
   environment = "staging"
 }
}