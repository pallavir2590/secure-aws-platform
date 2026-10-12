"""Health check Lambda.

Confirms the function can reach its S3 bucket and read its secret,
without ever printing the secret value.
"""

import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
secrets = boto3.client("secretsmanager")


def lambda_handler(event, context):
    environment = os.environ["ENVIRONMENT"]
    bucket = os.environ["DATA_BUCKET"]
    secret_arn = os.environ["SECRET_ARN"]

    checks = {}

    # 1. Can we reach the data bucket?
    s3.list_objects_v2(Bucket=bucket, MaxKeys=1)
    checks["s3_bucket"] = "ok"

    # 2. Can we read the secret? (only check it exists, never log it)
    secret = json.loads(secrets.get_secret_value(SecretId=secret_arn)["SecretString"])
    checks["secret"] = "ok" if "api_key" in secret else "missing key"

    result = {"status": "healthy", "environment": environment, "checks": checks}
    logger.info(json.dumps(result))

    return {"statusCode": 200, "body": json.dumps(result)}
