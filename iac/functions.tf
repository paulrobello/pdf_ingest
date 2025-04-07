resource "azurerm_service_plan" "pdf_functions" {
  name                = "${var.app_name}-plan-${var.stack_env}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# Docker Registry for container images
resource "azurerm_container_registry" "acr" {
  name                = "${replace(var.app_name, "-", "")}registry${var.stack_env}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Function App for Inbox Container (Docker-based)
resource "azurerm_linux_function_app" "inbox_container" {
  name                       = "${var.app_name}-inbox-${var.stack_env}"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.pdf_functions.id
  storage_account_name       = data.azurerm_storage_account.pdf_storage.name
  storage_account_access_key = data.azurerm_storage_account.pdf_storage.primary_access_key

  site_config {
    application_stack {
      docker {
        registry_url      = azurerm_container_registry.acr.login_server
        image_name        = "inbox_container"
        image_tag         = var.inbox_container_image_tag
        registry_username = azurerm_container_registry.acr.admin_username
        registry_password = azurerm_container_registry.acr.admin_password
      }
    }
    
    # Enable file system logging
    app_service_logs {
      disk_quota_mb         = 35
      retention_period_days = 7
    }
    
    # Additional logging configuration
    http2_enabled                  = true
    minimum_tls_version            = "1.2"
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "AzureWebJobsStorage"                   = data.azurerm_storage_account.pdf_storage.primary_connection_string
    "DOCKER_REGISTRY_SERVER_URL"            = "https://${azurerm_container_registry.acr.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME"       = azurerm_container_registry.acr.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD"       = azurerm_container_registry.acr.admin_password
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = "false"
    "STACK_ENV"                             = var.stack_env
    "OUTPUT_BUCKET"                         = data.azurerm_storage_account.pdf_storage.name
    "OUTPUT_CONTAINER"                      = azurerm_storage_container.outbox.name
    "OUTPUT_PREFIX"                         = "outbox"
    "INPUT_BUCKET"                          = data.azurerm_storage_account.pdf_storage.name
    "INPUT_CONTAINER"                       = azurerm_storage_container.inbox.name
    "INPUT_PREFIX"                          = "inbox"
    "STORAGE_CONTAINER_INBOX"               = azurerm_storage_container.inbox.name
    "STORAGE_CONTAINER_OUTBOX"              = azurerm_storage_container.outbox.name
    "MAX_OCR_WORKERS"                       = var.max_ocr_workers
    "AI_PROVIDER"                           = var.ai_provider
    "AI_MODEL"                              = var.ai_model
    "AI_BASE_URL"                           = var.ai_base_url
    "OPENAI_API_KEY"                        = var.openai_api_key
    "AZURE_OPENAI_API_KEY"                  = var.azure_openai_api_key
    "ANTHROPIC_API_KEY"                     = var.anthropic_api_key
    "LANGCHAIN_PROJECT"                     = var.langchain_project
    "LANGCHAIN_TRACING_V2"                  = var.langchain_tracing
    "LANGCHAIN_API_KEY"                     = var.langchain_api_key
    "LANGCHAIN_ENDPOINT"                    = var.langchain_endpoint
    "AZURE_STORAGE_CONNECTION_STRING"       = data.azurerm_storage_account.pdf_storage.primary_connection_string
    "AZURE_QUEUE_STORAGE_CONNECTION_STRING" = data.azurerm_storage_account.pdf_storage.primary_connection_string
    
    # Application Insights settings
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.app_insights.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "FUNCTIONS_EXTENSION_VERSION"           = "~4"
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    
    # Enable detailed logging
    "AzureWebJobsDashboard"                = data.azurerm_storage_account.pdf_storage.primary_connection_string
    "WEBSITE_HTTPLOGGING_RETENTION_DAYS"   = "7"
    "APPINSIGHTS_SAMPLING_PERCENTAGE"      = "100"
    "DIAGNOSTICS_AZUREBLOBRETENTIONINDAYS" = "7"
  }
}


# Function App for Outbox (ZIP package based)
resource "azurerm_linux_function_app" "outbox" {
  name                       = "${var.app_name}-outbox-${var.stack_env}"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.pdf_functions.id
  storage_account_name       = data.azurerm_storage_account.pdf_storage.name
  storage_account_access_key = data.azurerm_storage_account.pdf_storage.primary_access_key

  site_config {
    application_stack {
      python_version = "3.11"
    }
    
    # Enable file system logging
    app_service_logs {
      disk_quota_mb         = 35
      retention_period_days = 7
    }
    
    # Additional logging configuration
    http2_enabled                  = true
    minimum_tls_version            = "1.2"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"    = "python"
    "AzureWebJobsStorage"         = data.azurerm_storage_account.pdf_storage.primary_connection_string
    "STACK_ENV"                   = var.stack_env
    "STORAGE_CONTAINER_INBOX"     = azurerm_storage_container.inbox.name
    "STORAGE_CONTAINER_OUTBOX"    = azurerm_storage_container.outbox.name
    
    # Application Insights settings
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.app_insights.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "FUNCTIONS_EXTENSION_VERSION"           = "~4"
    "WEBSITE_RUN_FROM_PACKAGE"              = "1"
    
    # Enable detailed logging
    "AzureWebJobsDashboard"                = data.azurerm_storage_account.pdf_storage.primary_connection_string
    "WEBSITE_HTTPLOGGING_RETENTION_DAYS"   = "7"
    "APPINSIGHTS_SAMPLING_PERCENTAGE"      = "100"
    "DIAGNOSTICS_AZUREBLOBRETENTIONINDAYS" = "7"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Role assignments for Storage access
resource "azurerm_role_assignment" "inbox_storage_blob_contributor" {
  scope                = data.azurerm_storage_account.pdf_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.inbox_container.identity[0].principal_id
}

resource "azurerm_role_assignment" "inbox_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_function_app.inbox_container.identity[0].principal_id
}

resource "azurerm_role_assignment" "inbox_storage_queue_contributor" {
  scope                = data.azurerm_storage_account.pdf_storage.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_linux_function_app.inbox_container.identity[0].principal_id
}

resource "azurerm_role_assignment" "outbox_storage_blob_contributor" {
  scope                = data.azurerm_storage_account.pdf_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.outbox.identity[0].principal_id
}

# Create a storage container for function deployment artifacts
resource "azurerm_storage_container" "function_deployments" {
  name                 = "function-deployments"
  storage_account_id = data.azurerm_storage_account.pdf_storage.id
  container_access_type = "private"
}

# Upload the function zip to blob storage
resource "azurerm_storage_blob" "outbox_function_zip" {
  name                   = "outbox-function-${formatdate("YYYYMMDDhhmmss", timestamp())}.zip"
  storage_account_name   = data.azurerm_storage_account.pdf_storage.name
  storage_container_name = azurerm_storage_container.function_deployments.name
  type                   = "Block"
  source                 = "../src/lambda_outbox/function.zip"
}

# Generate SAS token for the blob (valid for 1 hour)
data "azurerm_storage_account_sas" "sas" {
  connection_string = data.azurerm_storage_account.pdf_storage.primary_connection_string
  https_only        = true
  
  resource_types {
    service   = false
    container = false
    object    = true
  }
  
  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }
  
  start  = timestamp()
  expiry = timeadd(timestamp(), "1h")
  
  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

# Update the outbox function app settings using a Terraform lifecycle post-create
resource "null_resource" "outbox_function_deploy" {
  depends_on = [azurerm_storage_blob.outbox_function_zip, azurerm_linux_function_app.outbox]

  triggers = {
    blob_url = "https://${data.azurerm_storage_account.pdf_storage.name}.blob.core.windows.net/${azurerm_storage_container.function_deployments.name}/${azurerm_storage_blob.outbox_function_zip.name}${data.azurerm_storage_account_sas.sas.sas}"
  }

  # Use Azure CLI to update the function app settings
  provisioner "local-exec" {
    command = <<EOT
      az functionapp config appsettings set \
        --resource-group ${data.azurerm_resource_group.main.name} \
        --name ${azurerm_linux_function_app.outbox.name} \
        --settings WEBSITE_RUN_FROM_PACKAGE="${self.triggers.blob_url}"
    EOT
  }
}

resource "null_resource" "docker_push" {
  depends_on = [azurerm_container_registry.acr, azurerm_role_assignment.inbox_acr_pull]
  triggers = {
    image_tag = var.inbox_container_image_tag
  }
  provisioner "local-exec" {
    command = <<-EOT
    echo "${azurerm_container_registry.acr.admin_password}" | docker login -u "${azurerm_container_registry.acr.admin_username}" --password-stdin ${azurerm_container_registry.acr.login_server}
    docker image tag "${azurerm_container_registry.acr.login_server}/inbox_container:latest" "${azurerm_container_registry.acr.login_server}/inbox_container:${var.inbox_container_image_tag}"
    docker push "${azurerm_container_registry.acr.login_server}/inbox_container:${var.inbox_container_image_tag}"
    docker push "${azurerm_container_registry.acr.login_server}/inbox_container:latest"
  EOT
  }
}
