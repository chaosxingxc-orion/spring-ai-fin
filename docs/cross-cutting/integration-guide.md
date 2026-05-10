> Owner: agent-platform | Maturity: L2 | Posture: all | Last refreshed: 2026-05-10

# Integration Guide

Three paths for integrating with the spring-ai-fin platform. Choose the path that fits your deployment model.

---

## Path 1: Drop-in @Bean override

The simplest integration path. Import the BoM, add one or more starters, and declare @Bean implementations for the SPI interfaces you need. The starter's sentinel is replaced at context load.

### Maven setup

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>fin.springai</groupId>
      <artifactId>spring-ai-fin-dependencies</artifactId>
      <version>0.1.0-SNAPSHOT</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <dependency>
    <groupId>fin.springai</groupId>
    <artifactId>spring-ai-fin-memory-starter</artifactId>
  </dependency>
  <dependency>
    <groupId>fin.springai</groupId>
    <artifactId>spring-ai-fin-persistence-starter</artifactId>
  </dependency>
</dependencies>
```

### @Bean example

```java
@Configuration
public class InfraConfig {

    @Bean
    LongTermMemoryRepository myMemoryRepo(DataSource ds) {
        return new MyJdbcLongTermMemoryRepository(ds);
    }

    @Bean
    RunRepository myRunRepository(JdbcTemplate jdbc) {
        return new JdbcRunRepository(jdbc);
    }

    @Bean
    PolicyEvaluator myPolicyEvaluator(OpaClient opa) {
        return new OpaBackedPolicyEvaluator(opa);
    }
}
```

Posture is set via `APP_POSTURE` env var (`dev`/`research`/`prod`). In `research` and `prod`, the platform rejects sentinel impls at context load -- provide real @Bean overrides before deploying.

---

## Path 2: Sidecar adapter starter (enabled=true)

Use this path when you want a pre-built adapter to an external service (Mem0, Graphiti, Docling) without writing SPI glue yourself.

### Maven setup

```xml
<dependencies>
  <dependency>
    <groupId>fin.springai</groupId>
    <artifactId>spring-ai-fin-mem0-starter</artifactId>
  </dependency>
</dependencies>
```

### Enable and configure

```yaml
springai:
  fin:
    mem0:
      enabled: true
      base-url: ${SPRINGAI_FIN_MEM0_BASE_URL}
```

The sidecar adapter registers a `LongTermMemoryRepository` bean that overrides the sentinel. No @Bean declaration needed. The external service must be reachable at context load time in `research` and `prod` postures.

The same pattern applies to `spring-ai-fin-graphmemory-starter` (property prefix: `springai.fin.graphmemory`) and `spring-ai-fin-docling-starter` (property prefix: `springai.fin.docling`).

---

## Path 3: External BoM consumer

Use this path when you are building a third-party module or a downstream project that depends on the spring-ai-fin SPI contracts but does not bundle the platform itself.

### Maven setup

Import only the BoM and depend on the SPI-only artifact (no auto-configuration on the classpath):

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>fin.springai</groupId>
      <artifactId>spring-ai-fin-dependencies</artifactId>
      <version>0.1.0-SNAPSHOT</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <!-- SPI interfaces only; no auto-configuration triggered -->
  <dependency>
    <groupId>fin.springai</groupId>
    <artifactId>spring-ai-fin-memory-starter</artifactId>
    <optional>true</optional>
  </dependency>
</dependencies>
```

### @Bean example for a downstream module

```java
// In the downstream module's own auto-configuration:
@Bean
@ConditionalOnMissingBean
LongTermMemoryRepository externalMemoryRepository(ExternalServiceClient client) {
    return new ExternalMemoryRepository(client);
}
```

The platform BoM pins transitive dependency versions so the downstream module does not need to re-pin them.

---

## Posture summary

| Posture | APP_POSTURE value | Sentinel behavior |
|---------|-------------------|-------------------|
| dev | dev (default) | Sentinels active; WARN on every call |
| research | research | BeanCreationException if any sentinel remains |
| prod | prod | BeanCreationException if any sentinel remains |

Set `APP_POSTURE` as an environment variable before the JVM starts. Never hard-code the posture in application code.

---

## Related documents

- [docs/contracts/spi-contracts.md](spi-contracts.md) for the full SPI semantic contract reference
- [docs/cross-cutting/middleware-pattern-guide.md](middleware-pattern-guide.md) for the sidecar adapter pattern walked end-to-end
- [docs/cross-cutting/contract-evolution-policy.md](contract-evolution-policy.md) for versioning rules
- Individual starter READMEs for @Bean recipes per SPI
