from typing import Any
from boto3.dynamodb.conditions import Attr, Key
from aws_lambda_powertools import Logger


logger = Logger()


def update_ticket_status(
    job_table: Any, ticket_id: str, new_status: str, attempts: int = None
) -> bool:
    """
    Updates the status of a ticket in DynamoDB.

    :param job_table: The DynamoDB table to update.
    :param ticket_id: The ID of the ticket to update.
    :param new_status: The new status of the ticket.
    :param attempts: The number of attempts made to update the ticket.
    :return: True if the update was successful, False otherwise.
    """
    try:
        update_expression = "SET #s = :s"
        expression_attribute_names = {"#s": "status"}
        expression_attribute_values = {":s": new_status}

        if attempts:
            update_expression += ", #a = :a"
            expression_attribute_names["#a"] = "attempts"
            expression_attribute_values[":a"] = attempts

        job_table.update_item(
            Key={"pk": "ticket", "rk": ticket_id},
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expression_attribute_names,
            ExpressionAttributeValues=expression_attribute_values,
        )
        return True
    except Exception as e:
        logger.error(f"Failed to update item: {e}")
        return False


def get_rest_easy_tickets_with_status(
    job_table: any, ticket_type: str, status: str = "pending-ticket"
) -> list[dict]:
    res = job_table.query(
        KeyConditionExpression=Key("pk").eq("ticket"),
        FilterExpression=Attr("ticket_type").eq(ticket_type)
        & Attr("status").eq(status),
    )
    if "Items" in res:
        return res["Items"]
    return []


def get_item(table: any, pk_value: str, rk_value: str):
    try:
        response = table.get_item(Key={"pk": pk_value, "rk": rk_value})
        if "Item" in response:
            return response["Item"]
        else:
            logger.info(f"Item not found: {pk_value}-{rk_value}")

    except Exception as e:
        logger.error(f"Unable to retrieve item. Error: {e}")


def put_item(table, item):
    try:
        table.put_item(Item=item)
        return item
    except Exception as e:
        logger.error(f"Unable to insert item. Error: {e}")
