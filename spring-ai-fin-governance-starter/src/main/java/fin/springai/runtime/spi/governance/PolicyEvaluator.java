package fin.springai.runtime.spi.governance;

import java.util.Map;

/**
 * SPI: evaluate a named policy against an input document.
 *
 * Default impl: in-process JSR-303 Bean Validation + active-corpus
 * constraint loader.
 * Optional external impl: OPA client (OPA daemon via REST API).
 *
 * Rule 11: tenantId carried on every evaluation context.
 * Rule 7: any DENY result must be logged at WARNING+ with run id.
 */
public interface PolicyEvaluator {

    /**
     * Evaluate policy {@code policyId} against the given input map.
     *
     * @param tenantId  tenant scope (required; missing = DENY)
     * @param policyId  logical name of the policy to evaluate
     * @param input     arbitrary key-value input document
     * @return evaluation result; never null
     */
    EvaluationResult evaluate(String tenantId, String policyId, Map<String, Object> input);

    record EvaluationResult(
            Decision decision,
            String reason,
            Map<String, Object> details
    ) {}

    enum Decision {
        ALLOW,
        DENY,
        ABSTAIN
    }
}
