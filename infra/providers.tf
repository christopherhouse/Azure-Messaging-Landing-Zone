provider "azurerm" {
  features {}

  # OIDC / Workload Identity Federation is used in CI; locally the provider
  # falls back to whatever credentials `az login` produced.
  use_oidc = true
}
