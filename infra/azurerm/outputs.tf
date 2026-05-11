output "resource_group_id" {
  description = "Resource ID of the resource group containing net-new resources."
  value       = module.resource_group.id
}

output "resource_group_name" {
  description = "Name of the resource group containing net-new resources."
  value       = module.resource_group.name
}

output "virtual_network_id" {
  description = "Resource ID of the virtual network in use (newly created or pre-existing)."
  value       = local.vnet_id
}

output "private_endpoint_subnet_id" {
  description = "Resource ID of the subnet hosting private endpoints."
  value       = local.pe_subnet_id
}

output "network_security_group_id" {
  description = "Resource ID of the NSG associated with the PE subnet, or null when NSG is disabled."
  value       = local.nsg_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace receiving diagnostics, or null when not configured."
  value       = local.has_log_analytics ? local.log_analytics_id : null
}

output "event_hub_namespace_id" {
  description = "Resource ID of the deployed Event Hub namespace, or null when not deployed."
  value       = local.deploy_event_hub ? module.event_hub[0].namespace_id : null
}

output "service_bus_namespace_id" {
  description = "Resource ID of the deployed Service Bus namespace, or null when not deployed."
  value       = local.deploy_service_bus ? module.service_bus[0].namespace_id : null
}

output "servicebus_private_dns_zone_id" {
  description = "Resource ID of the `privatelink.servicebus.windows.net` Private DNS zone in use (newly created or pre-existing). Null when no zone is wired up."
  value       = local.has_servicebus_dns_zone ? local.servicebus_dns_zone_id : null
}
