terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend configuration is supplied at `terraform init` time via
  # `-backend-config=...` flags from the GitHub Actions workflow so that the
  # same root module can be initialized against multiple environments.
  backend "azurerm" {
    use_azuread_auth = true
  }
}
