---
mode: 'agent'
description: 'Scaffold a new Terraform module for an Azure resource using the correct Azure Verified Module (AVM).'
tools: ['codebase', 'fetch', 'search']
---

# Create a New AVM-Based Terraform Module

You are creating a new Terraform module for this Azure Messaging Landing Zone repository.  
All modules **must** use [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) — do not write raw `resource` blocks for any Azure resource that has an AVM module.

## Instructions

1. **Identify the correct AVM module** for the requested Azure resource:
   - Search the [Terraform Registry](https://registry.terraform.io/search/modules?namespace=Azure&query=avm) for `Azure/avm-res-<resource-type>`
   - Confirm the module exists and note the latest published version
   - Use the source format: `Azure/avm-res-<provider>-<resource>/azurerm`

2. **Create the module directory** under `infra/modules/<module-name>/` containing:
   - `main.tf` — one or more AVM module calls (no raw resource blocks)
   - `variables.tf` — all input variables with `description`, `type`, and `default` (where sensible)
   - `outputs.tf` — expose key outputs (resource ID, name, and any connection-related attributes) with `description`
   - `README.md` — brief description of the module, its inputs, and outputs

3. **Follow these conventions** in every generated file:

   **`main.tf` template:**
   ```hcl
   module "<resource_name>" {
     source  = "Azure/avm-res-<provider>-<resource>/azurerm"
     version = "~> 0.x"  # pin to the actual latest minor version

     name                = var.<resource>_name
     resource_group_name = var.resource_group_name
     location            = var.location

     tags = var.tags
   }
   ```

   **`variables.tf` template:**
   ```hcl
   variable "resource_group_name" {
     description = "The name of the resource group in which to create the resource."
     type        = string
   }

   variable "location" {
     description = "The Azure region where the resource will be deployed."
     type        = string
   }

   variable "<resource>_name" {
     description = "The name of the <resource>. Must follow naming conventions: <abbreviation>-<workload>-<env>."
     type        = string
   }

   variable "tags" {
     description = "A map of tags to apply to all resources. Must include 'environment', 'workload', and 'managed-by'."
     type        = map(string)
     default     = {}
   }
   ```

   **`outputs.tf` template:**
   ```hcl
   output "<resource>_id" {
     description = "The resource ID of the <resource>."
     value       = module.<resource_name>.resource_id
   }

   output "<resource>_name" {
     description = "The name of the <resource>."
     value       = module.<resource_name>.name
   }
   ```

4. **Apply security defaults** appropriate to the requested resource:
   - Service Bus / Event Hub: disable public network access, enable private endpoint variables
   - Key Vault: enable soft delete and purge protection
   - Storage: enable HTTPS-only, disable shared key access, set minimum TLS 1.2
   - All resources: include diagnostic settings variables pointing to a Log Analytics Workspace

5. **Naming convention reminder** — enforce these patterns in variable descriptions:
   - Service Bus Namespace: `sb-<workload>-<env>`
   - Event Hub Namespace: `evhns-<workload>-<env>`
   - Event Grid Topic: `evgt-<workload>-<env>`
   - Resource Group: `rg-<workload>-<env>`
   - Key Vault: `kv-<workload>-<env>`
   - Private Endpoint: `pep-<resource>-<env>`

## Request

Create a new Terraform module for the following Azure resource:

> **Resource**: [DESCRIBE THE AZURE RESOURCE — e.g., "Azure Service Bus Namespace with queues and topics"]
> **Module name**: [MODULE DIRECTORY NAME — e.g., "service-bus-namespace"]
> **Key configuration requirements**: [LIST ANY SPECIFIC REQUIREMENTS — e.g., "needs dead-lettering, sessions, geo-redundancy"]
