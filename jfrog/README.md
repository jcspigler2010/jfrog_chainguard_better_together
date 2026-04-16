# JFrog Platform on RKE2

Deploys **JFrog Artifactory** (OCI registry + generic repos) and optionally
**JFrog Xray** (vulnerability scanning) onto an RKE2 cluster via the official
JFrog Helm charts.

Xray is what lets you actually *show* the CVE delta between Chainguard and
baseline images, so it is strongly recommended for this POC.

## Prereqs

* RKE2 cluster up (`kubectl get nodes` returns Ready)
* `helm` v3.12+ on your workstation
* A default `StorageClass` (RKE2 ships `local-path` out of the box; for prod
  use Longhorn / Rook / vSphere CSI / etc.)
* An ingress controller OR a MetalLB pool if you want a `LoadBalancer` svc.
  Scripts below assume NGINX ingress + MetalLB; adjust to taste.
* Valid JFrog license (trial works). Drop it at `jfrog/artifactory.lic` before
  running `install-artifactory.sh`, or set `ARTIFACTORY_LICENSE` env var.

## What gets installed

| Component    | Namespace  | Chart                                 | Access                     |
|--------------|------------|---------------------------------------|----------------------------|
| Artifactory  | `jfrog`    | `jfrog/artifactory`                   | `https://artifactory.<DOMAIN>` |
| Xray         | `jfrog`    | `jfrog/xray`                          | via Artifactory UI         |
| PostgreSQL   | `jfrog`    | bundled sub-chart                     | internal only              |

## Install

```bash
# 1. Add the JFrog Helm repo
helm repo add jfrog https://charts.jfrog.io
helm repo update

# 2. Set your domain + master key + join key BEFORE running
export JFROG_DOMAIN=jfrog.lab.local
export MASTER_KEY=$(openssl rand -hex 16)
export JOIN_KEY=$(openssl rand -hex 16)

# 3. Install
./install-artifactory.sh
./install-xray.sh        # optional but recommended
```

## What to configure inside Artifactory after install

1. Log in as `admin` / `password` and change the password immediately.
2. Apply the license (Administration → License).
3. Create repositories used by the demo app:
   * **Docker (local):** `docker-chainguard-local` &rarr; stores Chainguard-based images
   * **Docker (local):** `docker-baseline-local`   &rarr; stores Iron Bank / Ubuntu-based images
   * **Docker (remote):** `docker-chainguard-remote` &rarr; proxies `cgr.dev/chainguard`
   * **Docker (remote):** `dockerhub-remote`        &rarr; proxies `docker.io`
   * **Docker (virtual):** `docker-virtual`         &rarr; aggregates the above
4. In Xray: enable indexing for both `docker-chainguard-local` and
   `docker-baseline-local`. That is what produces the side-by-side CVE report
   you will demo.

See `../docs/demo-flow.md` for the full end-to-end walkthrough.
