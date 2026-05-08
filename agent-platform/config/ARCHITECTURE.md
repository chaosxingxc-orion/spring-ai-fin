# config -- Settings + Version Pin (L2)

> **L2 sub-architecture of `agent-platform/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`config/` is the **minimal v1 runtime-settings layer**. Two responsibilities:

1. **Frozen v1 contract version pin** (`V1_RELEASED`, `V1_FROZEN_HEAD`, `API_VERSION`).
2. **Environment-driven runtime settings** (host, port, state-dir, API version, JWT secret pointer).

Owns:

- `ContractVersion.java` -- version constants
- `PlatformSettings.java` -- `@ConfigurationProperties` record bound to `app.*` properties
- `application.yaml` -- defaults for all postures
- `application-{dev,research,prod}.yaml` -- posture-specific overrides

Does NOT own:

- **Posture itself** -- owned by `agent-runtime/posture/AppPosture.java`. We surface posture choice via Spring Profile activation.
- Per-tenant overrides (deferred to v1.1+; see hi-agent's W35-T7 for the pattern)
- Lease intervals, retention policies (deferred; tracked in `docs/governance/retention-roadmap.md`)
- Model routing config (deferred to v1.1+)

---

## 2. Why minimal at v1 (mirrors hi-agent's W35-T7)

v5.0 wanted exhaustive config (4-tier cache parameters, 22-stream tier configs, 5-isolation-dimension toggles per tenant). v6.0 ships **three settings only** at v1:

```yaml
# application.yaml (v1 default)
app:
  host: 127.0.0.1
  port: 8080
  state-dir: ./var/state
  api-version: v1
  posture: ${APP_POSTURE:dev}
  jwt-secret: ${APP_JWT_SECRET:}    # optional; active only when HmacValidator path is enabled (DEV loopback or BYOC single-tenant carve-out per docs/governance/allowlists.yaml). Research SaaS multi-tenant + prod use RS256/ES256 + JWKS via IssuerRegistry instead.
  llm-mode: ${APP_LLM_MODE:mock}    # research/prod requires real
  datasource-url: ${SPRING_DATASOURCE_URL}
```

Posture-specific overrides:

```yaml
# application-research.yaml
app:
  host: 0.0.0.0    # bind external for research deployments
  llm-mode: real   # mock rejected at boot under research

# application-prod.yaml  
app:
  host: 0.0.0.0
  llm-mode: real
  audit-worm-required: true
  pii-redaction-required: true
```

Per Rule 17 (allowlist discipline): adding a new setting to `PlatformSettings` requires a justification + expiry_wave if temporary. The default trajectory is "settings stay minimal; overrides live in `application-*.yaml`".

---

## 3. ContractVersion shape

```java
public final class ContractVersion {
    private ContractVersion() {}
    
    public static final String API_VERSION = "v1";
    public static final String SCHEMA_VERSION = "v1";
    public static final boolean V1_RELEASED = true;       // toggled at first stable release
    public static final String V1_RELEASED_AT = "2026-MM-DD";
    
    /** SHA-256 prefix of the first stable release. Cross-checked by ContractFreezeTest. */
    public static final String V1_FROZEN_HEAD = "<filled at release>";
    
    /** When this constant changes, contract_v1_freeze.json digest must be re-rolled. */
    public static final int FREEZE_GENERATION = 0;        // bumped on additive re-snap (e.g., new @PostConstruct validator)
}
```

`ContractFreezeTest` walks `agent-platform/contracts/v1/` and:
1. Computes per-file SHA-256
2. Compares to `docs/governance/contract_v1_freeze.json`
3. Fails if mismatch AND `FREEZE_GENERATION` not bumped

The `--snapshot` and `--enforce` modes (mirrors hi-agent's W31-N N.8) eliminate drift between `V1_FROZEN_HEAD` and `contract_v1_freeze.json`.

---

## 4. PlatformSettings shape

```java
@ConfigurationProperties("app")
public record PlatformSettings(
    @NotBlank String host,
    @Positive int port,
    @NotNull Path stateDir,
    @NotBlank String apiVersion
) {
    public PlatformSettings {
        Objects.requireNonNull(host);
        if (port < 1 || port > 65535) throw new IllegalArgumentException("port range 1..65535");
        Objects.requireNonNull(stateDir);
        Objects.requireNonNull(apiVersion);
    }
}
```

Bound via `@EnableConfigurationProperties(PlatformSettings.class)` in `bootstrap/`. Validation at construction (Bean Validation + record canonical constructor).

---

## 5. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Settings stay minimal in v1** | 4 fields only | v5.0 over-config; per-tenant overrides + lease/retention deferred |
| **AD-2: Posture lives in `agent-runtime/posture/`** | NOT in this package | Posture is a runtime-domain concept; read once at boot via `AppPosture.fromEnv()` and injected into facade validators. The `config/` package never branches on posture by `Environment.getProperty` at call-time (cycle-2 correction); spring profiles activated by posture provide the binding seam |
| **AD-3: `V1_FROZEN_HEAD` cross-check** | `ContractFreezeTest` validates pin matches actual digest | Eliminates drift between two locations |
| **AD-4: Posture-tied Spring Profiles** | `application-{dev,research,prod}.yaml` overrides | Standard Spring; clean override boundary |
| **AD-5: Validation at record canonical constructor** | port range, paths, etc. checked at construction | Fail-fast at boot |
| **AD-6: Allowlist for new fields** | adding setting requires `docs/governance/allowlists.yaml` entry if temporary | Rule 17 discipline; prevents settings sprawl |

---

## 6. Cross-cutting hooks

- **Rule 6**: `PlatformSettings` is a single `@ConfigurationProperties` bean
- **Rule 11**: posture surfaced via Spring Profile, not as a field in `PlatformSettings`
- **Rule 14**: `V1_FROZEN_HEAD` cross-check is a manifest-truth invariant
- **Rule 17**: settings additions require allowlist entry

---

## 7. Quality

| Attribute | Target | Verification |
|---|---|---|
| Settings count at v1 | <= 6 (4 in PlatformSettings + 2 env: posture + jwt-secret) | `SettingsLocTest` |
| Posture-profile override | overrides apply correctly | `tests/integration/PostureProfileIT` |
| Contract freeze cross-check | `V1_FROZEN_HEAD` matches `contract_v1_freeze.json` | `ContractFreezeTest` |
| Boot-time validation | port/path validity at startup | `tests/integration/SettingsValidationIT` |

## 8. Risks

- **Settings sprawl over waves**: Rule 17 allowlist discipline; reviewer audit on every new setting
- **Posture-vs-Spring-Profile drift**: explicit binding in `application.yaml` (`spring.profiles.active=${APP_POSTURE}`)

## 9. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Posture: [`../../agent-runtime/posture/ARCHITECTURE.md`](../../agent-runtime/posture/ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/agent_server/config/ARCHITECTURE.md`
