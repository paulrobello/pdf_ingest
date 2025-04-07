data "azurerm_resource_group" "main" {
  name = "${var.app_name}-${var.stack_env}"
}

data "azurerm_storage_account" "pdf_storage" {
  name                = var.storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_storage_container" "inbox" {
  name                  = "inbox"
  storage_account_id    = data.azurerm_storage_account.pdf_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "outbox" {
  name                  = "outbox"
  storage_account_id    = data.azurerm_storage_account.pdf_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_queue" "ocr_queue" {
  name                 = "ocr-queue"
  storage_account_name = data.azurerm_storage_account.pdf_storage.name
}

# Create Event Grid System Topic with managed identity
resource "azurerm_eventgrid_system_topic" "blob_events" {
  name                   = "blob-events-${var.stack_env}"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = data.azurerm_resource_group.main.location
  source_arm_resource_id = data.azurerm_storage_account.pdf_storage.id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  identity {
    type = "SystemAssigned"
  }
}

# Event subscription to trigger queue messages when new blobs are uploaded to inbox container
resource "azurerm_eventgrid_system_topic_event_subscription" "blob_created" {
  name                = "blob-created-event"
  system_topic        = azurerm_eventgrid_system_topic.blob_events.name
  resource_group_name = data.azurerm_resource_group.main.name
  
  storage_queue_endpoint {
    storage_account_id = data.azurerm_storage_account.pdf_storage.id
    queue_name         = azurerm_storage_queue.ocr_queue.name
  }
  
  included_event_types = ["Microsoft.Storage.BlobCreated"]
  
  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${azurerm_storage_container.inbox.name}/"
  }
}

# Grant permission for Event Grid to write to the queue
resource "azurerm_role_assignment" "eventgrid_queue_contributor" {
  scope                = data.azurerm_storage_account.pdf_storage.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_eventgrid_system_topic.blob_events.identity[0].principal_id
}
