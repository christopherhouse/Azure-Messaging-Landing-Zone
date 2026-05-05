# GitHub Copilot Instructions — Azure Messaging Landing Zone

## Repository Overview

This repository contains Terraform templates to deploy a landing zone for Azure Messaging services, including **Azure Service Bus**, **Azure Event Hub**, and **Azure Event Grid**.  All infrastructure is managed exclusively through Terraform using **Azure Verified Modules (AVM)**.

---

## Terraform Standards

### Azure Verified Modules (AVM) — MANDATORY

All Terraform resource declarations **must** use [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/).  
Do **not** write raw `resource` blocks for Azure resources that have a corresponding AVM module — always use the module instead.

- AVM resource modules follow the naming pattern: `Azure/avm-res-<provider>-<resource>/azurerm`
- AVM pattern modules follow the naming pattern: `Azure/avm-ptn-<pattern>/azurerm`
- Source modules from the public Terraform Registry: `registry.terraform.io`
- Always pin to a version constraint using the pessimistic operator: `version = "~> 0.x"`
- Verify the exact latest version on the [Terraform Registry](https://registry.terraform.io/search/modules?namespace=Azure&query=avm) before pinning

**Common AVM modules used in this repository:**

| Azure Resource | AVM Module Source |
|---|---|
| Service Bus Namespace | `Azure/avm-res-servicebus-namespace/azurerm` |
| Event Hub Namespace | `Azure/avm-res-eventhub-namespace/azurerm` |
| Event Grid Topic | `Azure/avm-res-eventgrid-topic/azurerm` |
| Event Grid System Topic | `Azure/avm-res-eventgrid-systemtopic/azurerm` |
| Resource Group | `Azure/avm-res-resources-resourcegroup/azurerm` |
| Key Vault | `Azure/avm-res-keyvault-vault/azurerm` |
| Virtual Network | `Azure/avm-res-network-virtualnetwork/azurerm` |
| Private Endpoint | `Azure/avm-res-network-privateendpoint/azurerm` |
| Storage Account | `Azure/avm-res-storage-storageaccount/azurerm` |
| Log Analytics Workspace | `Azure/avm-res-operationalinsights-workspace/azurerm` |

**Example AVM module invocation:**

```hcl
module "servicebus_namespace" {
  source  = "Azure/avm-res-servicebus-namespace/azurerm"
  version = "~> 0.3"

  name                = var.servicebus_namespace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location

  tags = local.tags
}
```

### Terraform Backend — Entra ID Authentication (MANDATORY)

The Terraform backend **must** use Azure Storage with Entra ID (Azure AD) authentication.  
Do **not** use storage account access keys or SAS tokens for backend authentication.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "messaging-landing-zone.tfstate"
    use_azuread_auth     = true
  }
}
```

### Provider Configuration

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.9"
}

provider "azurerm" {
  features {}
  use_oidc = true  # OIDC authentication for CI/CD
}
```

### Module and Directory Structure

```
infra/
  modules/
    <resource-name>/
      main.tf        # Module resources (AVM module calls only)
      variables.tf   # Input variables with descriptions and types
      outputs.tf     # Output values
      README.md      # Module documentation
  environments/
    dev/
      main.tf
      variables.tf
      terraform.tfvars.example
    prod/
      main.tf
      variables.tf
      terraform.tfvars.example
```

### Variable and Output Conventions

- Every variable **must** have a `description` and explicit `type`
- Every output **must** have a `description`
- Group related variables with comments
- Use `sensitive = true` on outputs that expose secret values

---

## GitHub Actions Standards

### Entra ID / OIDC Authentication — MANDATORY

GitHub Actions workflows **must** authenticate to Azure using **OIDC Workload Identity Federation** (Entra ID).  
Do **not** use service principal client secrets, storage account access keys, or any long-lived credentials.

**Required workflow-level permissions:**

```yaml
permissions:
  id-token: write   # Required for OIDC token issuance
  contents: read
  pull-requests: write  # Only if the workflow comments on PRs
```

**Azure login step:**

```yaml
- name: Azure Login
  uses: azure/login@v2
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

**Terraform environment variables for OIDC:**

```yaml
env:
  ARM_USE_OIDC: "true"
  ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### GitHub Variables (not Secrets) for Azure Identity

Use **GitHub Variables** (`vars.*`) — not Secrets — for Azure identity values that are not sensitive:

| Variable | Description |
|---|---|
| `AZURE_CLIENT_ID` | App registration or managed identity client ID |
| `AZURE_TENANT_ID` | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `TF_BACKEND_RESOURCE_GROUP` | Terraform state resource group name |
| `TF_BACKEND_STORAGE_ACCOUNT` | Terraform state storage account name |
| `TF_BACKEND_CONTAINER` | Terraform state blob container name |

### Standard Terraform Workflow Job Pattern

```yaml
jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.9"

      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="resource_group_name=${{ vars.TF_BACKEND_RESOURCE_GROUP }}" \
            -backend-config="storage_account_name=${{ vars.TF_BACKEND_STORAGE_ACCOUNT }}" \
            -backend-config="container_name=${{ vars.TF_BACKEND_CONTAINER }}" \
            -backend-config="key=${{ env.TF_STATE_KEY }}" \
            -backend-config="use_azuread_auth=true"
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

---

## Naming Conventions

Follow [Azure Resource Abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations):

| Resource Type | Pattern | Example |
|---|---|---|
| Resource Group | `rg-<workload>-<env>` | `rg-messaging-dev` |
| Service Bus Namespace | `sb-<workload>-<env>` | `sb-messaging-dev` |
| Event Hub Namespace | `evhns-<workload>-<env>` | `evhns-messaging-dev` |
| Event Grid Topic | `evgt-<workload>-<env>` | `evgt-messaging-dev` |
| Storage Account | `st<workload><env>` | `stmessagingdev` |
| Key Vault | `kv-<workload>-<env>` | `kv-messaging-dev` |
| Virtual Network | `vnet-<workload>-<env>` | `vnet-messaging-dev` |
| Private Endpoint | `pep-<resource>-<env>` | `pep-sb-messaging-dev` |
| Log Analytics Workspace | `log-<workload>-<env>` | `log-messaging-dev` |

---

## Security Requirements

- **Private Endpoints**: Enable private endpoints for all messaging resources (Service Bus, Event Hub, Event Grid)
- **Public Network Access**: Disable public network access on resources unless explicitly required
- **Managed Identities**: Use managed identities for resource-to-resource authentication; avoid connection strings where possible
- **Key Vault**: Store all secrets and connection strings in Azure Key Vault — never in Terraform state, `.tfvars` files, or code
- **Diagnostic Settings**: Enable diagnostic settings on all resources, sending logs and metrics to a Log Analytics Workspace
- **Tags**: All resources **must** include at minimum these tags:
  ```hcl
  tags = {
    environment = var.environment   # e.g., "dev", "staging", "prod"
    workload    = var.workload_name # e.g., "messaging"
    managed-by  = "terraform"
  }
  ```
