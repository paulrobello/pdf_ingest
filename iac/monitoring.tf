# Create Log Analytics workspace for Application Insights
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "${var.app_name}-logs-${var.stack_env}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_in_days
}

# Azure Application Insights for monitoring
resource "azurerm_application_insights" "app_insights" {
  name                = "${var.app_name}-insights-${var.stack_env}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
}

# Update inbox container function with app insights settings
resource "azurerm_application_insights_web_test" "inbox_availability" {
  name                    = "${var.app_name}-inbox-availability-${var.stack_env}"
  location                = data.azurerm_resource_group.main.location
  resource_group_name     = data.azurerm_resource_group.main.name
  application_insights_id = azurerm_application_insights.app_insights.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 120
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]
  
  configuration = <<XML
<WebTest Name="PDF OCR Inbox Function Availability Check" Enabled="True" Timeout="120" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Items>
    <Request Method="GET" Version="1.1" Url="https://${azurerm_linux_function_app.inbox_container.name}.azurewebsites.net/api/health" ThinkTime="0" Timeout="120" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
XML
}

# Update outbox function app with app insights settings
resource "azurerm_application_insights_web_test" "outbox_availability" {
  name                    = "${var.app_name}-outbox-availability-${var.stack_env}"
  location                = data.azurerm_resource_group.main.location
  resource_group_name     = data.azurerm_resource_group.main.name
  application_insights_id = azurerm_application_insights.app_insights.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 120
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]
  
  configuration = <<XML
<WebTest Name="PDF OCR Outbox Function Availability Check" Enabled="True" Timeout="120" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Items>
    <Request Method="GET" Version="1.1" Url="https://${azurerm_linux_function_app.outbox.name}.azurewebsites.net/api/health" ThinkTime="0" Timeout="120" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" />
  </Items>
</WebTest>
XML
}

# Diagnostic settings for inbox function logs
resource "azurerm_monitor_diagnostic_setting" "inbox_function_logs" {
  name                       = "${var.app_name}-inbox-diag-${var.stack_env}"
  target_resource_id         = azurerm_linux_function_app.inbox_container.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Diagnostic settings for outbox function logs
resource "azurerm_monitor_diagnostic_setting" "outbox_function_logs" {
  name                       = "${var.app_name}-outbox-diag-${var.stack_env}"
  target_resource_id         = azurerm_linux_function_app.outbox.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}