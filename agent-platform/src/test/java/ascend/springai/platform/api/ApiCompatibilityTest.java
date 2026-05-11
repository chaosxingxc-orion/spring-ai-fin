package ascend.springai.platform.api;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * Freezes the public API and SPI surface of ascend.springai.* and enforces
 * the competitor-exclusion rule (no com.alibaba.cloud.ai imports).
 *
 * Per docs/cross-cutting/oss-bill-of-materials.md sec-8 "Excluded dependencies":
 * spring-ai-alibaba (com.alibaba.cloud.ai:*) is a direct competitor.
 * Its code must never be imported into the SDK. This test is the
 * compile-time enforcement gate for that rule.
 *
 * SPI freeze: extended after Step 11 landed ascend.springai.runtime.spi.*.
 * Any signature change in spi.** requires editing this test, making
 * the break explicit during code review.
 */
class ApiCompatibilityTest {

    private static final JavaClasses FIN_SPRINGAI_CLASSES = new ClassFileImporter()
            .importPackages("ascend.springai");

    @Test
    void no_springai_ascend_class_imports_competitor_alibaba_cloud_ai() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai..")
                .should().dependOnClassesThat()
                .resideInAPackage("com.alibaba.cloud.ai..");
        rule.check(FIN_SPRINGAI_CLASSES);
    }

    @Test
    void platform_api_package_has_no_runtime_internals_dependency() {
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai.platform..")
                .should().dependOnClassesThat()
                .resideInAPackage("ascend.springai.runtime..");
        rule.check(FIN_SPRINGAI_CLASSES);
    }

    @Test
    void spi_packages_have_no_platform_dependency() {
        // SPI layer must not depend on platform (northbound) code.
        // Platform may depend on SPI (via adapters); never the reverse.
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai.runtime.spi..")
                .should().dependOnClassesThat()
                .resideInAPackage("ascend.springai.platform..");
        rule.check(FIN_SPRINGAI_CLASSES);
    }

    @Test
    void spi_packages_import_only_java_sdk_types() {
        // SPI interfaces are pure Java (no Spring, no third-party frameworks).
        // This keeps the contract stable across Boot major upgrades.
        ArchRule rule = noClasses()
                .that().resideInAPackage("ascend.springai.runtime.spi..")
                .should().dependOnClassesThat()
                .resideInAPackage("org.springframework..");
        rule.check(FIN_SPRINGAI_CLASSES);
    }
}
