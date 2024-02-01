terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

variable "prefix" {
	default = "examjwe"
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
  subscription_id = "0eea535e-a7c0-4758-bffc-aa9ca2da6765"
  client_id       = "50649df4-1904-40e8-8399-dda8f1e15fb8"
  client_secret   = "Gyj8Q~k2VF3HXKtjSA5.tXd2~ZMm2awtuVdr_axq"
  tenant_id       = "5aa79040-afd4-4978-a730-7a278afe0dd2"
  environment     = "public"
}

resource "azurerm_resource_group" "example" {
  name     = "myRG_${var.prefix}"
  location = "West Europe"
}

resource "azurerm_application_gateway" "example" {
  name                = "${var.prefix}-app-gateway"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }
  
  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.0"
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.gateway.id
  }

  frontend_port {
    name = "httpPort"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "publicIPAddress"
    public_ip_address_id = azurerm_public_ip.example.id
  }


  http_listener {
    name                           = "listener"
    frontend_ip_configuration_name = "publicIPAddress"
    frontend_port_name             = "httpPort"
	protocol	= 	"Http"
  }


  backend_address_pool {
    name = "backendPool"
  }

  backend_http_settings {
    name                  = "httpSettings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
  }
  
	request_routing_rule {
		name                       = "${var.prefix}-rule"
		rule_type                  = "Basic"
		http_listener_name         = "listener"
		backend_address_pool_name  = "backendPool"
		backend_http_settings_name = "httpSettings"
		priority                   = 1
	}
}

resource "azurerm_public_ip" "example" {
  name                = "${var.prefix}-public-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_storage_account" "example" {
  name                     = "${var.prefix}strgacc"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_log_analytics_workspace" "example" {
  name                = "${var.prefix}-workspace"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "example" {
  name               = "${var.prefix}-monitordiag"
  target_resource_id = azurerm_storage_account.example.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id

  metric {
    category = "Capacity"
    enabled  = true
  }
}


resource "azurerm_managed_disk" "example" {
  name                 = "${var.prefix}disk"
  location			   = azurerm_resource_group.example.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 100
}

resource "azurerm_virtual_network" "example" {
  name                = "myVNet_${var.prefix}"
  address_space       = ["10.0.0.0/8"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "${var.prefix}internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.14.0/24"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "${var.prefix}internalgateway"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.15.0/24"]
}

resource "azurerm_network_interface" "vm1" {
  name                = "${var.prefix}nic1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "myVM1_${var.prefix}"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  size               = "Standard_F2"
network_interface_ids = [
    azurerm_network_interface.vm1.id,
  ]
computer_name  = "hostname"
admin_username = "adminuser"
admin_password = "Password1234!"

disable_password_authentication = false


  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_network_interface" "vm2" {
  name                = "${var.prefix}nic2"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "myVM2_${var.prefix}"
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  size               = "Standard_F2"
network_interface_ids = [
    azurerm_network_interface.vm2.id,
  ]
computer_name  = "hostname"
admin_username = "adminuser"
admin_password = "Password1234!"

disable_password_authentication = false


  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}
