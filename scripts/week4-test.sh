#!/usr/bin/env bash
# Week 4: test the AI gateway from the test VM (it only accepts internal traffic).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W4="$ROOT/infra/week04-ai-gateway"
GW=$(terraform -chdir="$W4" output -raw gateway_url)
MASTER=$(gcloud secrets versions access latest --secret "$(terraform -chdir="$W4" output -raw master_key_secret)")
DEMO="sk-team-demo-$(date +%s)"

echo "From your laptop first (should be refused by Cloud Run's internal-only ingress):"
echo "  HTTP $(curl -s -o /dev/null -w '%{http_code}' "$GW/health/liveliness")  (404 or 403 expected)"
echo; echo "Now from inside the VPC. The first call may take ~30s while the gateway starts."

cat > /tmp/gw-test.sh <<SCRIPT
set -u
pass=0; fail=0
check() { if [ "\$2" = "\$3" ]; then echo "PASS  \$1"; pass=\$((pass+1)); else echo "FAIL  \$1 (expected \$3, got \$2)"; fail=\$((fail+1)); fi; }
code() { curl -s -o /tmp/out.json -w '%{http_code}' --max-time 90 "\$@"; }
chat() { echo "{\"model\":\"\$1\",\"max_tokens\":60,\"messages\":[{\"role\":\"user\",\"content\":\"\$2\"}]}"; }
check "gateway is healthy" "\$(code $GW/health/liveliness)" "200"
curl -s -o /dev/null $GW/key/generate -H "Authorization: Bearer $MASTER" -H "Content-Type: application/json" \
  -d '{"key":"$DEMO","key_alias":"$DEMO","models":["bank-chat"],"rpm_limit":2}'
check "a made-up key is refused (401)" "\$(code $GW/v1/chat/completions -H 'Authorization: Bearer sk-nope-123456789012' -H 'Content-Type: application/json' -d "\$(chat bank-chat hi)")" "401"
check "team key works (200)" "\$(code $GW/v1/chat/completions -H 'Authorization: Bearer $DEMO' -H 'Content-Type: application/json' -d "\$(chat bank-chat 'What does an AI gateway do? One sentence.')")" "200"
python3 -c 'import json;d=json.load(open("/tmp/out.json"));print("      answer:", d.get("choices",[{}])[0].get("message",{}).get("content", d))'
check "team key can't use other models (403)" "\$(code $GW/v1/chat/completions -H 'Authorization: Bearer $DEMO' -H 'Content-Type: application/json' -d "\$(chat some-other-model hi)")" "403"
last=""
for i in 1 2 3; do last=\$(code $GW/v1/chat/completions -H 'Authorization: Bearer $DEMO' -H 'Content-Type: application/json' -d "\$(chat bank-chat hi)"); done
check "the key's 2-per-minute limit kicks in (429)" "\$last" "429"
echo; echo "\$pass passed, \$fail failed"
SCRIPT
"$ROOT/scripts/on-vm.sh" "bash -s" /tmp/gw-test.sh
