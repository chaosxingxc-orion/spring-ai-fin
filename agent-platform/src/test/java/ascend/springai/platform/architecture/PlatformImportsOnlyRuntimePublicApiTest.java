package ascend.springai.platform.architecture;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * Enforcer for plan §11 row E34 / Phase K audit fix F9 (META-PATTERN
 * side-effect of Phase B's Gate Rule 10 amendment).
 *
 * <p>ADR-0055 permits {@code agent-platform → agent-runtime} for the W1 HTTP
 * run handoff, but only through the runtime's PUBLIC API surface. Internal
 * packages (in-memory reference impls, resilience routing, memory SPI, etc.)
 * MUST remain hidden from the HTTP edge — otherwise a future refactor could
 * silently couple the platform's request thread to runtime internals that
 * are not request-safe.
 *
 * <p>Permitted import roots from {@code ascend.springai.platform..}:
 * <ul>
 *   <li>{@code ascend.springai.runtime.runs..} — Run entity + state machine</li>
 *   <li>{@code ascend.springai.runtime.orchestration.spi..} — pure-Java SPIs</li>
 *   <li>{@code ascend.springai.runtime.orchestration.inmemory.InMemoryRunRegistry}
 *       — the only dev-posture impl agent-platform legitimately wires
 *       (RunControllerAutoConfiguration). Other inmemory.* classes stay
 *       internal.</li>
 *   <li>{@code ascend.springai.runtime.posture..} — AppPostureGate / AppPosture</li>
 *   <li>{@code ascend.springai.runtime.memory.spi..} — explicitly forbidden;
 *       enforced by the sibling test {@code HttpEdgeMustNotImportMemorySpiTest}</li>
 * </ul>
 *
 * <p>Anything else under {@code ascend.springai.runtime..} is OFF-LIMITS to
 * the HTTP edge.
 */
class PlatformImportsOnlyRuntimePublicApiTest {

    private static final JavaClasses PLATFORM_MAIN_CLASSES = new ClassFileImporter()
            .withImportOption(new ImportOption.DoNotIncludeTests())
            .importPackages("ascend.springai.platform");

    @Test
    void platform_does_not_depend_on_internal_runtime_packages() {
        // W1.x Phase 9 / ADR-0070 promoted ascend.springai.runtime.resilience..
        // to a PUBLIC SPI surface (ResilienceContract two-arg resolve consumed by
        // agent-platform.resilience.ResilienceAutoConfiguration). Internal-only
        // packages stay: idempotency.. and probe..
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai.platform..")
                .should().dependOnClassesThat()
                .resideInAnyPackage(
                        "ascend.springai.runtime.idempotency..",
                        "ascend.springai.runtime.probe..")
                .because("ADR-0055 / plan §18 F9 (extended by ADR-0070): platform may "
                        + "import runtime's PUBLIC api (runs.*, orchestration.spi.*, "
                        + "posture.*, resilience.*, and the InMemoryRunRegistry adapter). "
                        + "Internal packages (idempotency.., probe..) remain hidden from "
                        + "the HTTP edge. Enforcer row E34.");
        rule.check(PLATFORM_MAIN_CLASSES);
    }

    @Test
    void platform_does_not_depend_on_runtime_inmemory_executors_or_checkpointer() {
        // The single legitimate inmemory import is InMemoryRunRegistry (wired
        // by RunControllerAutoConfiguration in dev posture). Other inmemory
        // adapters — SyncOrchestrator, SequentialGraphExecutor,
        // IterativeAgentLoopExecutor, InMemoryCheckpointer — stay hidden from
        // the HTTP edge. They're driven by the orchestration SPI from within
        // the runtime, not from the platform.
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai.platform..")
                .should().dependOnClassesThat()
                .haveFullyQualifiedName(
                        "ascend.springai.runtime.orchestration.inmemory.SyncOrchestrator")
                .orShould().dependOnClassesThat().haveFullyQualifiedName(
                        "ascend.springai.runtime.orchestration.inmemory.SequentialGraphExecutor")
                .orShould().dependOnClassesThat().haveFullyQualifiedName(
                        "ascend.springai.runtime.orchestration.inmemory.IterativeAgentLoopExecutor")
                .orShould().dependOnClassesThat().haveFullyQualifiedName(
                        "ascend.springai.runtime.orchestration.inmemory.InMemoryCheckpointer")
                .because("ADR-0055 / plan §18 F9: only InMemoryRunRegistry is the "
                        + "legitimate in-memory adapter the HTTP edge wires. "
                        + "Sync/Sequential/Iterative executors + InMemoryCheckpointer "
                        + "stay internal to the runtime.");
        rule.check(PLATFORM_MAIN_CLASSES);
    }
}
