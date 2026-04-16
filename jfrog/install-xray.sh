#!/usr/bin/env bash
# Deploy JFrog Xray after Artifactory is healthy. Reuses the joinKey Secret
# created by install-artifactory.sh.
set -euo pipefail

NAMESPACE="${NAMESPACE:-jfrog}"
RELEASE="${RELEASE:-xray}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JOIN_KEY="$(kubectl -n "$NAMESPACE" get secret jfrog-keys \
  -o jsonpath='{.data.join-key}' | base64 -d)"
MASTER_KEY="$(kubectl -n "$NAMESPACE" get secret jfrog-keys \
  -o jsonpath='{.data.master-key}' | base64 -d)"

if [[ -z "$JOIN_KEY" ]]; then
  echo "Could not find join-key in secret $NAMESPACE/jfrog-keys. Run install-artifactory.sh first." >&2
  exit 1
fi

helm repo add jfrog https://charts.jfrog.io >/dev/null 2>&1 || true
helm repo update jfrog >/dev/null

echo "==> Installing/upgrading Xray"
helm upgrade --install "$RELEASE" jfrog/xray \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/values-xray.yaml" \
  --set common.joinKey="$JOIN_KEY" \
  --set common.masterKey="$MASTER_KEY" \
  --wait --timeout 20m

echo "==> Xray up. Link Xray in Artifactory UI: Administration -> Xray -> Getting Started."
