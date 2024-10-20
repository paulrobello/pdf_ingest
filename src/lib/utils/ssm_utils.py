import boto3
from botocore.exceptions import ClientError


def get_ssm_parameter(parameter_name: str):
    """Get an SSM parameter value

    Args:
            parameter_name (str): The name of the SSM parameter

    Returns:
            The value of the SSM parameter, or None if an error occurred
    """
    try:
        # Create a SSM client
        ssm = boto3.client("ssm")

        # Get the parameter
        response = ssm.get_parameter(
            Name=parameter_name,
            WithDecryption=True,  # Set to True if the parameter is encrypted
        )

        # Return the parameter value
        return response["Parameter"]["Value"]

    except ClientError as e:
        print("An error occurred: ", e)
        return None
