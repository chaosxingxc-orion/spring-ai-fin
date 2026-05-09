# v1 Reference Customer Profile -- cross-cutting policy

> Owner: architecture | Wave: W0..W4 (per-wave NFRs anchor here) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Pins the v1 reference customer so capacity, NFRs, deployment topology,
and cost model have one concrete target instead of parametric ranges.
Closes Phase A item 2 (per cycle-12).

This profile is **a working assumption** -- not a contract with any real
customer. It exists so the architecture has concrete numbers to commit
to. When a real first customer is named, this profile is renegotiated;
the architecture's parametric design (per-tenant configs, HPA, posture
defaults) absorbs reasonable deviations without redesign.

## 2. The reference customer

**Profile name**: `Tier-1 financial-services operator (single-customer
on-prem)`.

| Attribute | Value | Rationale |
|---|---|---|
| Industry | Banking / broker-dealer / insurance | matches the project's stated target ("self-hostable agent runtime for financial-services operators" -- L0 sec-0) |
| Deployment | On-prem Kubernetes (or hybrid private cloud) | regulatory + data-residency typical for the segment |
| Region | Single region (one DC; one DR site) | v1 simplifies; v2+ adds multi-region per cycle-10 deployment topology |
| Customer count served by deployment | 1 | this is a single-customer install; no SaaS multi-tenancy at v1 |
| Logical tenants in this customer's deployment | 5 | typical for a Tier-1 institution: corporate-banking / retail-banking / wealth / treasury / risk; each as a sub-tenant |
| Internal users | ~500 | analysts, ops, RM staff |
| Concurrent users at peak | 50-100 | working-hours peak |
| Runs per day | 20,000 | mix of internal queries + automated workflows |
| Runs per second peak | ~50 RPS app, ~10 RPS sustained | working-hours bursty |
| Concurrent in-flight runs at peak | ~200 | mostly short (<5s); some long via Temporal |
| Average run duration | 8s (median); 25s (p95) | LLM-dominated |
| Long runs (Temporal-managed) | ~10% | reports, multi-step workflows |
| Tools registered per tenant | ~20-30 | varies by tenant role |
| Long-term memory rows per tenant | ~500k | 1-year retention; ~1.4k rows / day / tenant |
| Audit log retention | 7 years | regulatory baseline (SOX, banking secrecy) |

## 3. Mapping to NFR targets

The numbers above anchor the NFR doc's `prod` column targets. Where
the NFR doc gives a range, this profile picks the value:

| NFR | NFR-doc range | v1 customer pinned |
|---|---|---|
| `POST /v1/runs` (real LLM) p99 latency | <= 5s (prod) | <= 5s |
| `POST /v1/runs/{id}/cancel` p99 | <= 100ms (prod) | <= 100ms |
| HTTP requests / second / replica | 200 (prod) | 50 sustained, 200 peak across 3 replicas |
| Concurrent in-flight runs / replica | 400 (prod) | <= 100 (assuming 3 replicas; capacity headroom) |
| API availability monthly | 99.9% (prod) | 99.9% (~43m / month allowed downtime) |
| Run lifecycle availability (sync) | 99.9% (prod) | 99.9% |
| Run lifecycle availability (Temporal) | 99.95% (prod) | 99.95% |
| Per-run median LLM cost | <= $0.003 (prod) | <= $0.003 (cheap-tier first; budget gates) |
| Tenants per single-region | up to 1000 (prod) | 5 logical tenants -- 0.5% of design ceiling |
| Active tools / tenant | 200 (prod) | 30 typical; design ceiling unchanged |
| Long-term memory rows / tenant | 1M (prod) | ~500k; pgvector OK (Qdrant trigger > 5M) |

The architecture's design ceilings are 10x to 100x the v1 customer's
expected load. This is intentional headroom -- the design accommodates
v2+ growth without rework.

## 4. Compliance posture

The reference customer's regulatory environment shapes which controls
must be on by default:

| Regulation | Implication for design | Where enforced |
|---|---|---|
| SOX (financial reporting) | Audit-log append-only + 7-year retention; segregation of duties | `agent-runtime/action/` audit_log; admin scopes (`agent-platform/auth/`) |
| Banking secrecy (regional) | Data-residency: all tenant data in customer's region | `docs/cross-cutting/deployment-topology.md`; on-prem default |
| AML / KYC | Auditability of every recommendation | OTel + audit_log + outbox event per `agent-runtime/action/` |
| GDPR (or local equivalent) | Right to erasure | tenant export + soft+hard delete in `agent-platform/tenant/` sec-10 |
| PCI-DSS (if payment data handled) | Encryption in transit + at rest; key rotation | TLS 1.2+; Postgres TDE (customer-supplied); Vault rotation |
| Internal audit | Reproducible queries / decisions | Workflow versioning markers (`agent-runtime/temporal/`); prompt versioning |

Posture defaults: `prod` is the working posture for this customer;
`research` is only used in pre-prod / staging clusters; `dev` is on
developer laptops only.

## 5. Cost model anchored to v1

Monthly cost ceiling targets (per `docs/cross-cutting/deployment-topology.md`
sec-8 with this profile pinned):

| Cost line | Monthly ceiling | Notes |
|---|---|---|
| Infrastructure (compute + DB + Temporal) | $1,500 | 3 app pods + RDS medium + Temporal cluster (3-node) + observability |
| LLM provider cost | $1,800 | 20k runs/day * 30 days = 600k runs * $0.003 median |
| Operations (SRE, monitoring, on-call) | external | not counted in platform cost |
| **Total monthly platform cost** | **<= $3,500** | excluding ops + customer's own SRE |

Per-run cost target (P2 first-principle): **median run cost <= $0.005
infra + LLM combined**.

## 6. Deployment shape pinned

| Aspect | v1 customer setting |
|---|---|
| Region | 1 (active); 1 DR site (passive Postgres replica only) |
| App replicas | 3 |
| Postgres | 1 RW + 1 RO (read replica + DR target) |
| Valkey | 1 (single node; rebuildable from source) |
| Temporal | 3-node cluster (frontend/match/history); shared Postgres v1 |
| Keycloak | external customer IdP (their existing); fallback Keycloak 2-node if customer requests |
| Observability stack | Loki + Grafana + Tempo (single-region) |
| Vault | 3-node cluster; KV-v2 backend; per-tenant subpaths |
| OPA | sidecar per app pod (3 sidecars) |
| Network | private network only; egress allowlist; CDN/WAF customer-side |

This pin sets the Helm `values.yaml` defaults at W2.

## 7. What this profile does NOT cover

- Multi-customer SaaS: not v1.
- Multi-region active-active: deferred (W4+ post; per cycle-10 deployment topology sec-2.3).
- Mobile SDK consumption: not v1.
- Public API exposure: gated; customer's API Gateway is the public face.
- BYO-LLM-provider customer cases: v1 ships with Anthropic + OpenAI + Bedrock provider beans; customer chooses via config.

## 8. Cadence + revision rule

This profile is **revisited at each wave close**:

- **W0**: confirm Maven + Postgres + image-build viable for the pinned shape.
- **W1**: confirm RLS + JWT validation behavior at projected scale (50 RPS).
- **W2**: confirm sync-mode latency (cycle-10 NFR doc) under simulated load.
- **W3**: confirm ActionGuard latency budget under tool-fanout.
- **W4**: confirm Temporal HA under chaos test; confirm cost model.

If a revision deviates >20% from this profile, the profile updates;
NFR targets re-anchor; deployment topology revises. Smaller deviations
are absorbed by per-tenant config + HPA scaling.

When a real first customer is named, this doc is rewritten with their
specific numbers; the architecture's design ceilings (1000 tenants /
1M memory rows / etc.) ensure headroom remains.

## 9. References

- `ARCHITECTURE.md` sec-0 (purpose statement)
- `docs/cross-cutting/non-functional-requirements.md` (NFR ranges this profile pins)
- `docs/cross-cutting/deployment-topology.md` sec-2.2 (single-region K8s)
- `docs/cross-cutting/security-control-matrix.md` (audit + data-residency controls)
- `docs/cross-cutting/secrets-lifecycle.md` (Vault per-tenant subpaths)
