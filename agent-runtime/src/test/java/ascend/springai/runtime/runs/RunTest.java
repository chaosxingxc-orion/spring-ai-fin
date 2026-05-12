package ascend.springai.runtime.runs;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatNullPointerException;

class RunTest {

    @Test
    void run_requires_tenantId() {
        assertThatNullPointerException()
            .isThrownBy(() -> new Run(UUID.randomUUID(), null, "cap", RunStatus.PENDING,
                Instant.now(), null, null, null, null))
            .withMessageContaining("tenantId");
    }

    @Test
    void run_requires_runId() {
        assertThatNullPointerException()
            .isThrownBy(() -> new Run(null, "tenant-1", "cap", RunStatus.PENDING,
                Instant.now(), null, null, null, null))
            .withMessageContaining("runId");
    }

    @Test
    void run_requires_capabilityName() {
        assertThatNullPointerException()
            .isThrownBy(() -> new Run(UUID.randomUUID(), "tenant-1", null, RunStatus.PENDING,
                Instant.now(), null, null, null, null))
            .withMessageContaining("capabilityName");
    }

    @Test
    void run_valid_construction_carries_mandatory_fields() {
        UUID id = UUID.randomUUID();
        Instant now = Instant.now();
        var run = new Run(id, "tenant-1", "llm-call", RunStatus.PENDING, now, null, null, null, 1);
        assertThat(run.runId()).isEqualTo(id);
        assertThat(run.tenantId()).isEqualTo("tenant-1");
        assertThat(run.status()).isEqualTo(RunStatus.PENDING);
    }
}
