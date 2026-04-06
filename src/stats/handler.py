"""
Stats Lambda — GET /stats/{code}

Returns click statistics for a short URL.
Uses the clicks GSI to query recent clicks efficiently.
"""
import sys
import boto3
from boto3.dynamodb.conditions import Key
from shared.utils import response, log_event, get_env
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
dynamodb = boto3.resource("dynamodb")
urls_table = dynamodb.Table(get_env("URLS_TABLE"))
clicks_table = dynamodb.Table(get_env("CLICKS_TABLE"))


def handler(event, context):
    log_event(event, context, "stats")

    code = event.get("pathParameters", {}).get("code", "")

    if not code:
        return response(400, {"error": "Missing code"})

    # Get URL metadata
    url_result = urls_table.get_item(Key={"code": code})

    if "Item" not in url_result:
        return response(404, {"error": "Short URL not found"})

    url_item = url_result["Item"]

    # Query recent clicks from clicks table
    clicks_result = clicks_table.query(
        KeyConditionExpression=Key("code").eq(code),
        ScanIndexForward=False,  # Most recent first
        Limit=100,
    )

    clicks = clicks_result.get("Items", [])

    # Aggregate user agents (top 5)
    user_agents = Counter(c.get("user_agent", "unknown") for c in clicks)
    top_user_agents = [
        {"user_agent": ua, "count": count}
        for ua, count in user_agents.most_common(5)
    ]

    # Aggregate referers (top 5, excluding empty)
    referers = Counter(c.get("referer", "") for c in clicks if c.get("referer"))
    top_referers = [
        {"referer": ref, "count": count} for ref, count in referers.most_common(5)
    ]

    return response(
        200,
        {
            "code": code,
            "original_url": url_item["url"],
            "total_clicks": int(url_item.get("clicks", 0)),
            "created_at": int(url_item["created_at"]),
            "recent_clicks_shown": len(clicks),
            "top_user_agents": top_user_agents,
            "top_referers": top_referers,
        },
    )
