# Secure Image Catalog — demo app

A deliberately-simple 3-tier app that is easy to demo and thematically maps
to the POC story (it catalogs container images and their CVE counts).

```
   browser ──▶  NGINX (frontend)  ──▶  FastAPI (api)  ──▶  PostgreSQL (db)
               React SPA              Python 3.12         Postgres 16
```

Every tier has **two** Dockerfiles:

| File                       | Base image                                   | Purpose                 |
|----------------------------|----------------------------------------------|-------------------------|
| `Dockerfile.chainguard`    | `cgr.dev/chainguard/*`                       | Chainguard flow         |
| `Dockerfile.baseline`      | `docker.io/library/*` (Debian/Ubuntu/Alpine) | Open-source flow        |

Push both sets into Artifactory, let Xray index them, then show the CVE delta.
See `../docs/demo-flow.md`.

## Local smoke test

```bash
# API
cd api && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
DATABASE_URL=sqlite:///./catalog.db uvicorn main:app --reload

# Frontend
cd frontend && npm install && npm run dev
```

## Build both flows (via Artifactory)

```bash
# from repo root
./scripts/build-and-push.sh chainguard
./scripts/build-and-push.sh baseline
```
