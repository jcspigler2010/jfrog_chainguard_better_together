# Demo flow — JFrog + Chainguard "Better Together"

A 20-minute runbook for showing that **starting with Chainguard drastically
reduces time-to-remediation** versus Iron Bank / open-source baselines,
*without* changing anything about your JFrog pipeline.

## Narrative

> "Same cluster. Same Artifactory. Same CI. Same app. Only the base image
> changes. Here's what Xray says about each."

Two flows, run back-to-back:

1. **Flow A — Chainguard** — build catalog-api & catalog-frontend from
   `cgr.dev/chainguard/*` bases, push to Artifactory, scan, deploy. Show ~0
   CVEs in Xray, near-daily rebuilds mean any new CVE is closed in hours.
2. **Flow B — Baseline** — exact same sources, rebuilt from `python:3.12-slim`
   and `node:20-bookworm` / `nginx:1.27`. Show the Xray report with dozens of
   highs + mediums, many waiting on upstream distro patches.

## Prereqs (one-time)

| Step | Where | Command |
|------|-------|---------|
| Install Artifactory | workstation | `./jfrog/install-artifactory.sh` |
| Install Xray | workstation | `./jfrog/install-xray.sh` |
| Create repos | Artifactory UI | see `jfrog/README.md` |
| Enable Xray indexing | Xray UI | Indexed Resources → add `docker-*-local` |
| Create pull secret | target namespaces | see below |

```bash
for ns in catalog-cg catalog-bl; do
  kubectl create ns "$ns" 2>/dev/null || true
  kubectl -n "$ns" create secret docker-registry artifactory-pull \
    --docker-server="$ARTIFACTORY_HOST" \
    --docker-username="$ARTIFACTORY_USER" \
    --docker-password="$ARTIFACTORY_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
done
```

## The 20-minute demo

### 1. Show the app (2 min)
Open `https://catalog-cg.lab.local` and `https://catalog-bl.lab.local` in two
browser tabs. Point out they're byte-identical UIs. The whole story lives in
Xray.

### 2. Build Flow A — Chainguard (4 min)
```bash
export ARTIFACTORY_HOST=artifactory.lab.local
export ARTIFACTORY_USER=demo
export ARTIFACTORY_TOKEN=xxxxxxxx
./scripts/build-and-push.sh chainguard
```
Talk track while builds run:
* "Look at the Dockerfile — same app code, base is `cgr.dev/chainguard/python`."
* "These images ship daily from Chainguard; the CVE window is ~24h, not weeks."
* "Distroless — no shell, no package manager, smaller attack surface."

### 3. Build Flow B — Baseline (4 min)
```bash
./scripts/build-and-push.sh baseline
```
Same codebase, `python:3.12-slim` + `node:20-bookworm`. Bigger image, more
layers, more things Xray can find.

### 4. Let Xray chew (background, ~2 min)
While chatting, Xray indexes the new manifests. Refresh Artifactory → Packages
until the scan badge appears.

### 5. The money shot — CVE delta (3 min)
```bash
./scripts/compare-cves.sh
```
Expected shape (your numbers will vary):

```
IMAGE                     FLAVOR       HIGH   MED    LOW
catalog-api               chainguard   0      0      1
catalog-api               baseline     11     34     78
catalog-frontend          chainguard   0      0      0
catalog-frontend          baseline     7      22     41
```

Open the Xray UI side-by-side too — the baseline report will have pages of
`glibc`, `openssl`, `libsystemd` findings; chainguard's will be empty or a
single informational item.

### 6. Remediation story (4 min)
Pick one nasty CVE in the baseline report (usually a `glibc` CVSS 9.x).
* Baseline: "waiting on Debian point release → days to weeks."
* Chainguard: `docker pull cgr.dev/chainguard/python:latest` — already
  patched. Rebuild:
  ```bash
  ./scripts/build-and-push.sh chainguard
  ```
  Rerun `compare-cves.sh` → still zero. **Minutes, not weeks.**

### 7. Deploy both side-by-side (3 min)
```bash
helm install catalog-cg ./helm/demo-app \
  -n catalog-cg --create-namespace \
  --set flavor=chainguard \
  --set registry.host=$ARTIFACTORY_HOST \
  --set ingress.host=catalog-cg.lab.local

helm install catalog-bl ./helm/demo-app \
  -n catalog-bl --create-namespace \
  --set flavor=baseline \
  --set registry.host=$ARTIFACTORY_HOST \
  --set ingress.host=catalog-bl.lab.local
```
Show `kubectl get pods -A -l part-of=secure-image-catalog` — both are
running, both are healthy, both are pulled through Artifactory. Only the
CVE posture differs.

### 8. Wrap (takeaways)

* JFrog Artifactory stays the system of record — no pipeline changes.
* Swapping the base image is a one-line PR.
* Xray still does the gating. Chainguard just gives it nothing to complain
  about.
* Remediation SLAs collapse from "next patch Tuesday" to "next daily rebuild."
