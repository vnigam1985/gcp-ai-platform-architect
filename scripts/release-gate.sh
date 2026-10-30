#!/usr/bin/env bash
# Week 8: run the release gate job (inside the VPC) and show its output.
# Exit 0 = GO, non-zero = NO-GO.
set -uo pipefail
REGION=${REGION:-northamerica-northeast1}
EXEC=$(gcloud run jobs execute release-gate --region "$REGION" --wait --format='value(metadata.name)' 2>/dev/null); rc=$?
[ -n "$EXEC" ] || EXEC=$(gcloud run jobs executions list --job release-gate --region "$REGION" --limit 1 --format='value(metadata.name)')
sleep 5
gcloud logging read "resource.type=\"cloud_run_job\" AND labels.\"run.googleapis.com/execution_name\"=\"$EXEC\"" \
  --format='value(textPayload)' --order=asc --limit 50 | sed '/^$/d'
exit $rc
