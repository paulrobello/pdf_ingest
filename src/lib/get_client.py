"""
This module provides a simple interface to interact with AWS services.

It uses the boto3 library to interact with AWS services. By default, it uses the
environment variable AWS_REGION to determine the AWS region to connect to. If
the AWS_REGION environment variable is not set, it uses the default region
"eu-west-1".

Example usage:

import os
from aws_utils import client, resource

# Set the AWS_REGION environment variable to use a different region
os.environ["AWS_REGION"] = "us-east-1"

# Create a S3 client and list the buckets in the current region
s3 = client("s3")
buckets = s3.list_buckets()
for bucket in buckets["Buckets"]:
    print(bucket["Name"])

# Create a DynamoDB resource and list the tables in the current region
dynamodb = resource("dynamodb")
tables = dynamodb.tables.all()
for table in tables:
    print(table.name)

"""

import os

import boto3

default_region = os.environ.get("AWS_REGION", "eu-west-1")


def get_session():
    """
    Returns a boto3 session. If the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
    environment variables are set, it will use those credentials to create a
    session. Otherwise, it will use the default credentials chain to obtain
    credentials.

    Returns:
        boto3.session.Session: A boto3 session.
    """
    return boto3.session.Session()


def client(client_type, region: str = default_region):
    """
    Returns a boto3 client for the specified client type and region.

    Args:
        client_type (str): The type of client to return, e.g. "s3".
        region (str, optional): The AWS region to connect to. Defaults to the
            value of the AWS_REGION environment variable, or "eu-west-1" if the
            AWS_REGION environment variable is not set.

    Returns:
        boto3.client: A boto3 client for the specified client type and region.
    """
    session = get_session()
    if session:
        return session.client(client_type, region_name=region)
    return boto3.client(client_type, region_name=region)


def resource(client_type: str, region: str = default_region):
    """
    Returns a boto3 resource for the specified client type and region.

    Args:
        client_type (str): The type of resource to return, e.g. "s3".
        region (str, optional): The AWS region to connect to. Defaults to the
            value of the AWS_REGION environment variable, or "eu-west-1" if the
            AWS_REGION environment variable is not set.

    Returns:
        boto3.resource: A boto3 resource for the specified client type and region.
    """
    session = get_session()
    if session:
        return session.resource(client_type, region_name=region)
    return boto3.resource(client_type, region_name=region)
