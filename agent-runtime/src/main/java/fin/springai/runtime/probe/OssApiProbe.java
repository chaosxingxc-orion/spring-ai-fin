package fin.springai.runtime.probe;

/*
 * U1 -> U2 promotion probe for agent-runtime critical-path deps.
 *
 * Imports cited APIs from each pinned dep. Per
 * docs/cross-cutting/oss-bill-of-materials.md sec-3 (Spring AI 1.0.7,
 * Temporal 1.34.0, MCP 2.0.0-M2 verified at U1; this probe advances them to
 * U2 once `mvn compile` passes).
 */

// Spring AI
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.vectorstore.VectorStore;

// Temporal Java SDK
import io.temporal.workflow.Workflow;
import io.temporal.workflow.WorkflowInterface;
import io.temporal.workflow.WorkflowMethod;
import io.temporal.activity.ActivityInterface;
import io.temporal.activity.ActivityMethod;
import io.temporal.client.WorkflowClient;

// MCP Java SDK -- imports below are placeholders pending 2.0.0 GA;
// the SDK at 2.0.0-M2 is a milestone with API still in flux. The actual
// class names are reserved at U1 doc-verified; W3 wave commits the real
// surface once the team probes the milestone artifact.
// import io.modelcontextprotocol.sdk.... <-- pending W3

// Apache Tika
import org.apache.tika.parser.AutoDetectParser;
import org.apache.tika.metadata.Metadata;

public final class OssApiProbe {

    private OssApiProbe() {}

    public static String probe() {
        Class<?>[] cites = new Class<?>[]{
                ChatClient.class,
                ChatModel.class,
                EmbeddingModel.class,
                VectorStore.class,
                Workflow.class,
                WorkflowInterface.class,
                WorkflowMethod.class,
                ActivityInterface.class,
                ActivityMethod.class,
                WorkflowClient.class,
                AutoDetectParser.class,
                Metadata.class
        };
        StringBuilder sb = new StringBuilder("agent-runtime U2 probe: ");
        for (Class<?> c : cites) {
            sb.append(c.getSimpleName()).append(' ');
        }
        return sb.toString();
    }

    public static int temporalGetVersionShape() {
        // ADR-03 + agent-runtime/temporal/ARCHITECTURE.md sec-10.1 cite the
        // Workflow.getVersion(String, int, int) signature for workflow versioning.
        // This compile-time reference proves the method exists at the pinned
        // SDK version (1.34.0). Runtime invocation is illegal outside a
        // workflow context -- this probe never calls the method.
        if (false) {
            // unreachable; here purely to type-check the signature.
            return Workflow.getVersion("never", 0, 1);
        }
        return -1;
    }
}
