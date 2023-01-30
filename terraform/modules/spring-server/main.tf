# Azure Spring Apps is not yet supported in azurecaf_name
locals {
  spring_cloud_service_name = "asa-${var.application_name}-${var.environment}"
  spring_cloud_app_name     = "app-${var.application_name}"
  spring_cloud_gateway_name = "gateway-${var.application_name}"

  # Azure Spring Apps Resource Provider object id. It is a constant and it is required to manage the VNET.
  azure_spring_apps_provisioner_object_id = "d2531223-68f9-459e-b225-5592f90d145e"
}

data "azurerm_client_config" "current" {}

# Assign Owner role to Azure Spring Apps Resource Provider on the Virtual Network used by the deployed service
# Make sure the SPID used to provision terraform has privileges to do role assignments.
resource "azurerm_role_assignment" "provider_owner" {
  scope                = var.virtual_network_id
  role_definition_name = "Owner"
  principal_id         = local.azure_spring_apps_provisioner_object_id
}

# This creates the Azure Spring Apps that the service use
resource "azurerm_spring_cloud_service" "application" {
  name                = local.spring_cloud_service_name
  resource_group_name = var.resource_group
  location            = var.location
  sku_name            = "S0"

  tags = {
    "environment"      = var.environment
    "application-name" = var.application_name
  }

  network {
    app_subnet_id             = var.app_subnet_id
    service_runtime_subnet_id = var.service_subnet_id
    cidr_ranges               = var.cidr_ranges
  }

  depends_on = [
    azurerm_role_assignment.provider_owner
  ]
}

# Gets the Azure Spring Apps internal load balancer IP address once it is deployed
data "azurerm_lb" "asc_internal_lb" {
  resource_group_name = "ap-svc-rt_${azurerm_spring_cloud_service.application.name}_${azurerm_spring_cloud_service.application.location}"
  name                = "kubernetes-internal"
  depends_on = [
    azurerm_spring_cloud_service.application
  ]
}

# Create DNS zone
resource "azurerm_private_dns_zone" "private_dns_zone" {
  name                = "private.azuremicroservices.io"
  resource_group_name = var.resource_group
}

# Link DNS to Azure Spring Apps virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_zone_link_asc" {
  name                  = "asa-dns-link"
  resource_group_name   = var.resource_group
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_zone.name
  virtual_network_id    = var.virtual_network_id
}

# Creates an A record that points to Azure Spring Apps internal balancer IP
resource "azurerm_private_dns_a_record" "internal_lb_record" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.private_dns_zone.name
  resource_group_name = var.resource_group
  ttl                 = 300
  records             = [data.azurerm_lb.asc_internal_lb.private_ip_address]
}



resource "azurerm_key_vault_access_policy" "spring_apps_provisioner_access" {
  key_vault_id = var.vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = local.azure_spring_apps_provisioner_object_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]
}

data "azuread_service_principal" "asa_domain_management" {
  display_name = "Azure Spring Cloud Domain-Management"
}

resource "azurerm_key_vault_access_policy" "spring_apps_cloud_domain_management" {
  key_vault_id = var.vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.asa_domain_management.object_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]
}




# # This creates the application definition
# resource "azurerm_spring_cloud_app" "spring_gateway" {
#   name                = local.spring_cloud_gateway_name
#   resource_group_name = var.resource_group
#   service_name        = azurerm_spring_cloud_service.application.name
#   identity {
#     type = "SystemAssigned"
#   }

#   tls_enabled = true
#   https_only  = true
#   is_public   = true
# }

# resource "azurerm_key_vault_access_policy" "gateway" {
#   key_vault_id = var.vault_id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = azurerm_spring_cloud_app.spring_gateway.identity[0].principal_id

#   secret_permissions = [
#     "Get",
#     "List"
#   ]

#   certificate_permissions = [
#     "Get",
#     "List"
#   ]
# }


# # This creates the application deployment. Terraform provider doesn't support dotnet yet
# resource "azurerm_spring_cloud_java_deployment" "gateway_default_deployment" {
#   name                = "default"
#   spring_cloud_app_id = azurerm_spring_cloud_app.spring_gateway.id
#   instance_count      = 1
#   runtime_version     = "Java_17"

#   quota {
#     cpu    = "1"
#     memory = "1Gi"
#   }

#   environment_variables = {

#     # Required for configuring the azure-spring-boot-starter-keyvault-secrets library
#     "AZURE_KEYVAULT_ENABLED"    = "true"
#     "AZURE_KEYVAULT_URI"        = var.vault_uri
#     "SERVER_SSL_KEYALIAS"       = azurerm_spring_cloud_certificate.gateway_cert.name
#     "SERVER_SSL_KEYSTORETYPE"   = "AzureKeyVault"
#     "SERVER_SSL_TRUSTSTORETYPE" = "AzureKeyVault"
#   }
# }

# resource "azurerm_spring_cloud_java_deployment" "gateway_staging_deployment" {
#   name                = "staging"
#   spring_cloud_app_id = azurerm_spring_cloud_app.spring_gateway.id
#   instance_count      = 1
#   runtime_version     = "Java_17"

#   quota {
#     cpu    = "1"
#     memory = "1Gi"
#   }

#   environment_variables = {

#     # Required for configuring the azure-spring-boot-starter-keyvault-secrets library
#     "AZURE_KEYVAULT_ENABLED"    = "true"
#     "AZURE_KEYVAULT_URI"        = var.vault_uri
#     "SERVER_SSL_KEYALIAS"       = azurerm_spring_cloud_certificate.gateway_cert.name
#     "SERVER_SSL_KEYSTORETYPE"   = "AzureKeyVault"
#     "SERVER_SSL_TRUSTSTORETYPE" = "AzureKeyVault"
#   }
# }

# resource "azurerm_key_vault_certificate" "gateway_cert" {
#   name         = var.gateway_certificate_name
#   key_vault_id = var.vault_id

#   certificate_policy {
#     issuer_parameters {
#       name = "Self"
#     }

#     key_properties {
#       exportable = true
#       key_size   = 2048
#       key_type   = "RSA"
#       reuse_key  = true
#     }

#     lifetime_action {
#       action {
#         action_type = "AutoRenew"
#       }

#       trigger {
#         days_before_expiry = 30
#       }
#     }

#     secret_properties {
#       content_type = "application/x-pkcs12"
#     }

#     x509_certificate_properties {
#       # Server Authentication = 1.3.6.1.5.5.7.3.1
#       # Client Authentication = 1.3.6.1.5.5.7.3.2
#       extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

#       key_usage = [
#         "cRLSign",
#         "dataEncipherment",
#         "digitalSignature",
#         "keyAgreement",
#         "keyCertSign",
#         "keyEncipherment",
#       ]

#       subject_alternative_names {
#         dns_names = ["asa-demo-3132-1959-dev.test.azuremicroservices.io", "asa-demo-3132-1959-dev.azuremicroservices.io"]
#       }

#       subject            = "CN=asa-demo-3132-1959-dev"
#       validity_in_months = 12
#     }
#   }
# }


# resource "azurerm_spring_cloud_certificate" "gateway_cert" {
#   name                     = azurerm_key_vault_certificate.gateway_cert.name
#   resource_group_name      = var.resource_group
#   service_name             = azurerm_spring_cloud_service.application.name
#   key_vault_certificate_id = azurerm_key_vault_certificate.gateway_cert.id
# }
