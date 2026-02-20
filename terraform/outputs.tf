output "resource_group_name" {
  description = "Name of the created resource group."
  value       = azurerm_resource_group.rg.name
}

output "function_app_name" {
  description = "Name of the Azure Function App."
  value       = azurerm_linux_function_app.func.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Azure Function App."
  value       = azurerm_linux_function_app.func.default_hostname
}

output "event_grid_topic_endpoint" {
  description = "Endpoint URL of the Event Grid topic."
  value       = azurerm_eventgrid_topic.topic.endpoint
}

output "event_grid_topic_key" {
  description = "Primary access key of the Event Grid topic."
  value       = azurerm_eventgrid_topic.topic.primary_access_key
  sensitive   = true
}

output "event_grid_topic_id" {
  description = "Resource ID of the Event Grid topic."
  value       = azurerm_eventgrid_topic.topic.id
}
