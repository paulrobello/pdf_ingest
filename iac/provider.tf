terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "pdf-ingest-dev"
    storage_account_name = "pdfingestdev"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {
  }
  # client_id       = "00000000-0000-0000-0000-000000000000"
  # client_secret   = var.client_secret
  # tenant_id       = "10000000-0000-0000-0000-000000000000"
  # subscription_id = "20000000-0000-0000-0000-000000000000"

}
