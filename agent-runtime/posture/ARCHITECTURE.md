# posture — AppPosture (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`posture/` owns the **single most-impactful design lever** in spring-ai-fin: the three-posture model (`dev` / `research` / `prod`). Every fail-closed vs fail-open decision in the platform reads from here.

Owns:

- `AppPosture` — enum `DEV / RESEARCH / PROD`
- `PostureGate` — consumer-facing helpers (`requiresStrict`, `requiresRealLLM`, `requiresJwt`, `requiresWorm`, `permitsInMemoryStore`, etc.)
- `Posture.fromEnv()` — single boot-time read

Does NOT own:

- Per-feature flags (deferred to v1.1+)
- Per-tenant overrides (a customer cannot override platform posture)
- Spring profile activation (handled via Spring's `@Profile` annotation tied to posture)

---

## 2. Three postures

```yaml
DEV:
  default: true (when APP_POSTURE unset)
  permits:
    - in-memory backends OK
    - missing tenant_id warns (not rejects)
    - JWT optional (anonymous claims accepted)
    - mock LLM provider permitted
    - WORM audit storage optional
  recommended_for:
    - local development
    - unit tests
    - smoke tests

RESEARCH:
  default: false
  enforces:
    - durable backends required
    - tenant_id required (rejected if missing)
    - JWT required (HMAC validated)
    - real LLM required (mock raises 503)
    - audit logged but WORM-anchoring optional
  recommended_for:
    - integration testing
    - research workloads with real-LLM but non-customer data
    - pre-production staging

PROD:
  default: false
  enforces:
    - all RESEARCH constraints
    - WORM-anchored audit required (S3 Object Lock or SeaweedFS WORM)
    - behaviour-version pinning honoured (if customer opted in)
    - PII redaction default-on
    - dual-approval workflow on PII decode
    - bias-audit cadence enforced (MAS FEAT)
  recommended_for:
    - regulated production deployment
    - customer-facing SLA tier
```

---

## 3. Consumer pattern (mandatory)

Consumers ask `posture.requires*()` rather than branch on posture name:

```java
// CORRECT
if (posture.requiresJwt()) { /* validate JWT */ }
if (posture.requiresStrict()) { throw new SpineCompletenessException(...); }

// WRONG — couples consumer to posture name
if (posture == AppPosture.PROD) { /* ... */ }
```

This decouples consumers from posture taxonomy. Adding a new posture (e.g., `STAGING`) requires updating `requires*()` helpers in one place; consumers don't change.

---

## 4. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Three postures, not two** | dev / research / prod | Two postures conflate "research workloads" with "regulated prod" |
| **AD-2: Boot-time read, not per-call** | `Posture.fromEnv()` once in bootstrap | Avoids re-reading env on hot path; consistent across request lifetime |
| **AD-3: Consumer asks `requires*()`** | Don't branch on posture name | Decouples; new posture = update helpers, not consumers |
| **AD-4: Posture is a JVM-process property** | Not per-tenant; not per-request | Different postures = different deployments; no tenant can override |
| **AD-5: Spring profile activation tied to posture** | `spring.profiles.active=research` etc. | Standard Spring pattern; `application-research.yaml` overrides defaults |

---

## 5. Cross-cutting hooks

- **Rule 11**: this IS Rule 11; everything else inherits
- **Rule 8**: operator-shape gate is run under `prod` posture
- **Rule 6**: single `@Bean AppPosture posture(Environment env)` builder
- **Rule 12**: capability maturity L3 requires `posture.requiresStrict()` to default-on the capability

---

## 6. Quality

| Attribute | Target | Verification |
|---|---|---|
| Single boot-time read | yes | `tests/unit/PostureBootReadTest` |
| Consumer pattern compliance | no `posture == AppPosture.X` literals in consumers | `ArchitectureRulesTest::posturePatternCompliance` |
| Test coverage of postures | dev + research paths covered for every new contract | `PostureCoverageTest` |

---

## 7. Risks

- **Adding a 4th posture (e.g., `STAGING`)**: low risk if consumers use `requires*()` pattern; high risk if they branch on name
- **Posture-aware default-on enforcement**: requires reviewer audit on each capability claiming L3

## 8. References

- Hi-agent equivalent: `D:/chao_workspace/hi-agent/hi_agent/config/posture.py`
- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- L0 D-6: [`../../ARCHITECTURE.md#d-6-three-posture-model-rule-11`](../../ARCHITECTURE.md)
