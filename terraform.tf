terraform {
  required_version = ">= 1.11.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.9"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.8"
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  use_cli = false

  skip_provider_registration = false
}

provider "vault" {
  address   = var.vault_address
  namespace = var.vault_namespace
}
