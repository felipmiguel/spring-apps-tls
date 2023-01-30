# This creates the application definition
resource "azurerm_spring_cloud_app" "application" {
  name                = var.application_name
  resource_group_name = var.resource_group
  service_name        = var.spring_server_name
  identity {
    type = "SystemAssigned"
  }

  tls_enabled = var.tls_enabled
  is_public   = var.is_public
  https_only  = true
}

# This creates the application deployment. Terraform provider doesn't support dotnet yet
resource "azurerm_spring_cloud_java_deployment" "app_default_deployment" {
  name                = "default"
  spring_cloud_app_id = azurerm_spring_cloud_app.application.id
  instance_count      = 1
  runtime_version     = "Java_17"

  quota {
    cpu    = "1"
    memory = "1Gi"
  }

  environment_variables = {

    # Required for configuring the azure-spring-boot-starter-keyvault-secrets library
    "AZURE_KEYVAULT_ENABLED"    = "true"
    "AZURE_KEYVAULT_URI"        = var.vault_uri
    "SERVER_SSL_KEYALIAS"       = azurerm_spring_cloud_certificate.app_cert.name
    "SERVER_SSL_KEYSTORETYPE"   = "AzureKeyVault"
    "SERVER_SSL_TRUSTSTORETYPE" = "AzureKeyVault"
  }
}

resource "azurerm_spring_cloud_java_deployment" "app_staging_deployment" {
  name                = "staging"
  spring_cloud_app_id = azurerm_spring_cloud_app.application.id
  instance_count      = 1
  runtime_version     = "Java_17"

  quota {
    cpu    = "1"
    memory = "1Gi"
  }

  environment_variables = {

    # Required for configuring the azure-spring-boot-starter-keyvault-secrets library
    "AZURE_KEYVAULT_ENABLED"    = "true"
    "AZURE_KEYVAULT_URI"        = var.vault_uri
    "SERVER_SSL_KEYALIAS"       = azurerm_spring_cloud_certificate.app_cert.name
    "SERVER_SSL_KEYSTORETYPE"   = "AzureKeyVault"
    "SERVER_SSL_TRUSTSTORETYPE" = "AzureKeyVault"
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


resource "azurerm_key_vault_certificate" "app_cert" {
  name         = var.certificate_name
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
        dns_names = var.subject_alternative_names
      }

      subject            = var.subject_name
      validity_in_months = 12
    }
  }
}


resource "azurerm_spring_cloud_certificate" "app_cert" {
  name                     = azurerm_key_vault_certificate.app_cert.name
  resource_group_name      = var.resource_group
  service_name             = var.spring_server_name
  key_vault_certificate_id = azurerm_key_vault_certificate.app_cert.id
}
