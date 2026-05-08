# bootstrap -- Assembly Seam #1 (L2)

> **L2 sub-architecture of `agent-platform/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`bootstrap/` is **SAS-1 seam #1**: the assembly module where everything is wired. It is one of only two locations in `agent-platform/` permitted to import `agent-runtime.*` (the other is `runtime/`).

Owns:

- `PlatformBootstrap` -- `@SpringBootApplication`-annotated; entry point for `java -jar`
- `@Bean` methods that wire facades, idempotency store, real kernel backend, lifespan controller
- Spring profile activation tied to `APP_POSTURE`
- Boot-time invariant assertions

Does NOT own:

- Kernel binding logic (delegated to `../runtime/RealKernelBackend.java`)
- Lifespan task implementations (delegated to `../runtime/LifespanController.java`)
- Auth seam (delegated to `../runtime/AuthSeam.java`)
- HTTP routes (delegated to `../api/`)
- Domain logic (out of scope per Rule 10)

---

## 2. Why one assembly module

Hi-agent's W11 lesson: assembly logic scattered across multiple modules creates "two construction sites for the same resource" defects (DF-11 class). Concentrating assembly in one module:

1. **Makes Rule 6 enforceable** -- every shared resource has exactly one `@Bean` method here.
2. **Makes SAS-1 auditable** -- `agent-runtime.*` imports concentrated; reviewer scans 200 LOC, not the whole package.
3. **Makes test-vs-prod swap clean** -- tests inject stub callables; production wires `RealKernelBackend` callables; same facades.

---

## 3. PlatformBootstrap shape

```java
@SpringBootApplication
public class PlatformBootstrap {
    public static void main(String[] args) {
        SpringApplication.run(PlatformBootstrap.class, args);
    }
    
    // Posture -- single boot-time read (Rule 11)
    @Bean
    public AppPosture appPosture(Environment env) {
        return AppPosture.fromEnv(env);
    }
    
    // Single Construction Path resources (Rule 6)
    @Bean
    public IdempotencyStore idempotencyStore(DataSource ds, MeterRegistry meter, AppPosture posture) {
        return new PostgresIdempotencyStore(ds, meter, posture);
    }
    
    @Bean
    public RealKernelBackend realKernelBackend(
        @Value("${app.state-dir}") Path stateDir,
        AppPosture posture,
        IdempotencyStore idemStore
    ) {
        var backend = new RealKernelBackend(stateDir, posture);
        backend.setIdempotencyStore(idemStore);   // mirrors hi-agent W35-T4
        return backend;
    }
    
    // Facades -- constructor-injected with method references (SAS-1 seam concentrated here)
    @Bean
    public RunFacade runFacade(RealKernelBackend backend) {
        return new RunFacade(
            backend::startRun,
            backend::getRun,
            backend::cancelRun,
            backend::iterEvents
        );
    }
    
    @Bean public EventFacade eventFacade(RealKernelBackend backend) { /* ... */ }
    @Bean public ArtifactFacade artifactFacade(RealKernelBackend backend) { /* ... */ }
    @Bean public ManifestFacade manifestFacade(RealKernelBackend backend) { /* ... */ }
    @Bean public IdempotencyFacade idempotencyFacade(IdempotencyStore store) { /* ... */ }
    @Bean public AuditFacade auditFacade(RealKernelBackend backend) { /* ... */ }
    
    // Lifespan supervisor
    @Bean
    public LifespanController lifespanController(RealKernelBackend backend, ScheduledExecutorService scheduler) {
        return new LifespanController(backend, scheduler);
    }
    
    // Auth seam
    @Bean
    public AuthSeam authSeam(JwtValidator validator) {
        return new AuthSeam(validator);
    }
    
    // Boot-time invariant assertions (mirrors hi-agent W35-T8)
    @PostConstruct
    public void assertInvariants() {
        var posture = appPosture(/* env */);
        if (posture.requiresStrict()) {
            // Posture-aware identity per L0 D-block sec-A3 and `agent-runtime/auth/`:
            //   research SaaS multi-tenant + prod  -> RS256/ES256 + JWKS via IssuerRegistry (mandatory)
            //   research BYOC single-tenant        -> HS256 carve-out only with allowlist entry
            //   dev loopback                       -> HS256 or anonymous
            // PostureBootGuard (in `agent-runtime/posture/`) is the canonical boot gate;
            // bootstrap delegates by asserting prerequisites match the active validator path:
            assertJwksIssuerRegistryWhenSaasMultiTenant();
            assertHmacAllowlistWhenHmacActive();   // APP_JWT_SECRET is asserted >=32 bytes ONLY when HmacValidator is active
            assertEnvSet("APP_LLM_MODE", "research/prod posture requires real LLM");
            assertStateDirWritable();
        }
    }
}
```

LOC budget: bootstrap target <= 300 LOC (allowlisted to <= 500 if necessary; expiry_wave required).

---

## 4. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: One `@SpringBootApplication`** | Single entry point | Standard Spring pattern; only one main class |
| **AD-2: All `@Bean` methods here, not scattered** | Concentration enables Rule 6 audit | Hi-agent's DF-11 class of defect prevention |
| **AD-3: `@PostConstruct` boot-time assertions** | Fail-fast at startup, not at first request | hi-agent's W35-T8 pattern |
| **AD-4: Posture from env via @Bean** | `AppPosture.fromEnv(env)` returned as `@Bean` | Single boot-time read; consumers `@Inject` |
| **AD-5: Method references for facade callables** | `backend::startRun` (no lambda) | Cleaner; SAS-1 seam annotation per import |
| **AD-6: Spring Profiles tied to posture** | `spring.profiles.active=${APP_POSTURE}` in `application.yaml` | Standard Spring; `application-research.yaml` overrides defaults |

---

## 5. Cross-cutting hooks

- **SAS-1**: every `agent-runtime.*` import in this file carries `// sas-1-seam: <reason>` annotation; reviewed at PR
- **Rule 6**: every `@Bean` method here is the single construction path for that resource
- **Rule 11**: `AppPosture.fromEnv` once at boot
- **Rule 8**: boot-time assertions are the first defense (gate step 1: long-lived process)

---

## 6. Quality

| Attribute | Target | Verification |
|---|---|---|
| LOC budget | <= 300 (<= 500 with allowlist) | `BootstrapLocTest` |
| All `@Bean` methods are single construction | no inline `x != null ? x : new DefaultX()` | `Rule6BootstrapTest` |
| Boot-time assertions trigger on missing config | strict posture without JWT secret = fail at startup | `tests/integration/BootstrapInvariantsIT` |

## 7. Risks

- **Bootstrap-as-god-class**: budget enforced by LOC; complex assembly may need helper methods (still in this file) or a sub-class
- **Bean dependency cycles**: Spring detects at startup; rejected via fail-fast

## 8. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Runtime seam: [`../runtime/ARCHITECTURE.md`](../runtime/ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/agent_server/bootstrap.py`
