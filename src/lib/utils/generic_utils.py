import base64
import copy
import csv
import hashlib
import json
import logging
import math
import os
import random
import string
import traceback
import uuid
from collections.abc import Generator
from datetime import date, datetime
from decimal import Decimal
from io import StringIO
from os import listdir
from os.path import isfile, join
from typing import Any

from azure.servicebus import ServiceBusClient
from azure.storage.blob import BlobServiceClient

from .headers_util import get_cors_headers

# Configure logger
logger = logging.getLogger("azure")
logger.setLevel(logging.INFO)
encodings = ["utf-8", "ISO-8859-1", "windows-1250", "windows-1252"]
DECIMAL_PRECESSION = 5


def get_auth_header_rest_ap(access_token: str) -> dict:
    """
    Returns an authorization header for a REST API request using Bearer authentication.

    :param access_token: The access token to use for authentication.
    :return: The authorization header as a dictionary.
    """
    return {"Authorization": f"Bearer {access_token}"}


def get_auth_header_ws_api(access_token: str) -> list:
    """
    Returns an authorization header for a WebSocket API request using Bearer authentication.

    :param access_token: The access token to use for authentication.
    :return: The authorization header as a list of strings.
    """
    return [f"Sec-WebSocket-Protocol: auth, {access_token}"]


def id_generator(size=6, chars=string.ascii_uppercase + string.digits):
    """
    Generates a random string of uppercase letters and digits.

    :param size: The length of the string to generate.
    :param chars: The characters to use for the string.
    :return: The random string.
    """
    return "".join(random.choice(chars) for _ in range(size))


def json_serial(obj):
    """
    JSON serializer for objects not serializable by default json code.

    :param obj: The object to serialize.
    :return: The serialized object.
    """

    if isinstance(obj, datetime | date):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")


def deep_copy(obj):
    # tmp = json.dumps(obj)
    # return json.loads(tmp, use_decimal=True)
    return copy.deepcopy(obj)


def coalesce(*arg):
    """
    Return first item that is not None.

    :param arg: The items to check.
    :return: The first non-None item.
    """
    return next((a for a in arg if a is not None), None)


def chunks(lst: list, n: int) -> Generator[Any, Any, Any]:
    """
    Yield successive n-sized chunks from lst.

    :param lst: The list to split.
    :param n: The size of the chunks.
    :return: The chunks.
    """
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def to_camel_case(snake_str):
    """
    Convert a snake_case string to CamelCase.

    :param snake_str: The snake_case string.
    :return: The CamelCase string.
    """
    components = snake_str.split("_")
    # We capitalize the first letter of each component except the first one
    # with the 'title' method and join them together.
    return components[0] + "".join(x.title() for x in components[1:])


def to_class_case(snake_str):
    """
    Convert a snake_case string to ClassCase.

    :param snake_str: The snake_case string.
    :return: The ClassCase string.
    """
    components = snake_str.split("_")
    # We capitalize the first letter of each component
    # with the 'title' method and join them together.
    return "".join(x.title() for x in components[0:])


def apigw_db_results(results, table_name):
    """
    Generate an API Gateway response body for a database query.

    :param results: The results of the query.
    :param table_name: The name of the table being queried.
    :return: The response body as a dictionary.
    """
    if results:
        logger.info({"message": results})
        return gen_api_response_body(results)
    return gen_api_response_body(f"{table_name} was not found", 404)


def gen_api_response_body(data, httpCode: int = 200) -> dict:
    try:
        body = json.dumps({"data": data}, default=str)
        resp = {
            "statusCode": httpCode,
            "isBase64Encoded": False,
            "headers": get_cors_headers(),
            "body": body,
        }
    except Exception:
        logger.error(f"Error: {str(traceback.format_exc())}")
        resp = {
            "statusCode": 500,
            "isBase64Encoded": False,
            "headers": get_cors_headers(),
            "body": "Unknown error happened in gen_api_response_body",
        }
    return resp


def get_files(path: str, ext: str = "") -> list[str]:
    """Return list of file names in alphabetical order inside of provided path non-recursively.
    Omitting files not ending with ext."""
    ret = [f for f in listdir(path) if isfile(join(path, f)) and (not ext or not f.endswith(ext))]
    ret.sort()
    return ret


# tests if value is able to be converted to float
def is_float(s) -> bool:
    try:
        float(s)
        return True
    except (ValueError, TypeError):
        return False


# tests if value is able to be converted to int
def is_int(s) -> bool:
    try:
        int(s)
        return True
    except (ValueError, TypeError):
        return False


def is_date(date_text: str, fmt: str = "%Y/%m/%d") -> bool:
    try:
        datetime.strptime(date_text, fmt)
        return True
    except ValueError:
        return False


def open_and_detect_encoding(file_name: str):
    for enc in encodings:
        try:
            fh = open(file_name, encoding=enc)
            fh.readlines()
            fh.seek(0)
        except UnicodeDecodeError:
            print(f"got unicode error with {enc} , trying different encoding")
        else:
            print(f"opening the file with encoding:  {enc} ")
            return fh
    return None


def read_and_detect_encoding(f):
    data = f.read()
    for enc in encodings:
        try:
            ret = data.decode(enc)
        except UnicodeDecodeError:
            print(f"got unicode error with {enc} , trying different encoding")
        else:
            print(f"opening the file with encoding:  {enc} ")
            return ret

    return None


def has_value(v, search: str, depth: int = 0) -> bool:
    """Recursively search data structure for search value"""
    # don't go more than 3 levels deep
    if depth > 4:
        return False
    # if is a dict, search all dict values recursively
    if isinstance(v, dict):
        for dv in v.values():
            if has_value(dv, search, depth + 1):
                return True
    # if is a list, search all list values recursively
    if isinstance(v, list):
        for li in v:
            if has_value(li, search, depth + 1):
                return True
    # if is an int, trim off .00 for search if it exists then compare
    if isinstance(v, int):
        search = search.rstrip(".00")
        if str(v) == search:
            return True
    # if is a float, truncate string version of float to same size as search
    if isinstance(v, float):
        v = str(v)[0 : len(search)]
        if search == v:
            return True
    # if is a string, strip and lowercase it then check if string starts with search
    if isinstance(v, str):
        if v.lower().strip().startswith(search) or v.lower().strip().endswith(search):
            return True
    return False


def is_zero(val):
    if val is None:
        return False
    t = type(val)
    if t is Decimal:
        return val.round(DECIMAL_PRECESSION).is_zero()
    if t is float:
        return math.isclose(round(val, 5), 0, rel_tol=1e-05)
    if t is int:
        return 0 == val
    return False


def non_zero(val):
    return not is_zero(val)


def principal_to_username(principal_id: str) -> str:
    username = principal_id.split("|")
    if len(username) > 2:
        username = username[2].split("@")[0]
    else:
        username = principal_id
    return username


def service_bus_send_message(
    queue_or_topic_name: str, message: str, connection_string: str | None = None
) -> str | None:
    """
    Publishes a message to an Azure Service Bus queue or topic.

    Args:
        queue_or_topic_name: The queue or topic to publish to.
        message: The message to publish.
        connection_string: The Service Bus connection string. Defaults to environment variable.

    Returns:
        The message ID or None on error.
    """
    if not connection_string:
        connection_string = os.environ.get("AZURE_SERVICEBUS_CONNECTION_STRING")

    if not connection_string:
        logger.error("AZURE_SERVICEBUS_CONNECTION_STRING environment variable not set")
        return None

    msg = json.dumps({"default": message})
    hash_object = hashlib.sha256(msg.encode("utf-8"))
    hex_dig = hash_object.hexdigest()

    try:
        logger.info(f"Service Bus publish to {queue_or_topic_name}: {message}")
        with ServiceBusClient.from_connection_string(connection_string) as service_bus_client:
            sender = service_bus_client.get_queue_sender(queue_name=queue_or_topic_name)
            with sender:
                # Create a message with custom properties
                from azure.servicebus import ServiceBusMessage

                sb_message = ServiceBusMessage(
                    body=msg,
                    message_id=hex_dig,
                    content_type="application/json",
                )
                # Send the message
                sender.send_messages(sb_message)
                return hex_dig
    except Exception as e:
        logger.error(e)
        return None


def get_azure_client(service_name: str, connection_string: str | None = None) -> object:
    """
    Gets an Azure client for the specified service.

    Args:
        service_name: The name of the Azure service (blob, queue, etc.).
        connection_string: The connection string for the service.
                          If not provided, falls back to environment variables.

    Returns:
        The Azure client.
    """
    if service_name.lower() == "blob":
        if not connection_string:
            connection_string = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
        return BlobServiceClient.from_connection_string(connection_string)
    elif service_name.lower() == "queue":
        if not connection_string:
            connection_string = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
        from azure.storage.queue import QueueServiceClient

        return QueueServiceClient.from_connection_string(connection_string)
    elif service_name.lower() == "servicebus":
        if not connection_string:
            connection_string = os.environ["AZURE_SERVICEBUS_CONNECTION_STRING"]
        return ServiceBusClient.from_connection_string(connection_string)
    else:
        logger.error(f"Unknown Azure service: {service_name}")
        return None


def dict_keys_to_lower(dictionary: dict) -> dict:
    """
    Return a new dictionary with all keys lowercase
    @param dictionary: dict with keys that you want to lowercase
    @return: new dictionary with lowercase keys
    """
    return {k.lower(): v for k, v in dictionary.items()}


def is_valid_uuid_v4(value: str) -> bool:
    try:
        uuid_obj = uuid.UUID(value, version=4)
        return str(uuid_obj) == value  # Check if the string representation matches
    except ValueError:
        return False


def get_event_body(event: dict) -> dict:
    """
    Extracts the request body from the API Gateway event.

    Args:
            event (dict): The API Gateway event containing the request body.

    Returns:
            dict: The request body as a Python dictionary.
    """
    body = event.get("body", "")
    return json.loads(base64.b64decode(body).decode("utf-8") if event["isBase64Encoded"] else body)


def parse_csv_text(csv_data: StringIO) -> list[dict]:
    """
    Reads in a CSV file as text and returns it as a list of dictionaries.

    Args:
            csv_data (StringIO): The CSV file as text.

    Returns:
            typing.List[typing.Dict]: The CSV data as a list of dictionaries.
    """
    return [row for row in csv.DictReader(csv_data)]


def read_text_file_to_stringio(file_path: str) -> StringIO:
    """
    Reads in a text file and returns it as a StringIO object.

    Args:
            file_path (str): The path to the file to read.

    Returns:
            StringIO: The text file as a StringIO object.
    """
    with open(file_path) as file:
        return StringIO(file.read())


def md5_hash(data: str) -> str:
    """
    Returns a md5 hash of the input data.

    Args:
            data (str): The input data.

    Returns:
            str: The md5 hash of the input data.
    """
    md5 = hashlib.md5()
    md5.update(data.encode())
    return md5.hexdigest()


def sha1_hash(data: str) -> str:
    """
    Returns a SHA1 hash of the input data.

    Args:
            data (str): The input data.

    Returns:
            str: The SHA1 hash of the input data.
    """
    sha1 = hashlib.sha1()
    sha1.update(data.encode())
    return sha1.hexdigest()


def sha256_hash(data: str) -> str:
    """
    Returns a SHA256 hash of the input data.

    Args:
            data (str): The input data.

    Returns:
            str: The SHA256 hash of the input data.
    """
    sha256 = hashlib.sha256()
    sha256.update(data.encode())
    return sha256.hexdigest()


def nested_get(dictionary: dict, keys: str | list[str]):
    """
    Returns the value for a given key in a nested dictionary.

    Args:
            dictionary (dict): The nested dictionary to search.
            keys (str | list[str]): The key or list of keys to search for.

    Returns:
            Any: The value for the given key or None if the key does not exist.
    """
    if isinstance(keys, str):
        keys = keys.split(".")
    if keys and dictionary:
        element = keys[0]
        if element in dictionary:
            if len(keys) == 1:
                return dictionary[element]
            else:
                return nested_get(dictionary[element], keys[1:])
    return None


def convert_date_time(input_date):
    valid_date_formats = ["%Y-%m-%d %H:%M:%S", "%Y-%m-%d"]
    for date_format in valid_date_formats:
        try:
            parsed_date = datetime.strptime(input_date, date_format).strftime("%Y-%m-%d")
            return parsed_date
        except Exception:
            continue
    raise ValueError("Skipping Entry with input date not a valid format.")
