#!/usr/bin/env bash
# Push a handful of rows into the running catalog API so the UI has content
# during a demo even if Xray hasn't produced numbers yet.
set -euo pipefail

: "${CATALOG_URL:?set CATALOG_URL, e.g. https://catalog-cg.lab.local}"

post() {
  curl -sk -X POST "$CATALOG_URL/api/images" \
    -H 'Content-Type: application/json' \
    -d "$1" >/dev/null
}

post '{"name":"catalog-api","tag":"chainguard","base_flavor":"chainguard","cves_high":0,"cves_medium":0,"cves_low":1}'
post '{"name":"catalog-api","tag":"baseline","base_flavor":"baseline","cves_high":11,"cves_medium":34,"cves_low":78}'
post '{"name":"catalog-frontend","tag":"chainguard","base_flavor":"chainguard","cves_high":0,"cves_medium":0,"cves_low":0}'
post '{"name":"catalog-frontend","tag":"baseline","base_flavor":"baseline","cves_high":7,"cves_medium":22,"cves_low":41}'
post '{"name":"postgres","tag":"chainguard","base_flavor":"chainguard","cves_high":0,"cves_medium":1,"cves_low":2}'
post '{"name":"postgres","tag":"baseline","base_flavor":"baseline","cves_high":4,"cves_medium":18,"cves_low":37}'

echo "Seeded $CATALOG_URL"
