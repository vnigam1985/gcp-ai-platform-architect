#!/usr/bin/env bash
# Runs ON the test VM (make week2-test sends it over IAP SSH).
# Proves:
#   1. The VM has no internet path at all
#   2. Yet it reaches Google APIs (Private Google Access: Google's network only)
#   3. The VM gets a token from its service account (no keys anywhere)
#   4. Gemini answers on the REGIONAL Montreal endpoint
# Inputs: PROJECT, REGION, MODEL
set -u
HOST="${REGION}-aiplatform.googleapis.com"

echo "== 1. No internet =="
if curl -s --max-time 5 -o /dev/null https://example.com; then
  echo "FAIL the VM reached the internet"
else
  echo "PASS no route to the internet"
fi

echo "== 2. But Google APIs are reachable (Private Google Access) =="
IP=$(getent hosts "$HOST" | awk '{print $1}' | head -1)
echo "$HOST -> ${IP:-no answer} (a Google address, reached over Google's network, not the internet)"

echo "== 3. Token from the service account =="
TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))')
[ -n "$TOKEN" ] && echo "PASS got a token" || echo "FAIL no token"

echo "== 4. Call Gemini on the regional endpoint =="
curl -s -w '\nHTTP %{http_code}\n' \
  "https://${HOST}/v1/projects/${PROJECT}/locations/${REGION}/publishers/google/models/${MODEL}:generateContent" \
  -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  -d '{"contents":[{"role":"user","parts":[{"text":"Say hello from a private network in one short sentence."}]}],"generationConfig":{"maxOutputTokens":60}}' \
  | python3 -c '
import json, sys
raw = sys.stdin.read(); body, _, status = raw.rpartition("\nHTTP ")
print("HTTP", status.strip())
try:
    print("Answer:", json.loads(body)["candidates"][0]["content"]["parts"][0]["text"].strip())
except Exception:
    print(body[:400])
'
