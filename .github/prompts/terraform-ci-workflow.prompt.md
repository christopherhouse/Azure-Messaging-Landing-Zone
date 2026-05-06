---
agent: 'agent'
description: 'Create a GitHub Actions workflow for Terraform with Entra ID OIDC authentication — no service principal secrets.'
tools: ['search', 'web', 'edit']
---

# Create a Terraform GitHub Actions Workflow (Entra ID OIDC)

You are creating a GitHub Actions workflow for this Azure Messaging Landing Zone repository.

## Non-Negotiable Requirements

- **Authentication**: Use Entra ID OIDC Workload Identity Federation via `azure/login@v2`. Do **not** use service principal client secrets, storage account access keys, or any long-lived credentials.
- **Permissions**: Always declare `permissions: id-token: write` at workflow or job level.
- **Variables vs Secrets**: Azure identity values (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) are **not sensitive** — store them as GitHub **Variables** (`vars.*`), not secrets.
- **Terraform state**: The backend `use_azuread_auth = true` must be passed via `-backend-config` at `terraform init`; access is granted through the OIDC session, not keys.
- **Terraform version**: Use `hashicorp/setup-terraform@v3` with `terraform_version: "~> 1.9"`.
- **Apply gate**: Only run `terraform apply` on pushes to `main`; all other triggers only run plan.

## Workflow Template

Use this as the base template and customise it for the requested scenario:

```yaml
name: <WORKFLOW NAME>

on:
  push:
    branches:
      - main
    paths:
      - 'infra/**'
      - '.github/workflows/<workflow-file>.yml'
  pull_request:
    branches:
      - main
    paths:
      - 'infra/**'

permissions:
  id-token: write   # Required for OIDC
  contents: read
  pull-requests: write  # Remove if not commenting on PRs

env:
  TF_WORKING_DIR: infra/environments/<environment>
  TF_STATE_KEY: <environment>.tfstate

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    environment: <environment>  # GitHub environment for approval gates (optional)

    defaults:
      run:
        working-directory: ${{ env.TF_WORKING_DIR }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

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
        id: plan
        run: terraform plan -out=tfplan -no-color
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Comment Plan on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan 📖
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\``;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      - name: Upload Plan
        if: github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: ${{ env.TF_WORKING_DIR }}/tfplan
          retention-days: 1

  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    needs: terraform-plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: <environment>

    defaults:
      run:
        working-directory: ${{ env.TF_WORKING_DIR }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

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

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan
          path: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

## Required GitHub Configuration

After generating the workflow, remind the user to configure these in GitHub repository settings:

**GitHub Variables** (Settings → Secrets and Variables → Variables):
- `AZURE_CLIENT_ID` — Client ID of the Entra app registration or user-assigned managed identity
- `AZURE_TENANT_ID` — Entra tenant ID
- `AZURE_SUBSCRIPTION_ID` — Target Azure subscription ID
- `TF_BACKEND_RESOURCE_GROUP` — Resource group holding the Terraform state storage account
- `TF_BACKEND_STORAGE_ACCOUNT` — Storage account name for Terraform state
- `TF_BACKEND_CONTAINER` — Blob container name for Terraform state

**Azure side** (one-time admin setup):
1. Create an Entra app registration or user-assigned managed identity
2. Add a federated credential for GitHub Actions (repo + branch or environment)
3. Grant the identity `Storage Blob Data Contributor` on the state storage account
4. Grant the identity `Contributor` (or custom role) on the target subscription/resource group

## Request

Generate a GitHub Actions Terraform workflow for the following scenario:

> **Workflow purpose**: [DESCRIBE — e.g., "Deploy the dev environment messaging landing zone"]
> **Terraform working directory**: [PATH — e.g., "infra/environments/dev"]
> **State file key**: [KEY — e.g., "messaging-dev.tfstate"]
> **Trigger**: [DESCRIBE — e.g., "PR to main + push to main"]
> **Environments/approvals needed**: [YES/NO and details]
