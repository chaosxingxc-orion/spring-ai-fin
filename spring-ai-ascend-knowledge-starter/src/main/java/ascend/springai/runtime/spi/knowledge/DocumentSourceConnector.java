package ascend.springai.runtime.spi.knowledge;

import java.util.Iterator;

/**
 * SPI: pull documents from an external source (S3, web, GitHub, etc.)
 * and emit them for ingestion into the knowledge pipeline.
 *
 * Multiple implementations may be registered; the knowledge starter's
 * IngestionOrchestrator fans out to all connectors matching the
 * tenant's configured sources.
 *
 * Rule 11: tenantId carried on every RawDocument.
 */
public interface DocumentSourceConnector {

    /** Human-readable identifier for this connector (e.g. "s3", "github"). */
    String connectorId();

    /**
     * Emit all documents from the source for the given tenant config.
     * The caller is responsible for closing the iterator.
     */
    Iterator<RawDocument> fetch(String tenantId, SourceConfig config);

    record RawDocument(
            String tenantId,
            String sourceUri,
            String mimeType,
            byte[] content,
            java.util.Map<String, String> metadata
    ) {}

    record SourceConfig(
            java.util.Map<String, String> properties
    ) {}
}
