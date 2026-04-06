"""
Analytics Lambda — SQS trigger

Consumes click events from SQS, stores them in the clicks table,
and increments the click counter on the urls table.
"""
import json
import sys
import boto3
from pathlib import Path
from shared.utils import log_event, get_env

sys.path.insert(0, str(Path(__file__).parent.parent))

dynamodb = boto3.resource("dynamodb")
clicks_table = dynamodb.Table(get_env("CLICKS_TABLE"))
urls_table = dynamodb.Table(get_env("URLS_TABLE"))


def handler(event, context):
    log_event(event, context, "analytics")

    processed = 0
    failed = []

    for record in event.get("Records", []):
        try:
            body = json.loads(record["body"])
            code = body["code"]

            # Write to clicks table
            clicks_table.put_item(
                Item={
                    "code": code,
                    "click_id": body["click_id"],
                    "timestamp": body["timestamp"],
                    "user_agent": body.get("user_agent", "unknown"),
                    "ip": body.get("ip", "unknown"),
                    "referer": body.get("referer", ""),
                }
            )

            # Increment click counter on urls table (atomic)
            urls_table.update_item(
                Key={"code": code},
                UpdateExpression="ADD clicks :inc",
                ExpressionAttributeValues={":inc": 1},
            )

            processed += 1

        except Exception as e:
            print(f"Failed to process record: {e}")
            # Return the message ID to SQS so it can retry or go to DLQ
            failed.append({"itemIdentifier": record["messageId"]})

    print(f"Processed {processed} clicks, {len(failed)} failed")

    # Partial batch response — only failed messages go back to queue
    return {"batchItemFailures": failed}
