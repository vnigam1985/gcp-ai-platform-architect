#!/usr/bin/env bash
# Build an image with Cloud Build into the lab's Artifact Registry. No Docker needed.
# Usage: build-image.sh gateway|app|gate [tag]
set -euo pipefail
WHAT=$1; TAG=${2:-v1}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REG=$(terraform -chdir="$ROOT/infra/week04-ai-gateway" output -raw registry)
case "$WHAT" in
  gateway) gcloud builds submit "$ROOT/infra/week04-ai-gateway/gateway" --tag "$REG/ai-gateway:$TAG" ;;
  app)     (cd "$ROOT" && gcloud builds submit . --config=/dev/stdin <<YAML
steps:
- name: gcr.io/cloud-builders/docker
  args: [build, -t, $REG/maple-bank-assistant:$TAG, -f, app/Dockerfile, .]
images: [$REG/maple-bank-assistant:$TAG]
YAML
) ;;
  gate)    (cd "$ROOT" && gcloud builds submit . --config=/dev/stdin <<YAML
steps:
- name: gcr.io/cloud-builders/docker
  args: [build, -t, $REG/release-gate:latest, -f, infra/week08-cicd/gate/Dockerfile, .]
images: [$REG/release-gate:latest]
YAML
) ;;
  *) echo "usage: $0 gateway|app|gate [tag]"; exit 1 ;;
esac
