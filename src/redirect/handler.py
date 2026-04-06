"""
Redirect Lambda — GET /{code}

Looks up the short code, emits a click event to SQS,
and returns a 302 redirect to the original URL.
"""
import json
import sys
import time
import uuid
from pathlib import Path
import boto3
from shared.utils import response, log_event, get_env 

sys.path.insert(0, str(Path(__file__).parent.parent))

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")

table = dynamodb.Table(get_env("URLS_TABLE"))
QUEUE_URL = get_env("CLICKS_QUEUE_URL")


def handler(event, context):
    log_event(event, context, "redirect")

    code = event.get("pathParameters", {}).get("code", "")

    if not code:
        return response(400, {"error": "Missing code"})

    # Look up the short code
    result = table.get_item(Key={"code": code}, ConsistentRead=True)

    if "Item" not in result:
        return response(404, {"error": "Short URL not found"})

    item = result["Item"]
    original_url = item["url"]

    # Emit click event to SQS (fire-and-forget, doesn't block the redirect)
    try:
        click_event = {
            "click_id": str(uuid.uuid4()),
            "code": code,
            "timestamp": int(time.time()),
            "user_agent": event.get("headers", {}).get(
                "user-agent", "unknown"
            ),
            "ip": event.get("requestContext", {})
            .get("http", {})
            .get("sourceIp", "unknown"),
            "referer": event.get("headers", {}).get("referer", ""),
        }

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(click_event),
        )
    except Exception as e:
        # Don't fail the redirect if analytics fails
        print(f"Failed to emit click event: {e}")

    # 302 redirect
    return {
        "statusCode": 302,
        "headers": {
            "Location": original_url,
            "Cache-Control": "no-cache, no-store",
        },
        "body": "",
    }
