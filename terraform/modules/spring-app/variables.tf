variable "resource_group" {
  type        = string
  description = "The resource group"
}

variable "spring_server_name" {
  type        = string
  description = "The Azure Spring Apps Server Name"
}

variable "application_name" {
  type        = string
  description = "The name of your application"
}

variable "vault_id" {
  type        = string
  description = "The Azure Key Vault ID"
}

variable "vault_uri" {
  type        = string
  description = "The Azure Key Vault URI"
}

variable "certificate_name" {
  type        = string
  description = "The name of the certificate"
}

variable "subject_name" {
  type        = string
  description = "The subject name of the certificate"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "The subject alternative names of the certificate"
}

variable "tls_enabled" {
  type        = bool
  description = "Enable TLS"
}

variable "is_public" {
  type        = bool
  description = "Is the service public"
}
