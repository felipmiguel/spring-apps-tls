# Azure Spring Apps is not yet supported in azurecaf_name
locals {
  spring_cloud_service_name = "asa-${var.application_name}-${var.environment}"
  spring_cloud_app_name     = "app-${var.application_name}"

  # Azure Spring Apps Resource Provider object id. It is a constant and it is required to manage the VNET.
  azure_spring_apps_provisioner_object_id = "d2531223-68f9-459e-b225-5592f90d145e"
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
}

# This creates the application definition
resource "azurerm_spring_cloud_app" "application" {
  name                = local.spring_cloud_app_name
  resource_group_name = var.resource_group
  service_name        = azurerm_spring_cloud_service.application.name
  identity {
    type = "SystemAssigned"
  }

  tls_enabled = true
}

# This creates the application deployment. Terraform provider doesn't support dotnet yet
resource "azurerm_spring_cloud_java_deployment" "application_deployment" {
  name                = "default"
  spring_cloud_app_id = azurerm_spring_cloud_app.application.id
  instance_count      = 1
  runtime_version     = "Java_17"

  quota {
    cpu    = "1"
    memory = "1Gi"
  }

  environment_variables = {
    "SPRING_PROFILES_ACTIVE" = "prod,azure"

    # Required for configuring the azure-spring-boot-starter-keyvault-secrets library
    "AZURE_KEYVAULT_ENABLED" = "true"
    "AZURE_KEYVAULT_URI"     = var.vault_uri
  }
}

resource "azurerm_spring_cloud_java_deployment" "staging_deployment" {
  name                = "staging"
  spring_cloud_app_id = azurerm_spring_cloud_app.application.id
  instance_count      = 1
  runtime_version     = "Java_17"

  quota {
    cpu    = "1"
    memory = "1Gi"
  }

  environment_variables = {
    "SPRING_PROFILES_ACTIVE" = "staging,azure"

    # Required for configuring the azure-spring-boot-starter-keyvault-secrets library
    "AZURE_KEYVAULT_ENABLED" = "true"
    "AZURE_KEYVAULT_URI"     = var.vault_uri
  }


}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "application" {
  key_vault_id = var.vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_spring_cloud_app.application.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]
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

resource "azurerm_key_vault_certificate" "tls_self_cert" {
  name         = "tls-self-cert"
  key_vault_id = var.vault_id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject_alternative_names {
        dns_names = ["internal.contoso.com", "domain.hello.world"]
      }

      subject            = "CN=hello-world"
      validity_in_months = 12
    }
  }
}


resource "azurerm_spring_cloud_certificate" "tls_self_cert" {
  name                     = azurerm_key_vault_certificate.tls_self_cert.name
  resource_group_name      = var.resource_group
  service_name             = azurerm_spring_cloud_service.application.name
  key_vault_certificate_id = azurerm_key_vault_certificate.tls_self_cert.id
}
