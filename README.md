# JFrog + Chainguard — Better Together POC

A working proof-of-concept that stands up **JFrog Artifactory** (+ optional
**Xray**) on an RKE2 cluster, then deploys a small 3-tier demo application
**twice** — once built from **Chainguard** base images, once from standard
open-source / Iron-Bank-style baselines — so you can show the CVE and
time-to-remediation delta with real Xray scans.

## Repo layout

```
.
├── jfrog/              # Helm values + install scripts for Artifactory & Xray
├── app/
│   ├── api/            # FastAPI middle tier  (Dockerfile.chainguard + .baseline)
│   ├── frontend/       # React + NGINX SPA    (Dockerfile.chainguard + .baseline)
│   └── db/             # Postgres init.sql
├── helm/demo-app/      # Helm chart that deploys the 3 tiers from Artifactory
├── scripts/
│   ├── build-and-push.sh   # build both tiers for a flavor and push to Artifactory
│   ├── compare-cves.sh     # pull Xray summaries and print a side-by-side table
│   └── seed-demo-data.sh   # preload the running UI with demo rows
└── docs/
    ├── architecture.md
    ├── demo-flow.md              # 20-minute runbook
    └── remediation-comparison.md
```

## TL;DR

```bash
# 1. Deploy JFrog
export JFROG_DOMAIN=artifactory.lab.local
export MASTER_KEY=$(openssl rand -hex 16)
export JOIN_KEY=$(openssl rand -hex 16)
./jfrog/install-artifactory.sh
./jfrog/install-xray.sh                     # optional but worth it

# 2. In the Artifactory UI create repos (see jfrog/README.md):
#    docker-chainguard-local, docker-baseline-local, docker-virtual, etc.

# 3. Build & push both flavors
export ARTIFACTORY_HOST=$JFROG_DOMAIN
export ARTIFACTORY_USER=ci
export ARTIFACTORY_TOKEN=...
./scripts/build-and-push.sh chainguard
./scripts/build-and-push.sh baseline

# 4. Deploy two copies of the demo app, one per flavor
helm install catalog-cg ./helm/demo-app -n catalog-cg --create-namespace \
  --set flavor=chainguard --set registry.host=$ARTIFACTORY_HOST \
  --set ingress.host=catalog-cg.lab.local
helm install catalog-bl ./helm/demo-app -n catalog-bl --create-namespace \
  --set flavor=baseline   --set registry.host=$ARTIFACTORY_HOST \
  --set ingress.host=catalog-bl.lab.local

# 5. Show the CVE delta
./scripts/compare-cves.sh
```

Full walkthrough: **[docs/demo-flow.md](docs/demo-flow.md)**.

## The demo app: "Secure Image Catalog"

A deliberately-tiny 3-tier app (browser → NGINX/React → FastAPI → PostgreSQL)
that happens to *catalog container images and their CVE counts* — so the
subject matter mirrors the POC story. Same source, built twice, deployed
twice, scanned by the same Xray. The only variable is the base image.

## What this POC proves

1. JFrog Artifactory is the registry of record — no pipeline changes.
2. Swapping a base image from `python:3.12-slim` to `cgr.dev/chainguard/python`
   is a single-line Dockerfile edit.
3. Xray's own scan report collapses from "pages of highs" to "empty".
4. When a new CVE drops, Chainguard ships a patched base image in hours;
   you `docker pull`, rebuild, and you're clean. No waiting on Debian point
   releases or Iron Bank quarterly hardening cycles.

See **[docs/remediation-comparison.md](docs/remediation-comparison.md)** for
the side-by-side.
