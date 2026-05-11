package ascend.springai.runtime.spi.knowledge;

import java.io.InputStream;
import java.util.List;

/**
 * SPI: extract structured text blocks from documents, preserving layout.
 *
 * Default impl: Apache Tika 3.3.0 AutoDetectParser (best-effort;
 * no layout awareness for complex PDFs).
 * Optional sidecar impl: spring-ai-ascend-docling-starter (Docling-serve
 * REST API; IBM Granite-Docling; LF AI&Data donation 2026).
 */
public interface LayoutParser {

    /**
     * Parse an input stream of a document (PDF, DOCX, HTML, etc.) and
     * return an ordered list of content blocks with layout metadata.
     */
    List<ContentBlock> parse(InputStream document, ParseOptions options);

    record ParseOptions(
            String mimeTypeHint,
            boolean extractTables,
            boolean extractImages
    ) {
        public static ParseOptions defaults() {
            return new ParseOptions(null, false, false);
        }
    }

    // scope: process-internal — ContentBlock and BoundingBox are intermediate parse
    // artifacts bounded to a single document parse call; never persisted or transmitted across tenants.
    record ContentBlock(
            BlockType type,
            String text,
            int pageNumber,
            BoundingBox boundingBox
    ) {}

    enum BlockType {
        PARAGRAPH, HEADING, TABLE_ROW, LIST_ITEM, CAPTION, FOOTER, OTHER
    }

    // scope: process-internal (see ContentBlock above)
    record BoundingBox(double x, double y, double width, double height) {}
}
