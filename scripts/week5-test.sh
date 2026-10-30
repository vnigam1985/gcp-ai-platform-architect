#!/usr/bin/env bash
# Week 5: ask the private bank app questions, from inside the VPC.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP=$(terraform -chdir="$ROOT/infra/week05-private-app" output -raw app_url)
echo "From your laptop (should be refused, internal ingress only): HTTP $(curl -s -o /dev/null -w '%{http_code}' "$APP/health")"
cat > /tmp/app-test.sh <<SCRIPT
echo "== Health =="; curl -s --max-time 90 $APP/health; echo
echo "== Ask: app -> gateway -> Model Armor -> Gemini =="
curl -s --max-time 90 -X POST $APP/ask -H 'Content-Type: application/json' -d '{"question":"How much does an international wire transfer cost?"}' \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print("Answer:",d.get("answer"));print("Mode:",d.get("mode"),"| latency ms:",d.get("latency_ms"))'
echo "== Agent: money moves only with confirmation =="
curl -s --max-time 90 -X POST $APP/agent -H 'Content-Type: application/json' -d '{"message":"Transfer 200 dollars from CHQ-1001 to SAV-2002"}' \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print("Answer:",d.get("answer"));print("Tool calls:",d.get("tool_calls"))'
SCRIPT
"$ROOT/scripts/on-vm.sh" "bash -s" /tmp/app-test.sh
