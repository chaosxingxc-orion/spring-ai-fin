package ascend.springai.runtime.architecture;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * Generalised SPI purity enforcer for CLAUDE.md Rule 29 (Business/Platform Decoupling)
 * and Rule 32 (SPI + DFX + TCK Co-Design). Authority: ADR-0064, ADR-0067.
 *
 * <p>Existing test MemorySpiArchTest covers runtime.memory.spi only and OrchestrationSpiArchTest
 * covers runtime.orchestration.spi only. This test generalises the contract: ANY package under
 * {@code ascend.springai..spi..} (current or future) MUST remain free of Spring, platform,
 * inmemory-impl, and resilience-impl dependencies so SPI interfaces stay stable for downstream
 * developers extending the platform without source patches.
 *
 * <p>Vacuous-but-armed: when a new SPI package lands (e.g. {@code runtime.llm.spi}), this test
 * picks it up automatically — no test edits required.
 *
 * <p>Enforcer ID: E48.
 */
class SpiPurityGeneralizedArchTest {

    private static final JavaClasses ALL_RUNTIME_CLASSES = new ClassFileImporter()
            .importPackages("ascend.springai");

    @Test
    void any_spi_package_does_not_depend_on_spring() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai..spi..")
                .should().dependOnClassesThat()
                .resideInAPackage("org.springframework..");
        rule.check(ALL_RUNTIME_CLASSES);
    }

    @Test
    void any_spi_package_does_not_depend_on_platform() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai..spi..")
                .should().dependOnClassesThat()
                .resideInAPackage("ascend.springai.platform..");
        rule.check(ALL_RUNTIME_CLASSES);
    }

    @Test
    void any_spi_package_does_not_depend_on_inmemory_reference_impls() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai..spi..")
                .should().dependOnClassesThat()
                .resideInAPackage("ascend.springai.runtime.orchestration.inmemory..");
        rule.check(ALL_RUNTIME_CLASSES);
    }

    @Test
    void any_spi_package_does_not_depend_on_micrometer_or_otel() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai..spi..")
                .should().dependOnClassesThat()
                .resideInAnyPackage("io.micrometer..", "io.opentelemetry..");
        rule.check(ALL_RUNTIME_CLASSES);
    }
}
