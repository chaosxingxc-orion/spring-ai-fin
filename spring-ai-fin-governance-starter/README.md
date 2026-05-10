# spring-ai-fin-governance-starter

> Provides the SPI surface for policy evaluation; supports in-process Bean Validation and optional OPA sidecar delegation. Maturity: L1.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| PolicyEvaluator | evaluate(tenantId, policyId, input) | Evaluates named policy against input map; returns ALLOW, DENY, or ABSTAIN; missing tenantId always returns DENY |

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | Sentinel impl active; WARN on every call; returns DENY with reason "sentinel-not-configured" |
| research | Sentinel rejected at context load; BeanCreationException |
| prod | Sentinel rejected at context load; BeanCreationException |

## Drop-in override (@Bean recipe)

```java
@Bean
PolicyEvaluator myPolicyEvaluator(OpaClient opa) {
    return new OpaBackedPolicyEvaluator(opa);
}
```

## Counters emitted by sentinel

- `springai_fin_governance_default_impl_not_configured_total` tagged `spi=PolicyEvaluator, method=evaluate`

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
