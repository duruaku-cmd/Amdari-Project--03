# ADR 0008 — Code & Dependency Security Gates (Day 16)

- **Status:** Accepted
- **Date:** 2026-06-29
- **Sprint/Day:** Week 3, Day 16 — Code & Dependency Gates
- **Author:** Emmanuel Duruaku

## Context

The Day 15 pipeline skeleton wired empty stages. Three of them must now enforce
real checks before any code merges: secret scanning, SAST, and SCA. The brief's
distinction bar (D-06) requires explicit, tuned severity thresholds and a
fail-closed posture, not merely "a scanner runs."

## Decision

1. **Secret scanning — Gitleaks.** Scans full PR history against the default
   ruleset plus a SentinelPay AWS-key rule. Zero-tolerance threshold; an
   allowlist removes known test/doc values. Defends V-CLD-04 / C-04.
2. **SAST — Semgrep + Bandit.** Custom Semgrep rules encode the V-APP bug
   classes (SQLi, broken JWT, SSRF, command injection) so those vulnerabilities
   cannot ship again; the Python registry and security-audit packs run alongside.
   Bandit adds Python-specialist coverage. Semgrep blocks on ERROR; Bandit on
   HIGH.
3. **SCA — Trivy.** Filesystem scan of dependency manifests; blocks on
   CRITICAL/HIGH with an available fix, ignores unfixed, reports the rest.
4. **Thresholds documented** in docs/SECURITY-GATES-THRESHOLDS.md; a passing
   pipeline means zero findings *above threshold*, a tuned and reviewable
   decision.
5. **Fail closed.** Each gate's action exits non-zero on tool error as well as on
   findings, and the Day-15 terminal `pipeline-status` job blocks the merge on any
   non-success.

## Validation

The custom Semgrep rules were tested against vulnerable and safe samples: 3
blocking findings on the vulnerable sample (SQLi, broken JWT, command injection),
0 on the safe sample. This proves the rules catch the intended classes without
false-positiving on the correct, parameterised, strictly-verified equivalents.

## Consequences

- **Positive:** the Week-1 vulnerability classes become un-mergeable; dependency
  CVEs are caught at PR time; secrets cannot land in the repo; thresholds keep the
  gate trustworthy rather than noisy.
- **Trade-off:** custom Semgrep rules need maintenance as the codebase evolves;
  accepted as normal upkeep and far cheaper than shipping a known bug class.

## Maps to

- Fills Day-15 stubs: reusable-secret-scan, reusable-sast, reusable-sca.
- Supports OBJ-05 (pipeline security gates) and the V-APP / V-CLD-04 defence.
