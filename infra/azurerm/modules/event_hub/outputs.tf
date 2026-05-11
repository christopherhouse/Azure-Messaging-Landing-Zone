output "namespace_id" {
  description = "Resource ID of the Event Hub namespace."
  value       = azurerm_eventhub_namespace.this.id
}

output "namespace_name" {
  description = "Name of the Event Hub namespace."
  value       = azurerm_eventhub_namespace.this.name
}

output "private_endpoint_id" {
  description = "Resource ID of the namespace's private endpoint."
  value       = azurerm_private_endpoint.this.id
}
