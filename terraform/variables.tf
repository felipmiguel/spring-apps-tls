variable "application_name" {
  type        = string
  description = "The name of your application"
  default     = "springdemo"
}

variable "environment" {
  type        = string
  description = "The environment (dev, test, prod...)"
  default     = ""
}

variable "location" {
  type        = string
  description = "The Azure region where all resources in this example should be created"
  default     = "eastus"
}

variable "address_space" {
  type        = string
  description = "Virtual Network address space"
  default     = "10.11.0.0/16"
}

variable "app_subnet_prefix" {
  type        = string
  description = "Application subnet prefix"
  default     = "10.11.0.0/24"
}

variable "service_subnet_prefix" {
  type        = string
  description = "Azure Spring Apps service subnet prefix"
  default     = "10.11.1.0/24"
}

variable "jumpbox_subnet_prefix" {
  type        = string
  description = "Jumpbox subnet prefix"
  default     = "10.11.5.0/24"
}

variable "bastion_subnet_prefix" {
  type        = string
  description = "Bastion subnet prefix"
  default     = "10.11.6.0/24"
}

variable "appgateway_subnet_prefix" {
  type        = string
  description = "Application Gateway subnet prefix"
  default     = "10.11.7.0/24"
}

variable "cidr_ranges" {
  type        = list(string)
  description = "A list of (at least 3) CIDR ranges (at least /16) which are used to host the Azure Spring Apps infrastructure, which must not overlap with any existing CIDR ranges in the Subnet. Changing this forces a new resource to be created"
  default     = ["10.4.0.0/16", "10.5.0.0/16", "10.3.0.1/16"]
}

variable "jumpbox_admin_password" {
  type      = string
  sensitive = true
}

variable "aad_admin_username" {
  type        = string
  description = "The username for the administrator account of the virtual machine."
}

variable "applications" {
  type = list(object({
    name                      = string
    tls_enabled               = bool
    is_public                 = bool
  }))
  description = "The list of applications to deploy"
  default     = [ {
    name                      = "demoapi"
    tls_enabled               = true
    is_public                 = false
  }, {
    name                      = "api-gateway"
    tls_enabled               = true
    is_public                 = true
  } , {
    name                      = "admin-app"
    tls_enabled               = true
    is_public                 = true
  }]
}
