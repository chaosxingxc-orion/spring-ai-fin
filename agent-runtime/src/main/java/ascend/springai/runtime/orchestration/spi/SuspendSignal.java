package ascend.springai.runtime.orchestration.spi;

import ascend.springai.runtime.runs.RunMode;

import java.util.Objects;

/**
 * Checked exception that an executor throws to request suspension.
 * The orchestrator catches it, persists the checkpoint, marks the parent run SUSPENDED,
 * and dispatches a new child run. On resume, the executor re-enters the same node
 * and receives the child's result via RunContext.suspendForChild's return value.
 *
 * Executors must not catch this exception; only the Orchestrator catches it.
 */
public final class SuspendSignal extends Exception {

    private final String parentNodeKey;
    private final Object resumePayload;
    private final RunMode childMode;
    private final ExecutorDefinition childDef;

    public SuspendSignal(String parentNodeKey, Object resumePayload,
                         RunMode childMode, ExecutorDefinition childDef) {
        super("Suspend requested at node: " + parentNodeKey);
        this.parentNodeKey = Objects.requireNonNull(parentNodeKey, "parentNodeKey is required");
        this.resumePayload = resumePayload;
        this.childMode = Objects.requireNonNull(childMode, "childMode is required");
        this.childDef = Objects.requireNonNull(childDef, "childDef is required");
    }

    public String parentNodeKey() { return parentNodeKey; }
    public Object resumePayload() { return resumePayload; }
    public RunMode childMode() { return childMode; }
    public ExecutorDefinition childDef() { return childDef; }
}
