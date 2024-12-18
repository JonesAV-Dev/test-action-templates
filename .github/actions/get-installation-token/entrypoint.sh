#!/bin/bash

set -e

# Inputs
APP_ID=$1
PRIVATE_KEY=$2

# --- Generate JWT ---
# Write the private key to a file
echo "$PRIVATE_KEY" > private-key.pem

# Remove any Windows-style carriage returns
sed -i 's/\r$//g' private-key.pem

# Create JWT header & payload
HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -A | tr '+/' '-_' | tr -d '=')
IAT=$(date +%s)
IAT=$((IAT - 60))
EXP=$((IAT + 600))

PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $IAT $EXP "$APP_ID" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
HEADER_PAYLOAD="$HEADER.$PAYLOAD"

SIGNATURE=$(echo -n "$HEADER_PAYLOAD" | openssl dgst -sha256 -sign private-key.pem | openssl base64 -A | tr '+/' '-_' | tr -d '=')
JWT="$HEADER_PAYLOAD.$SIGNATURE"

#Get Installation ID
INSTALLATION_RESPONSE=$(curl -s -X GET \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/app/installations)

# Picks the first installaion ID returned if multiple exist
# If multiple installations, parse & select target
INSTALLATION_ID=$(echo "$INSTALLATION_RESPONSE" | jq -r '.[0].id')

if [ "$INSTALLATION_ID" == "null" ]; then
  echo "No installations found. Make sure the app is installed on the target repo."
  exit 1
fi

echo "INSTALLATION_ID=$INSTALLATION_ID" >> $GITHUB_OUTPUT

# Get Installation Access Token
TOKEN_REPSONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  http://api.github.com/app/installations/$INSTALLER_ID/access_tokens)

TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token')

if [ "$TOKEN" == "null" ]; then
  echo "Failed to retrieve installation token. Response: $TOKEN_RESPONSE"
  exit 1
fi

# Output the token
echo "::set-output name=token::$TOKEN"
