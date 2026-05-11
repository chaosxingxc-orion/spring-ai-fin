package ascend.springai.runtime.governance;

import ascend.springai.runtime.spi.governance.PolicyEvaluator;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;

/**
 * L0 sentinel: no JSR-303 or OPA impl wired at W0.
 * Replaced by JSR-303 + active-corpus loader default impl in W1.
 */
class NotConfiguredPolicyEvaluator implements PolicyEvaluator {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredPolicyEvaluator.class);
    private static final String METRIC = "springai_ascend_governance_default_impl_not_configured_total";
    private static final String MSG =
            "L0: PolicyEvaluator has no default impl yet. " +
            "Provide a @Bean PolicyEvaluator or wait for the W1 JSR-303 + active-corpus impl.";

    private final MeterRegistry registry;

    NotConfiguredPolicyEvaluator(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public EvaluationResult evaluate(String tenantId, String policyId, Map<String, Object> input) {
        registry.counter(METRIC, "spi", "PolicyEvaluator", "method", "evaluate").increment();
        LOG.warn("L0: PolicyEvaluator.evaluate called with no impl; tenantId={} policyId={}", tenantId, policyId);
        throw new IllegalStateException(MSG);
    }
}
