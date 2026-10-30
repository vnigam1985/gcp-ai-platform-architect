#!/usr/bin/env bash
# Destroy every week of the lab, newest first.
set -euo pipefail
PROJECT=${1:?project id}; REGION=${2:-northamerica-northeast1}; PREFIX=${3:-aiplat}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
read -r -p "Destroy every week of the lab in project $PROJECT? Type DESTROY: " c
[ "$c" = "DESTROY" ] || { echo "Cancelled."; exit 1; }
declare -A EXTRA=( [week00-budget]="-var billing_account=x" [week06-security]="-var email=x@example.com" [week08-cicd]="-var github_repo=x/y" )
for d in week08-cicd week07-observability week06-security week05-private-app week04-ai-gateway week03-guardrails week02-private-model week01-landing-zone week00-budget; do
  if [ -s "$ROOT/infra/$d/terraform.tfstate" ]; then
    echo "== destroying $d"
    (cd "$ROOT/infra/$d" && terraform destroy -input=false -auto-approve -var project_id="$PROJECT" -var region="$REGION" -var prefix="$PREFIX" ${EXTRA[$d]:-})
  fi
done
echo "Done. The simplest way to be sure nothing is left: shut down the whole lab project (gcloud projects delete $PROJECT)."
