package ascend.springai.runtime.knowledge;

import ascend.springai.runtime.spi.knowledge.DocumentSourceConnector;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

public class DocumentSourceConnectorRegistry {

    private final Map<String, DocumentSourceConnector> byId;

    public DocumentSourceConnectorRegistry(List<DocumentSourceConnector> connectors) {
        this.byId = connectors.stream().collect(
            Collectors.toUnmodifiableMap(
                DocumentSourceConnector::connectorId,
                Function.identity(),
                (a, b) -> { throw new IllegalArgumentException(
                    "Duplicate DocumentSourceConnector connectorId: " + a.connectorId()); }
            )
        );
    }

    public DocumentSourceConnector find(String connectorId) {
        DocumentSourceConnector c = byId.get(connectorId);
        if (c == null) throw new IllegalArgumentException("No DocumentSourceConnector for id: " + connectorId);
        return c;
    }

    public java.util.Collection<DocumentSourceConnector> all() {
        return byId.values();
    }
}
