#!/usr/bin/env bash
# Week 5: create the bank app's team key on the gateway (from the VM, because the
# gateway is internal-only) and store it in Secret Manager for Cloud Run.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W4="$ROOT/infra/week04-ai-gateway"; W5="$ROOT/infra/week05-private-app"
GW=$(terraform -chdir="$W4" output -raw gateway_url)
MASTER=$(gcloud secrets versions access latest --secret "$(terraform -chdir="$W4" output -raw master_key_secret)")
SECRET=$(terraform -chdir="$W5" output -raw team_key_secret)
KEY="sk-team-retail-bank-$(openssl rand -hex 8)"
cat > /tmp/mk-key.sh <<SCRIPT
curl -s -o /dev/null -w '%{http_code}' --max-time 90 $GW/key/generate -H "Authorization: Bearer $MASTER" -H "Content-Type: application/json" \
  -d '{"key":"$KEY","key_alias":"retail-banking-app","models":["bank-chat"],"rpm_limit":60,"tpm_limit":20000,"metadata":{"team":"retail-banking"}}'
SCRIPT
code=$("$ROOT/scripts/on-vm.sh" "bash -s" /tmp/mk-key.sh | tail -c 3)
[ "$code" = "200" ] || { echo "Gateway returned $code"; exit 1; }
printf '%s' "$KEY" | gcloud secrets versions add "$SECRET" --data-file=- > /dev/null
rm -f /tmp/mk-key.sh
echo "Team key created on the gateway and stored in Secret Manager: $SECRET"
