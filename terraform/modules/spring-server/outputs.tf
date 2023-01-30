output "spring_cloud_service_name" {
  value       = local.spring_cloud_service_name
  description = "Azure Spring Apps service name"
}

output "spring_cloud_server_id" {
  value       = azurerm_spring_cloud_service.application.id
  description = "Azure Spring Apps gateway name"
}
