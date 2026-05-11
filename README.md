# 📨 Azure Messaging Landing Zone

> Terraform templates to deploy a production-ready landing zone for Azure Messaging services, including **Azure Service Bus**, **Azure Event Hub**, and **Azure Event Grid**.
>
> Two parallel implementations live side-by-side:
>
> - [`infra/azurerm/`](infra/azurerm) — **active** implementation using raw `azurerm_*` resources. Deployed by CI/CD.
> - [`infra/avm/`](infra/avm) — **obsolete** implementation using [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/). Retained for reference; not deployed.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.9-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![OIDC](https://img.shields.io/badge/Auth-OIDC%20%2F%20Entra%20ID-00B4D8?logo=microsoft&logoColor=white)](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)

---

## 🗂️ Repository Layout

```
infra/
  azurerm/                # Active root module — raw azurerm resources
    main.tf
    providers.tf
    versions.tf           # Backend + provider version pinning
    variables.tf
    outputs.tf
    data.tf
    locals.tf
    dev.tfvars
    terraform.tfvars.example
  avm/                    # Obsolete root module — Azure Verified Modules (kept for reference)
    main.tf
    ...
.github/
  workflows/
    terraform-dev.yml     # CI/CD for the dev environment (targets infra/azurerm)
  prompts/                # GitHub Copilot prompt files
  copilot-instructions.md
```

## 💻 Local Development

1. Install [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.9` and the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
2. Sign in: `az login` and `az account set --subscription <subscription-id>`.
3. Copy [infra/azurerm/terraform.tfvars.example](infra/azurerm/terraform.tfvars.example) to `infra/azurerm/dev.tfvars` (or `terraform.tfvars`) and fill in values.
4. From the `infra/azurerm/` directory:
   ```pwsh
   terraform init `
     -backend-config="resource_group_name=<state-rg>" `
     -backend-config="storage_account_name=<state-sa>" `
     -backend-config="container_name=tfstate" `
     -backend-config="key=messaging-dev.tfstate" `
     -backend-config="use_azuread_auth=true"

   terraform plan -var-file="dev.tfvars"
   terraform apply -var-file="dev.tfvars"
   ```

The backend uses `use_azuread_auth = true`, so Terraform authenticates to the state storage account with your `az login` identity — no storage account access keys are required.

---

## 🚀 CI/CD: GitHub Actions Workflow

The [terraform-dev.yml](.github/workflows/terraform-dev.yml) workflow plans and applies the `dev` environment using **Entra ID OIDC Workload Identity Federation** — no client secrets or storage account keys are stored in GitHub.

**Triggers:**
- **Pull request** to `main` (paths under `infra/azurerm/**`) → runs `fmt`, `validate`, `plan`, and posts the plan as a PR comment.
- **Push** to `main` (paths under `infra/azurerm/**`) → runs plan, then `apply` (gated by the `dev` GitHub environment).

### 🔧 One-Time Setup

#### ☁️ 1. Provision the Terraform state storage account

In a subscription/resource group of your choice:

```pwsh
az group create --name rg-tfstate-messaging --location eastus2

az storage account create `
  --name <unique-state-sa-name> `
  --resource-group rg-tfstate-messaging `
  --location eastus2 `
  --sku Standard_LRS `
  --kind StorageV2 `
  --allow-shared-key-access false `
  --min-tls-version TLS1_2

az storage container create `
  --name tfstate `
  --account-name <unique-state-sa-name> `
  --auth-mode login
```

> `--allow-shared-key-access false` ensures only Entra ID identities (not access keys) can read/write state.

#### 🪪 2. Create the Entra workload identity for GitHub Actions

Either an **App Registration** or a **User-Assigned Managed Identity** works. Example with an app registration:

```pwsh
$app = az ad app create --display-name "gh-messaging-landing-zone" | ConvertFrom-Json
$sp  = az ad sp create --id $app.appId | ConvertFrom-Json
```

Add a **federated credential** scoped to the `dev` environment in this repo. PowerShell strips inner quotes when JSON is passed inline to `az`, so write the parameters to a temp file and use `@file` syntax:

```pwsh
$repo = "<github-org>/Azure-Messaging-Landing-Zone"

$fic = @{
  name        = "github-dev-environment"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "repo:${repo}:environment:dev"
  description = "GitHub Actions - dev environment"
  audiences   = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress

$ficFile = New-TemporaryFile
Set-Content -Path $ficFile -Value $fic -Encoding utf8

az ad app federated-credential create `
  --id $app.appId `
  --parameters "@$ficFile"

Remove-Item $ficFile
```

> Add additional federated credentials for `pull_request` and `ref:refs/heads/main` if you want plan jobs to authenticate without going through the `dev` environment gate. Subjects: `repo:<org>/<repo>:pull_request` and `repo:<org>/<repo>:ref:refs/heads/main`.

#### 🔐 3. Grant Azure RBAC

The identity needs **two** role assignments:

| Scope | Role | Why |
|---|---|---|
| The state storage account | `Storage Blob Data Contributor` | Read/write Terraform state without access keys |
| Target subscription (or resource group) | `Contributor` (or a least-privilege custom role) | Create the messaging landing zone resources |

```pwsh
$subId       = az account show --query id -o tsv
$saId        = az storage account show -n <unique-state-sa-name> -g rg-tfstate-messaging --query id -o tsv
$principalId = $sp.id

az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal `
  --role "Storage Blob Data Contributor" --scope $saId

az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal `
  --role "Contributor" --scope "/subscriptions/$subId"
```

#### ⚙️ 4. Configure the GitHub repository

**Settings → Environments → New environment → `dev`**
- (Recommended) add required reviewers so `terraform apply` requires manual approval.

**Settings → Secrets and variables → Actions → Variables** (use Variables, not Secrets — these IDs are not sensitive):

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | Application (client) ID of the app registration / managed identity |
| `AZURE_TENANT_ID` | Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |
| `TF_BACKEND_RESOURCE_GROUP` | Resource group of the state storage account (e.g. `rg-tfstate-messaging`) |
| `TF_BACKEND_STORAGE_ACCOUNT` | State storage account name |
| `TF_BACKEND_CONTAINER` | `tfstate` |
| `TF_BACKEND_KEY` | State blob name (e.g. `messaging-dev.tfstate`) |

#### 📄 5. Provide the dev tfvars file

Commit a non-secret `infra/dev.tfvars` (or rename your existing tfvars) so the workflow can pass it via `-var-file`. Use [infra/terraform.tfvars.example](infra/terraform.tfvars.example) as the template. Never put secrets in tfvars — store them in Key Vault and reference them from Terraform.

### ✅ Verify

Open a PR that touches anything under `infra/`. The workflow should:
1. Authenticate to Azure via OIDC.
2. Run `terraform fmt -check`, `init`, `validate`, and `plan`.
3. Comment the plan on your PR.

After merging to `main`, the `terraform-apply` job runs (subject to the `dev` environment approval gate, if configured).

---

## 📐 Standards

See [.github/copilot-instructions.md](.github/copilot-instructions.md) for the full Terraform, AVM, naming, security, and GitHub Actions standards enforced in this repository.

---

## ⚠️ Disclaimer

THIS CODE SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.

This sample is not supported under any Microsoft standard support program or service. The sample is provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties, including, without limitation, any implied warranties of merchantability or fitness for a particular purpose.

The entire risk arising out of the use or performance of the sample and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the sample be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample or documentation, even if Microsoft has been advised of the possibility of such damages.

---
