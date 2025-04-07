"""Start OCR from Azure Blob Storage events."""

import json
import logging
import os
import time
import uuid

import azure.functions as func
from ai_ocr.__main__ import ocr_main
from azure.storage.blob import BlobServiceClient
from par_ai_core.llm_providers import LlmProvider

# Configure logger with Application Insights integration
logger = logging.getLogger("azure")
logger.setLevel(logging.INFO)


# Add correlation IDs for tracing in Application Insights
def get_correlation_id() -> str:
    """Generate a unique correlation ID for request tracing."""
    return str(uuid.uuid4())


# Get the Azure Storage connection string
connection_string = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
blob_service_client = BlobServiceClient.from_connection_string(connection_string)


def process_document(request_id: str, container_name: str, blob_name: str) -> None:
    """
    Process a document using vision model.

    Args:
        request_id (str): The ID of the request.
        container_name (str): The storage container name.
        blob_name (str): The blob name of the document to process.
    """
    correlation_id = get_correlation_id()
    ocr_start_time = time.time()

    ai_provider = os.environ.get("AI_PROVIDER", "OpenAI")
    ai_model = os.environ.get("AI_MODEL", "")
    max_workers = int(os.environ.get("MAX_OCR_WORKERS", 0))
    output_container = os.environ.get("OUTPUT_CONTAINER", "outbox")
    output_key = os.environ.get("OUTPUT_KEY", f"outbox/{request_id}")

    logger.info(
        f"[{correlation_id}] Starting OCR id {request_id} for blob: {container_name}/{blob_name}",
        extra={
            "custom_dimensions": {
                "correlation_id": correlation_id,
                "request_id": request_id,
                "container_name": container_name,
                "blob_name": blob_name,
                "ai_provider": ai_provider,
                "ai_model": ai_model,
                "max_workers": max_workers,
                "output_container": output_container,
                "output_key": output_key,
                "event_type": "ocr_start",
            }
        },
    )

    provider = LlmProvider(ai_provider)

    try:
        ocr_main(
            max_workers=max_workers,
            ai_provider=provider,
            model=ai_model,
            ai_base_url=os.environ.get("AI_BASE_URL") or None,
            input_bucket=container_name,
            input_key=blob_name,
            output_bucket=output_container,
            output_key=output_key,
            request_id=request_id,
        )

        ocr_execution_time = time.time() - ocr_start_time
        logger.info(
            f"[{correlation_id}] Completed OCR id {request_id} for blob: {container_name}/{blob_name}. Duration: {ocr_execution_time:.2f}s",
            extra={
                "custom_dimensions": {
                    "correlation_id": correlation_id,
                    "request_id": request_id,
                    "container_name": container_name,
                    "blob_name": blob_name,
                    "ai_provider": ai_provider,
                    "ai_model": ai_model,
                    "execution_time_seconds": ocr_execution_time,
                    "event_type": "ocr_complete",
                }
            },
        )
    except Exception as e:
        ocr_execution_time = time.time() - ocr_start_time
        logger.error(
            f"[{correlation_id}] OCR processing failed for id {request_id}: {str(e)}",
            extra={
                "custom_dimensions": {
                    "correlation_id": correlation_id,
                    "request_id": request_id,
                    "container_name": container_name,
                    "blob_name": blob_name,
                    "ai_provider": ai_provider,
                    "ai_model": ai_model,
                    "error_message": str(e),
                    "execution_time_seconds": ocr_execution_time,
                    "event_type": "ocr_error",
                }
            },
        )
        raise


def main(message: func.QueueMessage) -> None:
    """
    Process Azure Queue Storage messages triggered by blob uploads to the /inbox container.

    This is the entry point for Azure Functions with Queue trigger.

    Args:
        message: The queue message containing blob information from Event Grid.
    """
    correlation_id = get_correlation_id()
    start_time = time.time()

    logger.info(
        f"[{correlation_id}] Function invoked",
        extra={
            "custom_dimensions": {
                "correlation_id": correlation_id,
                "function_name": "inbox_container_main",
                "event_type": "function_start",
            }
        },
    )

    try:
        # Parse the queue message
        message_body = message.get_body().decode("utf-8")
        data = json.loads(message_body)

        logger.info(
            f"[{correlation_id}] Received message: {json.dumps(data)[:500]}",
            extra={
                "custom_dimensions": {
                    "correlation_id": correlation_id,
                    "message_type": "queue_trigger",
                    "message_preview": json.dumps(data)[:500],
                }
            },
        )

        # Handle EventGrid message format
        if "data" in data and "url" in data.get("data", {}):
            # This is an EventGrid event
            blob_url = data["data"]["url"]
            # Extract container and blob name from the URL
            # Format: https://<storage-account>.blob.core.windows.net/<container>/<blob>
            url_parts = blob_url.split("/")
            if len(url_parts) >= 5:  # Need at least 5 parts to get container and blob
                container_name = url_parts[-2]
                blob_name = url_parts[-1]
            else:
                logger.warning(
                    f"[{correlation_id}] Invalid blob URL format: {blob_url}",
                    extra={
                        "custom_dimensions": {
                            "correlation_id": correlation_id,
                            "error_type": "invalid_url",
                            "blob_url": blob_url,
                        }
                    },
                )
                return
        else:
            # Legacy format or direct invocation
            container_name = data.get("containerName", "inbox")
            blob_name = data.get("blobName")

            # Handle EventGrid notification directly sent to queue
            if not blob_name and "subject" in data:
                subject = data.get("subject", "")
                if subject.startswith("/blobServices/default/containers/"):
                    parts = subject.split("/")
                    if len(parts) >= 5:
                        container_name = parts[3]
                        blob_name = "/".join(parts[4:])

        if not blob_name:
            logger.warning(
                f"[{correlation_id}] No blob name in message. Message content: {json.dumps(data)[:500]}",
                extra={
                    "custom_dimensions": {
                        "correlation_id": correlation_id,
                        "error_type": "missing_blob_name",
                        "message_preview": json.dumps(data)[:500],
                    }
                },
            )
            return

        # Generate a request ID (include correlation ID to link logs)
        request_id = f"req-{correlation_id[-8:]}"

        logger.info(
            f"[{correlation_id}] Starting document processing. RequestID: {request_id}, Blob: {container_name}/{blob_name}",
            extra={
                "custom_dimensions": {
                    "correlation_id": correlation_id,
                    "request_id": request_id,
                    "container_name": container_name,
                    "blob_name": blob_name,
                    "event_type": "process_start",
                }
            },
        )

        # Process the document
        process_document(request_id, container_name, blob_name)

        execution_time = time.time() - start_time
        logger.info(
            f"[{correlation_id}] Processing complete for {blob_name}. Execution time: {execution_time:.2f}s",
            extra={
                "custom_dimensions": {
                    "correlation_id": correlation_id,
                    "request_id": request_id,
                    "container_name": container_name,
                    "blob_name": blob_name,
                    "execution_time_seconds": execution_time,
                    "event_type": "process_complete",
                }
            },
        )

    except Exception as e:
        execution_time = time.time() - start_time
        logger.error(
            f"[{correlation_id}] Error processing document: {str(e)}",
            extra={
                "custom_dimensions": {
                    "correlation_id": correlation_id,
                    "error_type": "processing_error",
                    "error_message": str(e),
                    "execution_time_seconds": execution_time,
                    "event_type": "process_error",
                }
            },
        )
        raise
