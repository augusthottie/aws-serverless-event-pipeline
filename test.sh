#!/bin/bash
set -e

# Get the API URL from terraform output
API_URL=$(cd terraform && terraform output -raw api_url)

echo "==================================="
echo "Testing URL Shortener Pipeline"
echo "API: $API_URL"
echo "==================================="
echo ""

# 1. Shorten a URL
echo "1. Creating short URL..."
RESPONSE=$(curl -s -X POST $API_URL/shorten \
  -H "Content-Type: application/json" \
  -d '{"url":"https://github.com/augusthottie"}')

echo "Response: $RESPONSE"
CODE=$(echo $RESPONSE | python3 -c "import json,sys; print(json.load(sys.stdin)['code'])")
echo "Short code: $CODE"
echo ""

# 2. Try the redirect (should return 302 to github)
echo "2. Testing redirect..."
curl -s -o /dev/null -D - -X GET $API_URL/$CODE | head -5
echo ""

# 3. Generate some clicks
echo "3. Generating 10 clicks..."
for i in $(seq 1 10); do
  curl -s -o /dev/null $API_URL/$CODE
  echo -n "."
done
echo " done"
echo ""

# 4. Wait for SQS → Lambda to process
echo "4. Waiting 20s for async processing..."
sleep 20

# 5. Get stats
echo "5. Fetching stats..."
curl -s $API_URL/stats/$CODE | python3 -m json.tool
echo ""

echo "==================================="
echo "Test complete!"
echo "==================================="
