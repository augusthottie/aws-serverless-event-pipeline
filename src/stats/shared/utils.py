"""Shared utilities used by all Lambda functions."""
import json
import logging
import os
import random
import string
from typing import Any

# Structured logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def log_event(event: dict, context: Any, function_name: str) -> None:
    """Log request metadata for observability."""
    logger.info(
        json.dumps(
            {
                "function": function_name,
                "request_id": getattr(context, "aws_request_id", "local"),
                "event_type": event.get("httpMethod", "sqs"),
                "path": event.get("path", ""),
            }
        )
    )


def response(status_code: int, body: Any, headers: dict | None = None) -> dict:
    """Build an API Gateway response."""
    default_headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
    }
    if headers:
        default_headers.update(headers)

    return {
        "statusCode": status_code,
        "headers": default_headers,
        "body": json.dumps(body) if not isinstance(body, str) else body,
    }


def generate_code(length: int = 7) -> str:
    """Generate a random short code using URL-safe characters."""
    alphabet = string.ascii_letters + string.digits
    return "".join(random.choices(alphabet, k=length))


def is_valid_url(url: str) -> bool:
    """Basic URL validation."""
    return url.startswith(("http://", "https://")) and len(url) < 2048


def get_env(key: str, default: str | None = None) -> str:
    """Get required environment variable."""
    value = os.environ.get(key, default)
    if value is None:
        raise ValueError(f"Missing required env var: {key}")
    return value
