# 0033. Logical Identity Equivalence and Deployment-Locus Vocabulary

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Sixth reviewer (LucioIT L2) proposed "dual-posture edge / Logical Identity
Equivalence" and introduced S-Side/C-Side vocabulary in a different sense than the architecture
uses. Cluster 5 self-audit surfaced 8 hidden defects around vocabulary overload and the absence of
a deployment-locus taxonomy. This ADR names the principle and disambiguates the vocabularies.

## Context

The architecture uses "S-side / C-side" in Rule 17 (substitution-authority semantics): S-side means
a dependency is substitution-authoritative (platform-owned, swapped by the platform across waves);
C-side means consumer-authoritative (downstream, adapts to the platform's contract).

LucioIT used "S-side / C-side" to mean _server-side_ (cloud-hosted) vs _client-side_ (device-resident)
— a deployment-locus meaning. These are orthogonal concepts; merging them would create a terminology
collision.

No "Logical Identity Equivalence" principle is named anywhere in the codebase. The architecture has
no explicit vocabulary for the three deployment loci relevant to a modern multi-modal agent platform.

## Decision Drivers

- Sixth reviewer L2: deployment-locus disambiguation is legitimate; implementation post-W4 scope.
- Hidden defect 5.2: S-Side/C-Side overloaded — Rule 17 semantics must not be confused with deployment locus.
- Hidden defect 5.1: "Logical Identity Equivalence" principle unnamed; needed for A2A federation ADR-0016.
- `ARCHITECTURE.md:12-15` "Not in scope" mentions "on-device models" but doesn't name the deployment locus.

## Considered Options

1. **Name the principle and vocabulary; defer implementation post-W4** (this decision).
2. **Add `edge` posture variant** — rejected: would explode 3-posture matrix to 4+, with operational complexity before any edge deployment exists.
3. **Defer entirely** — leaves the vocabulary collision unresolved for future reviewers.

## Decision Outcome

**Chosen option:** Option 1.

### Logical Identity Equivalence (§4 #30)

**Definition:** An agent running at any deployment locus (S-Cloud, S-Edge, C-Device) that exposes
the same `AgentCard` capability descriptor and implements the same `Skill` SPI contract is
_logically equivalent_ to its counterpart at any other locus. The platform routes to any
logically-equivalent agent based on latency, cost, and data-residency constraints — the calling
Run does not need to know which locus was selected.

This principle is the foundation for future A2A federation (ADR-0016) and edge deployment.

### Deployment-locus vocabulary (§4 #30)

| Term | Meaning | Scope |
|---|---|---|
| **S-Cloud** | Agent runtime hosted in a cloud datacenter (primary posture) | in-scope W0–W4 |
| **S-Edge** | Agent runtime hosted at an operator-controlled edge node (CDN PoP, on-prem server) | named, post-W4 implementation |
| **C-Device** | Agent runtime hosted on-device (mobile, embedded, browser WASM) | named, post-W4 implementation |

### Preserved vocabulary (Rule 17)

**S-side / C-side** in Rule 17 retains its existing substitution-authority meaning:
- **S-side** = substitution-authoritative (the platform controls which implementation is wired; callers adapt).
- **C-side** = consumer-authoritative (consumers provide implementations; the platform adapts).

These are orthogonal to deployment locus. A VETTED Java Skill is C-side (consumer-provided) but may
run at S-Cloud or S-Edge. Do not conflate these two vocabularies.

### Out of scope (explicitly rejected)

- **`edge` posture variant** — deployment locus and operational posture are different axes. The
  3-posture model (dev / research / prod) is preserved. An S-Edge deployment may run in `prod` posture.
- **W0–W4 edge-deployment scheduling** — no wave budget; ADR-0016 covers post-W4 A2A; this ADR only names the principle.

### Consequences

**Positive:**
- Vocabulary collision eliminated — future reviewers and contributors understand the Rule 17 / deployment-locus distinction.
- Logical Identity Equivalence is the foundation for multi-locus federation work post-W4.
- `edge` posture explosion is explicitly rejected with rationale.

**Negative:**
- S-Edge and C-Device loci are named but have no implementation commitment before post-W4.

## References

- Sixth reviewer L2: `docs/reviews/2026-05-12-architecture-LucioIT-wave-1-request.en.md`
- ADR-0016: A2A Federation (reversal trigger updated to reference this ADR)
- ADR-0034: Memory & Knowledge Taxonomy (uses deployment-locus vocabulary)
- Rule 17 (substitution-authority S-side/C-side — preserved unchanged)
- `architecture-status.yaml` row: `logical_identity_equivalence`
