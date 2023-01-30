terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.32.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "1.2.22"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  // If an environment is set up (dev, test, prod...), it is used in the application name
  environment = var.environment == "" ? "dev" : var.environment
}

resource "azurecaf_name" "resource_group" {
  name          = var.application_name
  resource_type = "azurerm_resource_group"
  suffixes      = [local.environment]
}

resource "azurerm_resource_group" "main" {
  name     = azurecaf_name.resource_group.result
  location = var.location

  tags = {
    "terraform"        = "true"
    "environment"      = local.environment
    "application-name" = var.application_name
    "nubesgen-version" = "undefined"
  }
}

module "application_server" {
  source           = "./modules/spring-server"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location

  vault_id                 = module.key-vault.vault_id
  vault_uri                = module.key-vault.vault_uri
  app_certificate_name     = "app-cert"
  gateway_certificate_name = "gateway-cert"

  virtual_network_id = module.network.virtual_network_id
  app_subnet_id      = module.network.app_subnet_id
  service_subnet_id  = module.network.service_subnet_id
  cidr_ranges        = var.cidr_ranges
}

module "applications" {
  count              = length(var.applications)
  source             = "./modules/spring-app"
  resource_group     = azurerm_resource_group.main.name
  spring_server_name = module.application_server.spring_cloud_service_name
  application_name   = var.applications[count.index].name
  vault_id           = module.key-vault.vault_id
  vault_uri          = module.key-vault.vault_uri
  certificate_name   = var.applications[count.index].name
  subject_name       = "CN=${module.application_server.spring_cloud_service_name}"
  subject_alternative_names = [
    "${module.application_server.spring_cloud_service_name}.test.azuremicroservices.io",
    "${module.application_server.spring_cloud_service_name}.azuremicroservices.io"
  ]
  tls_enabled = var.applications[count.index].tls_enabled
  is_public   = var.applications[count.index].is_public
}

module "key-vault" {
  source           = "./modules/key-vault"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location
}

module "network" {
  source           = "./modules/virtual-network"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location

  service_endpoints = ["Microsoft.KeyVault"]

  address_space     = var.address_space
  app_subnet_prefix = var.app_subnet_prefix

  service_subnet_prefix    = var.service_subnet_prefix
  jumpbox_subnet_prefix    = var.jumpbox_subnet_prefix
  bastion_subnet_prefix    = var.bastion_subnet_prefix
  appgateway_subnet_prefix = var.appgateway_subnet_prefix
}


module "jumpbox" {
  source           = "./modules/jumpbox"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location

  vm_subnet_id       = module.network.jumpbox_subnet_id
  bastion_subnet_id  = module.network.bastion_subnet_id
  admin_password     = var.jumpbox_admin_password
  aad_admin_username = var.aad_admin_username
  enroll_with_mdm    = true
}

module "appgateway" {
  source           = "./modules/application_gateway"
  resource_group   = azurerm_resource_group.main.name
  application_name = var.application_name
  environment      = local.environment
  location         = var.location

  appgateway_subnet_id = module.network.appgateway_subnet_id
}
