---
agent: 'agent'
description: 'Add a new Azure messaging resource (Service Bus queue/topic, Event Hub, Event Grid subscription, etc.) to an existing Terraform module using AVM.'
tools: ['search', 'web', 'edit']
---

# Add an Azure Messaging Resource

You are extending an existing Terraform module in this repository to add a new Azure messaging resource.  
All resources **must** be configured through [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/).

## Supported Resource Types

Choose the resource type being added and follow the corresponding guidance:

---

### Service Bus (Namespace, Queue, Topic, Subscription)

**AVM module**: `Azure/avm-res-servicebus-namespace/azurerm`

Key configuration to consider:
- `sku` — `Basic`, `Standard`, or `Premium` (Premium required for private endpoints and geo-redundancy)
- `queues` — map of queue objects (name, max size, lock duration, dead-lettering, sessions)
- `topics` — map of topic objects
- `topics[*].subscriptions` — map of subscriptions per topic
- `private_endpoints` — configure for Premium SKU to disable public access
- `network_rule_set` — restrict access by IP or virtual network rules

Naming: `sb-<workload>-<env>` for namespace, queue/topic names as plain lowercase with hyphens.

---

### Event Hub (Namespace, Hub, Consumer Group)

**AVM module**: `Azure/avm-res-eventhub-namespace/azurerm`

Key configuration to consider:
- `sku` — `Basic`, `Standard`, or `Premium`
- `capacity` — throughput units (Standard) or processing units (Premium)
- `auto_inflate_enabled` — for Standard, enables auto-scaling throughput
- `event_hubs` — map of hub objects (partition count, message retention, capture settings)
- `event_hubs[*].consumer_groups` — additional consumer groups per hub
- `private_endpoints` — for Standard/Premium to disable public access
- `network_rulesets` — IP and virtual network rules

Naming: `evhns-<workload>-<env>` for namespace, hub names as plain lowercase with hyphens.

---

### Event Grid (Topic, System Topic, Event Subscription)

**AVM module**: `Azure/avm-res-eventgrid-topic/azurerm` (custom topics)

Key configuration to consider:
- `input_schema` — `EventGridSchema`, `CloudEventSchemaV1_0`, or `CustomEventSchema`
- `event_subscriptions` — map of subscriptions (endpoint type, filter, retry policy)
- `public_network_access_enabled` — set to `false` and use private endpoints
- `inbound_ip_rule` — IP filtering rules

Naming: `evgt-<workload>-<env>` for topics.

---

## Step-by-Step Instructions

1. **Identify the existing module** to extend (search `infra/modules/` in the codebase).

2. **Look up the AVM module** on the [Terraform Registry](https://registry.terraform.io/search/modules?namespace=Azure&query=avm) to confirm the correct input variable names for the requested resource configuration — AVM module interfaces evolve over versions.

3. **Add or update the AVM module call** in `main.tf` with the new resource configuration. Use the module's native sub-resource arguments (e.g., `queues`, `topics`, `event_hubs`) rather than separate AVM module calls for child resources where the parent module supports them.

4. **Add variables** in `variables.tf` for all new configuration points. Follow this pattern:
   ```hcl
   variable "queues" {
     description = "Map of Service Bus queues to create within the namespace. Key is the queue name."
     type = map(object({
       max_size_in_megabytes                    = optional(number, 1024)
       default_message_ttl                      = optional(string, "P14D")
       lock_duration                            = optional(string, "PT1M")
       dead_lettering_on_message_expiration     = optional(bool, false)
       requires_session                         = optional(bool, false)
     }))
     default = {}
   }
   ```

5. **Add outputs** in `outputs.tf` for any new resource IDs or connection-relevant attributes.

6. **Apply security defaults**:
   - Prefer Premium SKU for production workloads (enables private endpoints)
   - Set `public_network_access_enabled = false` on namespaces/topics when private endpoints are used
   - Enable diagnostic settings (send logs and metrics to Log Analytics)
   - For dead-letter queues: enable dead-lettering on filter evaluation exceptions for subscriptions

7. **Tags**: Ensure `tags = var.tags` is passed to all AVM module calls.

---

## Example: Adding a Service Bus Queue to an Existing Namespace Module

```hcl
# In main.tf — extend the existing servicebus module call:
module "servicebus_namespace" {
  source  = "Azure/avm-res-servicebus-namespace/azurerm"
  version = "~> 0.3"

  name                = var.servicebus_namespace_name
  resource_group_name = var.resource_group_name
  location            = var.location

  queues = var.queues   # <-- new

  tags = var.tags
}

# In variables.tf — new variable:
variable "queues" {
  description = "Map of Service Bus queues to create. Key is the queue name (lowercase, hyphens allowed)."
  type = map(object({
    max_size_in_megabytes                = optional(number, 1024)
    default_message_ttl                  = optional(string, "P14D")
    lock_duration                        = optional(string, "PT1M")
    dead_lettering_on_message_expiration = optional(bool, true)
    requires_session                     = optional(bool, false)
  }))
  default = {}
}

# In outputs.tf — new output:
output "queue_ids" {
  description = "Map of queue names to their resource IDs."
  value       = { for k, v in module.servicebus_namespace.queues : k => v.id }
}
```

---

## Request

Add the following Azure messaging resource:

> **Resource type**: [RESOURCE TYPE — e.g., "Service Bus queue", "Event Hub with consumer groups", "Event Grid topic with webhook subscription"]
> **Target module**: [MODULE PATH — e.g., "infra/modules/service-bus-namespace" or "new module"]
> **Configuration requirements**: [SPECIFIC REQUIREMENTS — e.g., "session-enabled queue, 1-minute lock duration, dead-lettering on expiry, Premium SKU with private endpoint"]
> **Environment**: [ENVIRONMENT — e.g., "dev", "prod"]
