#!/usr/bin/env bash
# Week 2: prove the private path to Gemini, from the test VM.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROJECT=$(gcloud config get-value project 2>/dev/null)
REGION=${REGION:-northamerica-northeast1}
MODEL=$(terraform -chdir="$ROOT/infra/week02-private-model" output -raw model)
"$ROOT/scripts/on-vm.sh" "PROJECT=$PROJECT REGION=$REGION MODEL=$MODEL bash -s" "$ROOT/scripts/prove-private.sh"
