# Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          RKE2 cluster                                │
│                                                                      │
│  ┌──────────────────────────┐     ┌───────────────────────────────┐  │
│  │ namespace: jfrog         │     │ namespace: catalog-cg         │  │
│  │                          │     │                               │  │
│  │ ┌─────────────┐          │     │ ┌───────────┐  ┌───────────┐  │  │
│  │ │ Artifactory │          │     │ │ frontend  │  │  api      │  │  │
│  │ │  + nginx    │◀────────┐│     │ │ nginx     │─▶│ fastapi   │  │  │
│  │ └─────────────┘         ││     │ │(chainguard│  │(chainguard│  │  │
│  │       ▲                 ││     │ └───────────┘  └─────┬─────┘  │  │
│  │       │ stores OCI      ││     │                      ▼        │  │
│  │       │                 ││     │                ┌──────────┐   │  │
│  │ ┌─────────────┐         ││     │                │ postgres │   │  │
│  │ │ Xray        │         ││     │                └──────────┘   │  │
│  │ │ (scans)     │         ││     └───────────────────────────────┘  │
│  │ └─────────────┘         ││                                        │
│  │                         ││     ┌───────────────────────────────┐  │
│  │                         │└────▶│ namespace: catalog-bl         │  │
│  │                         │      │  same 3 tiers, baseline images│  │
│  │                         │      └───────────────────────────────┘  │
│  └─────────────────────────┘                                         │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
             ▲                                    ▲
             │ docker push                        │ HTTPS ingress
             │                                    │
       ┌─────┴─────┐                      ┌───────┴────────┐
       │  CI host  │                      │  Browser       │
       │ (Docker)  │                      │ (demo audience)│
       └───────────┘                      └────────────────┘
```

## Image provenance

Both flavors are **built locally**, pushed to Artifactory, and scanned by Xray.
The base layers differ:

* **chainguard flavor** — base is pulled from `cgr.dev/chainguard/*`
  (proxied through Artifactory's `docker-chainguard-remote`). Images are
  distroless, rootless, minimal, and refreshed daily.
* **baseline flavor** — base is `docker.io/library/*` (Debian/Ubuntu/Alpine).
  Representative of the "as shipped" state from most projects / Iron Bank
  hardening pipelines.

## Why two deployments side-by-side?

Helm chart `helm/demo-app` takes `flavor={chainguard|baseline}` — install it
twice into two namespaces. Visitors hit two URLs in parallel:

| URL                           | Namespace   | Images                |
|-------------------------------|-------------|-----------------------|
| `https://catalog-cg.lab.local` | `catalog-cg` | Chainguard-based      |
| `https://catalog-bl.lab.local` | `catalog-bl` | Debian/Alpine baseline|

They render identical UIs — the story is entirely in the CVE numbers Xray
reports for the images that back each one.
