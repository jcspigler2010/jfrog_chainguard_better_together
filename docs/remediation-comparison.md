# Remediation comparison

Illustrative numbers for the demo deck. Replace with actuals once your
Artifactory + Xray are running real scans. Dates below are the *typical*
windows observed, not guarantees.

| Dimension                         | Iron Bank / Debian baseline        | Chainguard                |
|-----------------------------------|------------------------------------|---------------------------|
| Image size (catalog-api)          | ~180 MB                            | ~55 MB                    |
| Packages in image                 | 300+                               | 10–20                     |
| Shell / package manager present?  | yes (`bash`, `apt`, `dpkg`)        | no                        |
| Runs as root by default?          | yes                                | no                        |
| Typical high-severity CVEs at build | 8–15                             | 0                         |
| Typical medium-severity CVEs       | 25–50                             | 0–1                       |
| Base image refresh cadence        | weeks to months                    | daily                     |
| Time from CVE disclosure to patched base | days to weeks                 | hours                     |
| Pipeline changes to adopt         | n/a                                | one-line Dockerfile swap  |

## Why the gap exists

**Baseline** images carry a general-purpose Linux userland. Many of the
packages in them aren't used by the application at all, but they still show
up in every Xray scan, and they still have to be patched by the upstream
distro before you can pull a clean image. You are coupled to that patch
cadence.

**Chainguard** images are built from the component up on a minimal, distroless
base with only what the app needs. Packages are patched at the source and
rebuilt daily, so you can pull a clean `:latest` within hours of most CVE
disclosures.

## How to quote the numbers during the demo

Don't read this table out loud — let Xray's own report do the talking (run
`scripts/compare-cves.sh`). Use this page as a leave-behind or appendix in
your deck.
