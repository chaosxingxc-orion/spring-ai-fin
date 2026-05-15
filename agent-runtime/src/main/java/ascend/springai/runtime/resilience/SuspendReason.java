package ascend.springai.runtime.resilience;

/**
 * Reason envelope for a run-suspension, paired with {@code RunStatus.SUSPENDED}.
 * Sealed per ADR-0019 / ADR-0070 — only the runtime owns the closed taxonomy.
 *
 * <p>At W1.x Phase 9, only {@link RateLimited} is implemented. The remaining
 * permitted variants (AwaitChild, AwaitTimer, AwaitExternal, AwaitApproval) are
 * declared so downstream code can write exhaustive switch statements, but their
 * record bodies land when each variant ships an enforcer.
 *
 * <p>Authority: ADR-0070 (Cursor Flow + Skill Capacity Runtime); CLAUDE.md Rule 41
 * (Skill Capacity Matrix); CLAUDE.md Rule 41.b (ResilienceContract runtime
 * enforcement).
 */
public sealed interface SuspendReason
        permits SuspendReason.RateLimited,
                SuspendReason.AwaitChild,
                SuspendReason.AwaitTimer,
                SuspendReason.AwaitExternal,
                SuspendReason.AwaitApproval {

    /**
     * Skill-capacity pool was exhausted. The scheduler should park this agent process
     * on the affected skill's wait-queue and free the OS thread for unrelated work.
     *
     * @param skill the skill id that exhausted (matches {@code docs/governance/skill-capacity.yaml})
     * @param code  the canonical reason code; today only {@code SKILL_CAPACITY_EXCEEDED}
     */
    record RateLimited(String skill, String code) implements SuspendReason {
        public static final String SKILL_CAPACITY_EXCEEDED = "SKILL_CAPACITY_EXCEEDED";
    }

    /** Placeholder for the four other ADR-0019 variants — bodies land per future phase. */
    record AwaitChild() implements SuspendReason {}
    record AwaitTimer() implements SuspendReason {}
    record AwaitExternal() implements SuspendReason {}
    record AwaitApproval() implements SuspendReason {}
}
