"""Health check endpoint for the Azure Function."""

import json
import logging
import os
import platform
from datetime import UTC, datetime
from typing import Any

# Configure logger
logger = logging.getLogger("azure")
logger.setLevel(logging.INFO)


def main(req: Any) -> dict[str, Any]:
    """
    Health check endpoint for the Azure Function.

    Args:
        req: The HTTP request.

    Returns:
        A dictionary containing health information.
    """
    logger.info("Health check request received")

    # Get runtime information
    health_info = {
        "status": "healthy",
        "timestamp": datetime.now(UTC).isoformat(),
        "service": "OcrInboxProcessor",
        "environment": os.environ.get("STACK_ENV", "unknown"),
        "runtime": {
            "python": platform.python_version(),
            "platform": platform.platform(),
        },
    }

    logger.info(f"Health check response: {json.dumps(health_info)}")
    return health_info
