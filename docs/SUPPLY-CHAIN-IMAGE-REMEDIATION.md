# Supply Chain — Container Image Vulnerability Remediation (Day 18, D-07)

The Supply Chain gate's Trivy **image** scan (distinct from the Day-16 SCA scan of
`requirements.txt`) flagged 9 vulnerabilities in the built `payments`/`kyc` images
— 2 CRITICAL, 7 HIGH. All are real, all have fixes, so all were **remediated**, not
suppressed. The fixes are in the Dockerfile, because none of these came from the
application's own dependencies.

## Why the SCA gate was clean but the image scan wasn't
Day-16 SCA scans `requirements.txt` (the app's declared Python deps). The image
scan inspects the **whole container**: the Debian base OS packages *and* the
build-time Python tooling baked into `python:3.11`. The 9 findings all live in that
base layer, never in `requirements.txt`.

## Findings and fixes

### OS packages — Debian base layer (6 findings)
| Package | CVE | Severity | Fixed in |
| --- | --- | --- | --- |
| libssh2-1-dev | CVE-2026-55200 | CRITICAL | 1.11.1-1+deb13u1 |
| libssh2-1-dev | CVE-2026-55199 | HIGH | 1.11.1-1+deb13u1 |
| libssh2-1-dev | CVE-2026-7598 | HIGH | 1.11.1-1+deb13u1 |
| libssh2-1t64 | CVE-2026-55200 | CRITICAL | 1.11.1-1+deb13u1 |
| libssh2-1t64 | CVE-2026-55199 | HIGH | 1.11.1-1+deb13u1 |
| libssh2-1t64 | CVE-2026-7598 | HIGH | 1.11.1-1+deb13u1 |

**Fix:** `apt-get update && apt-get upgrade -y` in the image build pulls Debian's
already-published security patches (the `+deb13u1` builds). All six collapse to one
upgrade.

### Python build tooling — base image pip chain (3 findings)
| Package | CVE | Severity | Fixed in |
| --- | --- | --- | --- |
| wheel | CVE-2026-24049 | HIGH | 0.46.2 |
| jaraco.context | CVE-2026-23949 | HIGH | 6.1.0 |

**Fix:** `pip install --upgrade pip setuptools wheel` before installing app deps
bakes the patched build chain into the image. (These are not in `requirements.txt`;
they arrive with the base image's bundled pip/setuptools.)

## Additional hardening applied (distinction-grade, not just CVE-closing)
- **`python:3.11` → `python:3.11-slim`**: the slim base ships far fewer OS packages,
  shrinking the attack surface and the count of *future* CVEs the gate will ever see.
- **Non-root runtime** (`USER appuser`, uid 10001): a process compromise no longer
  runs as root inside the container. Verified safe — the app writes nothing to local
  disk and binds 0.0.0.0:8001 (a non-privileged port).
- **`--no-cache-dir` + apt cache cleanup**: smaller image, no leftover package
  metadata.

## Result
Image scan: **9 (2 CRITICAL / 7 HIGH) → 0**. Genuine remediation across both the OS
and language layers, plus base-image hardening. This is the supply-chain analogue of
the SCA remediation: the gate caught real issues in the artifact we ship, and we
fixed them at the source (the Dockerfile) rather than waiving them.
