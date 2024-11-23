"""Start ocr from S3 events."""

import os
from typing import Any
from urllib.parse import unquote_plus

import boto3
import orjson as json
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext
from ai_ocr import main
from ai_ocr.lib.llm_providers import LlmProvider

logger = Logger()

s3 = boto3.client("s3")


def process_document(request_id: str, bucket: str, key: str) -> None:
    """
    Process a document using Amazon Bedrock vision.

    Args:
        request_id (str): The ID of the request.
        bucket (str): The S3 bucket name.
        key (str): The S3 object key of the document to process.
    """

    logger.info(f"Starting OCR id {request_id} for object: s3://{bucket}/{key}")

    main(
        max_workers=int(os.environ.get("MAX_OCR_WORKERS", 0)),
        ai_provider=LlmProvider(os.environ.get("AI_PROVIDER", "Bedrock")),
        model=os.environ.get("AI_MODEL"),
        ai_base_url=os.environ.get("AI_BASE_URL"),
        input_bucket=bucket,
        input_key=key,
        output_bucket=bucket,
        output_key=os.environ.get("OUTPUT_KEY", f"outbox/{request_id}"),
        request_id=request_id,
    )


@logger.inject_lambda_context
def lambda_handler(
    event: dict[str, Any],
    context: LambdaContext,  # pylint: disable=unused-argument
) -> dict[str, Any]:
    """
    Process SQS messages triggered by S3 uploads to the /inbox prefix.

    Args:
        event (Dict[str, Any]): The event dict containing SQS messages.
        context (Any): The Lambda context object.

    Returns:
        Dict[str, Any]: A dictionary containing the status of the operation.
    """
    if "Records" not in event:
        logger.warning("No Records in event")
        return {"statusCode": 200, "body": json.dumps("Processing complete")}

    for event_record in event["Records"]:
        body = json.loads(event_record["body"])
        if "Records" not in body:
            logger.warning("No Records information in body")
            continue
        for record in body["Records"]:
            if "s3" not in record:
                logger.warning("No s3 information in record")
                continue
            request_id = record["responseElements"]["x-amz-request-id"]
            bucket = record["s3"]["bucket"]["name"]
            key = unquote_plus(record["s3"]["object"]["key"])

            process_document(request_id, bucket, key)

    return {"statusCode": 200, "body": json.dumps("Processing complete")}
