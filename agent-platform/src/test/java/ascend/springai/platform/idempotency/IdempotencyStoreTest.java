package ascend.springai.platform.idempotency;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class IdempotencyStoreTest {

    @Test
    void devPosture_claimOrFind_returnsEmpty() {
        var store = new IdempotencyStore(new MockEnvironment().withProperty("app.posture", "dev"));
        Optional<IdempotencyStore.IdempotencyRecord> result = store.claimOrFind("t1", "key-1", "run-1");
        assertThat(result).isEmpty();
    }

    @Test
    void researchPosture_claimOrFind_throws() {
        var store = new IdempotencyStore(new MockEnvironment().withProperty("app.posture", "research"));
        assertThatThrownBy(() -> store.claimOrFind("t1", "key-1", "run-1"))
                .isInstanceOf(UnsupportedOperationException.class)
                .hasMessageContaining("posture=research");
    }

    @Test
    void prodPosture_claimOrFind_throws() {
        var store = new IdempotencyStore(new MockEnvironment().withProperty("app.posture", "prod"));
        assertThatThrownBy(() -> store.claimOrFind("t1", "key-1", "run-1"))
                .isInstanceOf(UnsupportedOperationException.class)
                .hasMessageContaining("posture=prod");
    }
}
