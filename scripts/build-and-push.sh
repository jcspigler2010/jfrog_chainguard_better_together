#!/usr/bin/env bash
# Build both tiers of the demo app using the selected flavor and push into
# Artifactory. Tag == flavor ("chainguard" or "baseline") so the Helm chart
# can toggle between them with a single value flip.
#
# Usage:
#   export ARTIFACTORY_HOST=artifactory.lab.local
#   export ARTIFACTORY_USER=ci
#   export ARTIFACTORY_TOKEN=...        # identity token from Artifactory UI
#   ./scripts/build-and-push.sh chainguard
#   ./scripts/build-and-push.sh baseline
set -euo pipefail

FLAVOR="${1:-}"
if [[ "$FLAVOR" != "chainguard" && "$FLAVOR" != "baseline" ]]; then
  echo "Usage: $0 {chainguard|baseline}" >&2
  exit 2
fi

: "${ARTIFACTORY_HOST:?set ARTIFACTORY_HOST}"
: "${ARTIFACTORY_USER:?set ARTIFACTORY_USER}"
: "${ARTIFACTORY_TOKEN:?set ARTIFACTORY_TOKEN}"

# Local-repo keys (created in Artifactory UI). Pushing to *-local is required;
# pulling uses the virtual repo which aggregates both locals.
REPO_KEY="docker-${FLAVOR}-local"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Docker login to $ARTIFACTORY_HOST"
echo "$ARTIFACTORY_TOKEN" | docker login "$ARTIFACTORY_HOST" \
  -u "$ARTIFACTORY_USER" --password-stdin

build_and_push() {
  local tier="$1" context="$2"
  local image="$ARTIFACTORY_HOST/$REPO_KEY/catalog-$tier:$FLAVOR"
  echo "==> [$tier] build $image"
  docker build \
    -f "$context/Dockerfile.$FLAVOR" \
    -t "$image" \
    "$context"
  echo "==> [$tier] push $image"
  docker push "$image"
}

build_and_push api      "$REPO_ROOT/app/api"
build_and_push frontend "$REPO_ROOT/app/frontend"

echo
echo "==> Done. Images pushed:"
echo "    $ARTIFACTORY_HOST/$REPO_KEY/catalog-api:$FLAVOR"
echo "    $ARTIFACTORY_HOST/$REPO_KEY/catalog-frontend:$FLAVOR"
echo
echo "Next: wait for Xray indexing, then run scripts/compare-cves.sh"
