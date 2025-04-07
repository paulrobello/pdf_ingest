"""Azure Storage utility functions for PDF OCR processing."""

from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import BinaryIO

from azure.storage.blob import BlobServiceClient

# Get connection string from environment
connection_string = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")


def download_blob_to_temp(container_name: str, blob_name: str) -> Path:
    """
    Download a blob from Azure Blob Storage to a temporary file.

    Args:
        container_name: The container name
        blob_name: The blob name

    Returns:
        The path to the temporary file containing the blob contents

    Raises:
        Exception: If the blob download fails
    """
    if not connection_string:
        raise ValueError("AZURE_STORAGE_CONNECTION_STRING environment variable not set")

    # Create the BlobServiceClient
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)

    # Get a client for the blob
    blob_client = blob_service_client.get_blob_client(container=container_name, blob=blob_name)

    # Create a temporary file
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=Path(blob_name).suffix)

    # Download the blob to the temporary file
    with open(temp_file.name, "wb") as file:
        download_stream = blob_client.download_blob()
        file.write(download_stream.readall())

    return Path(temp_file.name)


def upload_to_blob(
    container_name: str, blob_name: str, data: bytes | str | BinaryIO | Path, content_type: str | None = None
) -> str:
    """
    Upload data to an Azure Blob Storage container.

    Args:
        container_name: The container name
        blob_name: The blob name (object key)
        data: The data to upload (bytes, string, file-like object, or Path)
        content_type: Optional content type for the blob

    Returns:
        The URL of the uploaded blob

    Raises:
        Exception: If the upload fails
    """
    if not connection_string:
        raise ValueError("AZURE_STORAGE_CONNECTION_STRING environment variable not set")

    # Create the BlobServiceClient
    blob_service_client = BlobServiceClient.from_connection_string(connection_string)

    # Get a client for the container
    container_client = blob_service_client.get_container_client(container_name)

    # Get a client for the blob
    blob_client = container_client.get_blob_client(blob_name)

    # Handle different input types
    if isinstance(data, Path):
        with open(data, "rb") as file:
            blob_client.upload_blob(file, overwrite=True, content_type=content_type)
    elif isinstance(data, str):
        blob_client.upload_blob(data.encode("utf-8"), overwrite=True, content_type=content_type)
    else:
        blob_client.upload_blob(data, overwrite=True, content_type=content_type)

    return blob_client.url
