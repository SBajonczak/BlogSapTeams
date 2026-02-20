variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
  default     = "rg-sap-eventgrid-demo"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "prefix" {
  description = "Short prefix used to name resources (lowercase, no special chars)."
  type        = string
  default     = "sapeg"
}

variable "teams_webhook_url" {
  description = "Incoming webhook URL for the Microsoft Teams channel."
  type        = string
  sensitive   = true
}
