#!/usr/bin/env bash
# Run a command on the test VM over IAP (the VM has no external IP).
# Usage: on-vm.sh "<command>" [file to send on stdin]
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W2="$ROOT/infra/week02-private-model"
VM=$(terraform -chdir="$W2" output -raw jumpbox); ZONE=$(terraform -chdir="$W2" output -raw zone)
# Start it if the evening schedule stopped it.
[ "$(gcloud compute instances describe "$VM" --zone "$ZONE" --format='value(status)')" = "RUNNING" ] || gcloud compute instances start "$VM" --zone "$ZONE" --quiet
if [ -n "${2:-}" ]; then
  gcloud compute ssh "$VM" --zone "$ZONE" --tunnel-through-iap --quiet --command "$1" < "$2"
else
  gcloud compute ssh "$VM" --zone "$ZONE" --tunnel-through-iap --quiet --command "$1"
fi
