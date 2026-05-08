# cli -- Operator CLI (L2)

> **L2 sub-architecture of `agent-platform/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`cli/` is the **operator-facing command-line wrapper** over the v1 HTTP routes. Four thin subcommands:

- `agent-platform serve` -- boot the Spring Boot app in-process
- `agent-platform run` -- submit a run via `POST /v1/runs`
- `agent-platform cancel` -- cancel via `POST /v1/runs/{id}/cancel`
- `agent-platform tail-events` -- SSE-stream `/v1/runs/{id}/events`

Owns:

- `CliApp` -- Spring Shell dispatcher
- 4 subcommand classes (`ServeCommand`, `RunCommand`, `CancelCommand`, `TailEventsCommand`)
- HTTP client (stdlib `java.net.http.HttpClient`; no third-party HTTP)

Does NOT own:

- Persistent state (no config file, no token cache, no session)
- Sophisticated routing (no `--profile` for tenant pre-selection -- every invocation explicit)

---

## 2. Why stdlib HTTP, why no state

**Stdlib HTTP** (`java.net.http.HttpClient`): no third-party HTTP client (Spring `RestTemplate`, `WebClient`, OkHttp). The only library imports outside Spring Boot core are Spring Shell. Reasons:

- CLI startup time matters; reactive client startup adds ~500ms
- Stdlib HttpClient is sufficient for our 4 subcommands
- Mirrors hi-agent's CLI principle (`urllib.request` only, no `httpx`)

**No state**: every invocation is fully self-describing. Tenant id is a CLI flag (`--tenant-id alice`); idempotency key auto-generated or specified (`--idempotency-key foo`); JWT supplied via env (`APP_OPERATOR_JWT`).

The discipline: **operator CLI is for incidents and one-off tasks**, not interactive workflow. For interactive workflow, use the Operations Console (Tier-A two-product architecture; see L0 sec-11).

---

## 3. Subcommands

### 3.1 `agent-platform serve`

```
agent-platform serve [--posture {dev,research,prod}] [--host HOST] [--port PORT] [--prod]
```

- Boots `PlatformBootstrap` in-process; same FastAPI-equivalent app as customer's `java -jar`
- `--prod` shorthand: posture=prod, host=0.0.0.0; explicit confirmation required
- Default loopback (`--host 127.0.0.1`) prevents accidental external exposure in dev
- Foreground process; for production, supervise via PM2/systemd/docker (Rule 8 step 1)

### 3.2 `agent-platform run`

```
agent-platform run --tenant-id TID --goal "..." [--profile-id PID] [--framework SPRING_AI|LANGCHAIN4J|PY_SIDECAR|AUTO] [--idempotency-key KEY] [--wait]
```

- Submits `POST /v1/runs`
- `--wait`: SSE-stream events to stdout until terminal
- Default exit codes: 0 success / 1 HTTP error / 2 input error

### 3.3 `agent-platform cancel`

```
agent-platform cancel --tenant-id TID --run-id RID
```

- Posts `POST /v1/runs/{id}/cancel`
- Exit codes: 0 (200 cancelled) / 1 (404 unknown / 409 already terminal) / 2 (input error)

### 3.4 `agent-platform tail-events`

```
agent-platform tail-events --tenant-id TID --run-id RID [--since-cursor CUR] [--filter EVENT_TYPE]
```

- SSE consumes `/v1/runs/{id}/events` to stdout
- Newline-delimited JSON; one event per line for grep-ability

---

## 4. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Stdlib HTTP only** | `java.net.http.HttpClient`; no third-party HTTP | CLI startup time; minimal dep footprint |
| **AD-2: SAS-1 split** | `serve` may import `bootstrap/`; other subcommands talk HTTP only | `run/cancel/tail-events` work against any v1 server, not just local |
| **AD-3: No persistent state** | every invocation self-describing; no config file | Avoid stale-state surprises; mirrors hi-agent CLI principle |
| **AD-4: Default loopback in dev** | `--host 127.0.0.1` default | Prevents accidental external exposure |
| **AD-5: `--prod` flips posture + host** | combined flag forces explicit production intent | Hi-agent's W33 lesson -- partial-prod-config caused outages |
| **AD-6: Deterministic exit codes** | 0 success / 1 HTTP / 2 input | Scriptable in shell pipelines |
| **AD-7: Newline-delimited JSON output** | one event per line for `grep` / `jq` | Operator-friendly |
| **AD-8: SSE 404 -> poll fallback** | if SSE returns 404 (route stub at v1), fall back to polling `GET /v1/runs/{id}` | Graceful degradation per Rule 7 |

---

## 5. Cross-cutting hooks

- **SAS-1**: only `ServeCommand` may import `agent-platform/bootstrap/`; others use HTTP
- **Rule 8**: `serve --prod` is the operator-shape gate step 1 (long-lived process); CLI documents the PM2/systemd/docker overlay
- **Rule 11**: CLI honours posture; under `--prod`, CLI fails-fast if `IssuerRegistry` has no RS256/ES256 entry (per L0 sec-A3 and `agent-runtime/auth/`). HS256 (`APP_JWT_SECRET`) is permitted only for DEV loopback or BYOC single-tenant carve-outs documented in `docs/governance/allowlists.yaml`; the operative invariant is "auth path matches posture x deployment shape," not "APP_JWT_SECRET is set"
- **Rule 7**: SSE -> poll fallback emits visible "fallback: sse-not-available" log line so operators see what happened

---

## 6. Quality

| Attribute | Target | Verification |
|---|---|---|
| CLI startup time | <= 500ms (excluding `serve`) | `tests/integration/CliStartupTimeIT` |
| All subcommands have integration tests | 100% | `CliCoverageTest` |
| Exit code consistency | matches `--help` documented codes | `tests/unit/CliExitCodeTest` |
| No third-party HTTP | only `java.net.http` and Spring Shell allowed | `ArchitectureRulesTest::cliMinDeps` |

## 7. Risks

- **Spring Shell startup time**: profile and trim if > 500ms
- **CLI vs Operations Console feature parity**: CLI for incidents; Console for workflow; gap acceptable

## 8. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/agent_server/cli/ARCHITECTURE.md`
- Spring Shell: https://docs.spring.io/spring-shell/reference/
