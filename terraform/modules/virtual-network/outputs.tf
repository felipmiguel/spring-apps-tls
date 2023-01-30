output "virtual_network_id" {
  value       = azurerm_virtual_network.virtual_network.id
  description = "Application Virtual Network"
}

output "app_subnet_id" {
  value       = azurerm_subnet.app_subnet.id
  description = "Application Subnet"
}

output "service_subnet_id" {
  value       = azurerm_subnet.service_subnet.id
  description = "Azure Spring Apps services subnet"
}

output "jumpbox_subnet_id" {
  value       = azurerm_subnet.jumpbox_subnet.id
  description = "Jumpbox subnet"
}

output "bastion_subnet_id" {
  value       = azurerm_subnet.bastion_subnet.id
  description = "Bastion subnet"
}

output "appgateway_subnet_id" {
  value       = azurerm_subnet.appgateway_subnet.id
  description = "Application Gateway subnet"
}
