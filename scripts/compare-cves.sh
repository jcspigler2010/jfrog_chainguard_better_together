#!/usr/bin/env bash
# Pull Xray scan summaries for the four demo-app images and print a
# side-by-side CVE comparison. This is the money shot of the POC.
#
# Usage:
#   export ARTIFACTORY_HOST=artifactory.lab.local
#   export ARTIFACTORY_USER=admin
#   export ARTIFACTORY_TOKEN=...
#   ./scripts/compare-cves.sh
#
# Xray API ref:
#   POST /xray/api/v1/summary/artifact
#     body: {"paths":["docker-<flavor>-local/catalog-<tier>/<flavor>/manifest.json"]}
set -euo pipefail

: "${ARTIFACTORY_HOST:?set ARTIFACTORY_HOST}"
: "${ARTIFACTORY_USER:?set ARTIFACTORY_USER}"
: "${ARTIFACTORY_TOKEN:?set ARTIFACTORY_TOKEN}"

base="https://$ARTIFACTORY_HOST"

summary() {
  local flavor="$1" tier="$2"
  local path="docker-${flavor}-local/catalog-${tier}/${flavor}/manifest.json"
  curl -s -u "$ARTIFACTORY_USER:$ARTIFACTORY_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"paths\":[\"$path\"]}" \
    "$base/xray/api/v1/summary/artifact"
}

extract() {
  # $1 = json, $2 = severity
  echo "$1" | python3 -c "
import json, sys
doc = json.load(sys.stdin)
sev = sys.argv[1]
total = 0
for a in doc.get('artifacts', []):
  for i in a.get('issues', []):
    if i.get('severity','').lower() == sev:
      total += 1
print(total)
" "$2"
}

printf '%-25s %-12s %-6s %-6s %-6s\n' "IMAGE" "FLAVOR" "HIGH" "MED" "LOW"
printf '%-25s %-12s %-6s %-6s %-6s\n' "-------------------------" "------------" "------" "------" "------"

for tier in api frontend; do
  for flavor in chainguard baseline; do
    j="$(summary "$flavor" "$tier")"
    h="$(extract "$j" high)"
    m="$(extract "$j" medium)"
    l="$(extract "$j" low)"
    printf '%-25s %-12s %-6s %-6s %-6s\n' "catalog-$tier" "$flavor" "$h" "$m" "$l"
  done
done
