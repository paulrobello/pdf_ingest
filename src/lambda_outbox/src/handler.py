"""Lambda to process OCR results from S3 bucket."""

from typing import Any
from urllib.parse import unquote_plus

import boto3
import orjson as json
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()

s3 = boto3.client("s3")


@logger.inject_lambda_context
def lambda_handler(
    event: dict[str, Any],
    context: LambdaContext,  # pylint: disable=unused-argument
) -> dict[str, Any]:
    """
    Process OCR results from S3 bucket.

    Args:
        event (Dict[str, Any]): The event dict containing information about the S3 object.
        context (LambdaContext): The Lambda context object.

    Returns:
        Dict[str, Any]: A dictionary containing the status of the operation.
    """

    if "Records" not in event:
        logger.warning("No Records in event")
        return {"statusCode": 200, "body": json.dumps("Processing complete")}

    try:
        for body in event["Records"]:
            if "s3" not in body:
                logger.warning("No s3 information in record")
                continue
            # Extract S3 bucket and key information from the event
            bucket = body["s3"]["bucket"]["name"]
            key = unquote_plus(body["s3"]["object"]["key"])
            file_ext = key.split(".")[-1].lower()
            if file_ext != "md":
                logger.warning(f"File extension not .md ({key})")
                continue

            logger.info(f"Processing OCR results for object: s3://{bucket}/{key}")

            response = s3.get_object(Bucket=bucket, Key=key)
            markdown = response["Body"].read().decode("utf-8")

            logger.info(markdown)
            logger.info("Successfully processed OCR results")
        return {
            "statusCode": 200,
            "body": json.dumps("OCR results processed successfully"),
        }
    except Exception as e:  # pylint: disable=broad-except
        logger.exception("Error processing OCR results")
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error processing OCR results: {str(e)}"),
        }
