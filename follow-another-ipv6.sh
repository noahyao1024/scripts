#!/bin/bash

# Ensure required environment variables are set
if [ -z "$API_TOKEN" ]; then
    echo "Error: API_TOKEN is not set."
    exit 1
fi

if [ -z "$ZONE_ID" ]; then
    echo "Error: ZONE_ID is not set."
    exit 1
fi

if [ -z "$RECORD_ID" ]; then
    echo "Error: RECORD_ID is not set."
    exit 1
fi

if [ -z "$RECORD_NAME" ]; then
    echo "Error: RECORD_NAME is not set."
    exit 1
fi

if [ -z "$NSLOOKUP_NAME" ]; then
    echo "Error: NSLOOKUP_NAME is not set."
    exit 1
fi

# Cloudflare API endpoint to get the DNS record details
url="https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}"

# Get the current IP from Cloudflare
current_record=$(curl -s -X GET "$url" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

# Extract the current IP address
CURRENT_IP=$(echo "$current_record" | jq -r '.result.content')

# Get the current IPv6 address using nslookup
NEW_IP=$(nslookup -q=AAAA $NSLOOKUP_NAME 1.1.1.1 | grep 'Address' | tail -n1 | awk '{print $2}')

# Check if the current IP is the same as the new IP
if [ "$CURRENT_IP" == "$NEW_IP" ]; then
    echo "No update needed. The IP address has not changed."
    exit 0
fi

# Data to update the DNS record
update_data=$(jq -n \
    --arg type "AAAA" \
    --arg name "$RECORD_NAME" \
    --arg content "$NEW_IP" \
    --argjson ttl 60 \
    --argjson proxied false \
    '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')

# Update the DNS record
update_response=$(curl -s -X PUT "$url" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$update_data")

# Check if the update was successful
if echo "$update_response" | jq -e '.success' > /dev/null; then
    echo "DNS record updated successfully."
else
    echo "Failed to update DNS record: $(echo "$update_response" | jq -r '.errors[0].message')"
    exit 1
fi
