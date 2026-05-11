output "id" {
  description = "Resource ID of the private endpoint subnet."
  value       = azurerm_subnet.this.id
}

output "name" {
  description = "Name of the private endpoint subnet."
  value       = azurerm_subnet.this.name
}
