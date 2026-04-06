"""
Shortener Lambda — POST /shorten

Accepts a URL, generates a short code, stores it in DynamoDB,
and returns the short URL.
"""
import json
import sys
import time
from pathlib import Path
import boto3
from botocore.exceptions import ClientError
from shared.utils import response, log_event, generate_code, is_valid_url, get_env

sys.path.insert(0, str(Path(__file__).parent.parent))

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(get_env("URLS_TABLE"))
BASE_URL = get_env("BASE_URL", "https://short.example.com")


def handler(event, context):
    log_event(event, context, "shortener")

    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return response(400, {"error": "Invalid JSON"})

    url = body.get("url", "").strip()

    if not url:
        return response(400, {"error": "Missing 'url' field"})

    if not is_valid_url(url):
        return response(
            400, {"error": "Invalid URL. Must start with http:// or https://"}
        )

    # Generate unique short code (retry on collision)
    code = None
    for _ in range(5):
        candidate = generate_code()
        try:
            table.put_item(
                Item={
                    "code": candidate,
                    "url": url,
                    "created_at": int(time.time()),
                    "clicks": 0,
                },
                ConditionExpression="attribute_not_exists(code)",
            )
            code = candidate
            break
        except ClientError as e:
            if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
                continue
            raise

    if code is None:
        return response(500, {"error": "Failed to generate unique code"})

    return response(
        201,
        {
            "code": code,
            "short_url": f"{BASE_URL}/{code}",
            "original_url": url,
        },
    )
