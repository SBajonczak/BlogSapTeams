terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

# ─── Random suffix to ensure globally unique names ───────────────────────────
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  name_suffix = random_string.suffix.result
}

# ─── Resource Group ───────────────────────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# ─── Storage Account (required by Function App runtime) ──────────────────────
resource "azurerm_storage_account" "sa" {
  name                     = "${var.prefix}sa${local.name_suffix}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ─── App Service Plan (Linux, Consumption) ───────────────────────────────────
resource "azurerm_service_plan" "plan" {
  name                = "${var.prefix}-plan-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan
}

# ─── Linux Function App (Node.js 18) ─────────────────────────────────────────
resource "azurerm_linux_function_app" "func" {
  name                       = "${var.prefix}-func-${local.name_suffix}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key

  site_config {
    application_stack {
      node_version = "18"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "node"
    WEBSITE_NODE_DEFAULT_VERSION   = "~18"
    TEAMS_WEBHOOK_URL              = var.teams_webhook_url
    AzureWebJobsStorage            = azurerm_storage_account.sa.primary_connection_string
    WEBSITE_RUN_FROM_PACKAGE       = "1"
  }
}

# ─── Event Grid Topic ─────────────────────────────────────────────────────────
resource "azurerm_eventgrid_topic" "topic" {
  name                = "${var.prefix}-topic-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# ─── Event Grid Subscription → Function App ──────────────────────────────────
resource "azurerm_eventgrid_event_subscription" "sub" {
  name  = "func-order-created-sub"
  scope = azurerm_eventgrid_topic.topic.id

  webhook_endpoint {
    url = "https://${azurerm_linux_function_app.func.default_hostname}/runtime/webhooks/eventgrid?functionName=OrderCreated"
  }

  included_event_types = ["OrderCreated"]

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }

  depends_on = [azurerm_linux_function_app.func]
}
