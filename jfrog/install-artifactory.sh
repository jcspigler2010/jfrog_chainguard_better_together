#!/usr/bin/env bash
# Deploy JFrog Artifactory onto the current kube-context (RKE2).
#
# Usage:
#   export JFROG_DOMAIN=artifactory.lab.local
#   export MASTER_KEY=$(openssl rand -hex 16)
#   export JOIN_KEY=$(openssl rand -hex 16)
#   ./install-artifactory.sh
#
# Optional:
#   ARTIFACTORY_LICENSE   path to .lic file (will be stashed in a Secret)
#   NAMESPACE             default: jfrog
#   RELEASE               default: artifactory
set -euo pipefail

: "${JFROG_DOMAIN:?set JFROG_DOMAIN (e.g. artifactory.lab.local)}"
: "${MASTER_KEY:?set MASTER_KEY (openssl rand -hex 16)}"
: "${JOIN_KEY:?set JOIN_KEY (openssl rand -hex 16)}"
NAMESPACE="${NAMESPACE:-jfrog}"
RELEASE="${RELEASE:-artifactory}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Ensuring namespace $NAMESPACE"
kubectl apply -f "$SCRIPT_DIR/namespace.yaml"

echo "==> Adding jfrog helm repo"
helm repo add jfrog https://charts.jfrog.io >/dev/null 2>&1 || true
helm repo update jfrog >/dev/null

# Persist the keys so Xray install (and later restarts) can re-use them.
kubectl -n "$NAMESPACE" create secret generic jfrog-keys \
  --from-literal=master-key="$MASTER_KEY" \
  --from-literal=join-key="$JOIN_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

if [[ -n "${ARTIFACTORY_LICENSE:-}" && -f "$ARTIFACTORY_LICENSE" ]]; then
  echo "==> Stashing license into Secret artifactory-license"
  kubectl -n "$NAMESPACE" create secret generic artifactory-license \
    --from-file=artifactory.lic="$ARTIFACTORY_LICENSE" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "==> Installing/upgrading Artifactory"
helm upgrade --install "$RELEASE" jfrog/artifactory \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/values-artifactory.yaml" \
  --set artifactory.masterKey="$MASTER_KEY" \
  --set artifactory.joinKey="$JOIN_KEY" \
  --set ingress.hosts[0]="$JFROG_DOMAIN" \
  --set ingress.tls[0].hosts[0]="$JFROG_DOMAIN" \
  --wait --timeout 20m

echo
echo "==> Artifactory is up at: https://$JFROG_DOMAIN"
echo "    Initial login:  admin / password   (CHANGE IMMEDIATELY)"
echo "    Apply license, then see docs/demo-flow.md for repo setup."
