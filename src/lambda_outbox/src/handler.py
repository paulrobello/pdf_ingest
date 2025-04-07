"""Function to process OCR results from Azure Blob Storage."""

import logging
import os
from typing import Any

from azure.storage.blob import BlobServiceClient

# Configure logger
logger = logging.getLogger("azure")
logger.setLevel(logging.INFO)

# Get the Azure Storage connection string
connection_string = os.environ["AzureWebJobsStorage"]
blob_service_client = BlobServiceClient.from_connection_string(connection_string)


def main(blob: Any) -> None:
    """
    Process OCR results from Azure Blob Storage.

    This is the entry point for Azure Functions with Blob trigger.

    Args:
        blob: The blob object that triggered the function.
    """
    try:
        # Get blob info
        blob_name = blob.name

        # Log detailed information to debug trigger issues
        logger.info(f"Received blob trigger for: {blob_name}")

        # Only process markdown files with the -final.md suffix
        if not blob_name.endswith("-final.md"):
            logger.info(f"Skipping non-final file: {blob_name}")
            return

        # Read blob content
        content = blob.read().decode("utf-8")

        # Log the content for demonstration
        logger.info(f"Processing OCR results for blob: {blob_name}")
        logger.info(f"Content: {content[:200]}...")  # Log first 200 chars

        # Here you can add additional processing for the OCR results
        # For example, storing in a database, sending notifications, etc.

        logger.info(f"Successfully processed OCR results for {blob_name}")

    except Exception as e:
        logger.error(f"Error processing OCR results: {str(e)}")
        # Log the exception traceback for better debugging
        import traceback

        logger.error(f"Exception traceback: {traceback.format_exc()}")
        raise
