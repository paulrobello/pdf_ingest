import os


def get_cors_headers(headers: dict | None = None) -> dict:
    """
    Returns a dictionary of CORS headers with the specified origin.
    If Origin header is not specified, it defaults to "*".
    Args:
            headers (dict, optional): The request headers. Defaults to None.


    Returns:
            dict: The CORS headers.
    """
    if headers is None:
        origin = "*"
    else:
        origin = headers.get("Origin", headers.get("origin", "*"))

    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Api-Key,x-ms-date,x-ms-version",
        "Access-Control-Allow-Credentials": "true",
    }


def validate_api_key(event: dict) -> bool:
    """
    Validates the API key in the request headers.
    Uses API_KEY environment variable to validate header.
    Args:
            event (dict): The Azure Function HTTP request event.

    Returns:
            bool: True if the API key is valid, False otherwise.
    """
    api_key_from_env = os.environ.get("API_KEY")
    if not api_key_from_env:
        # print("API_KEY environment variable not set.")
        return False

    headers = event.get("headers", {})

    # Convert header keys to lowercase for case-insensitive comparison
    lower_case_headers = {k.lower(): v for k, v in headers.items()}

    api_key_from_header = lower_case_headers.get("x-api-key")

    if not api_key_from_header:
        # print("x-api-key header not found.")
        return False

    return api_key_from_header == api_key_from_env
