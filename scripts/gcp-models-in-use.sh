#!/usr/bin/env bash
# Week 8: list the models the platform actually serves, as JSON for
# check_model_inventory.py. Source of truth: the gateway's Cloud Run config.
set -euo pipefail
REGION=${REGION:-northamerica-northeast1}
gcloud run services describe ai-gateway --region "$REGION" --format=json | python3 -c '
import json, sys
svc = json.load(sys.stdin)
env = {e["name"]: e.get("value") for e in svc["spec"]["template"]["spec"]["containers"][0].get("env", [])}
model = (env.get("BANK_MODEL") or "").removeprefix("vertex_ai/")
loc = env.get("VERTEX_LOCATION", "?")
print(json.dumps([{"deployment_name": "gateway:bank-chat", "provider_model": model, "deployment_type": "regional:" + loc}], indent=2))'
