# spring-ai-ascend-resilience-starter

> Provides the SPI surface for mapping operation identifiers to named Resilience4j policy triples (circuit breaker, retry, time limiter); W2 callers apply the names via @CircuitBreaker/@Retry annotations. Maturity: L1.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| ResilienceContract | resolve(operationId) | Returns ResiliencePolicy with non-null circuitBreakerName, retryName, and timeLimiterName; never returns null |

`ResiliencePolicy` is a process-internal record (not persisted or transmitted). The caller uses the returned names to bind Resilience4j @CircuitBreaker, @Retry, and @TimeLimiter annotations at W2 call sites.

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Sentinel impl active; WARN on every call; returns policy with names "default-cb", "default-retry", "default-tl" |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

## Drop-in override (@Bean recipe)

```java
@Bean
ResilienceContract myResilienceContract() {
    return operationId -> switch (operationId) {
        case "llm-call"  -> new ResilienceContract.ResiliencePolicy("llm-cb", "llm-retry", "llm-tl");
        case "tool-call" -> new ResilienceContract.ResiliencePolicy("tool-cb", "tool-retry", "tool-tl");
        default          -> new ResilienceContract.ResiliencePolicy("default-cb", "default-retry", "default-tl");
    };
}
```

## Counters emitted by sentinel

- `springai_fin_resilience_default_impl_not_configured_total` tagged `spi=ResilienceContract, method=resolve`

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
