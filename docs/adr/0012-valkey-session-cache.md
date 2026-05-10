# 0012. Maven multi-module, not Gradle

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Build system choice for a 3-module project with strict dependency direction and finserv audit requirements.

## Context

The project is organized as a multi-module build with strict dependency direction
rules between modules. The build system must support Spring Boot's BOM-first
dependency management and be readable by customer audit teams who review POM files
as part of finserv compliance processes.

## Decision Drivers

- Spring Boot's BOM is Maven-first; BOM inheritance is cleanest in Maven.
- Customer audit teams understand Maven (POM files are deterministic and familiar).
- 3 modules do not need Gradle's build flexibility or parallelism.
- Maven's explicit dependency declarations satisfy audit requirements.

## Considered Options

1. Maven 3.9 -- mature; explicit; works with Spring's BOM perfectly.
2. Gradle -- faster incremental builds; more flexible; less standard in finserv shops.
3. Bazel -- excellent at scale; massive overhead for 3 modules.

## Decision Outcome

**Chosen option:** Option 1 (Maven 3.9), because it provides first-class Spring Boot BOM
support, deterministic POM files that satisfy finserv audit requirements, and is
sufficient for the 3-module project structure.

### Consequences

**Positive:**
- Spring Boot BOM inheritance is clean and well-documented.
- Deterministic POM files meet finserv audit expectations.
- Lower learning curve for Java engineers familiar with Maven.

**Negative:**
- Incremental build performance is slower than Gradle.
- Less DSL flexibility for complex build logic.

### Reversal cost

high (every module's build descriptor)

## Pros and Cons of Options

### Option 1: Maven 3.9

- Pro: Spring Boot BOM-first integration; clean parent POM inheritance.
- Pro: Deterministic POM files; familiar to finserv audit teams.
- Pro: Sufficient for 3-module project; no over-engineering.
- Con: Slower incremental builds compared to Gradle.
- Con: Less flexible DSL for complex build customization.

### Option 2: Gradle

- Pro: Faster incremental builds; more flexible DSL.
- Con: Gradle build files are less standard in finserv customer environments.
- Con: Build logic is less transparent to audit teams expecting POM files.

### Option 3: Bazel

- Pro: Excellent at very large-scale builds with complex dependency graphs.
- Con: Massive overhead and learning curve for a 3-module project.
- Con: Overkill; Spring Boot BOM integration requires custom rules.

## References

- `docs/plans/engineering-plan-W0-W4.md` sec-2.4 (W0)
