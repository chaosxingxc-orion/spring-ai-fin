package fin.springai.runtime.knowledge;

import fin.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.InputStream;
import java.util.List;

/**
 * L0 sentinel: no Tika or Docling impl wired at W0.
 * Replaced by Tika 3.3.0 default impl in W1; optional Docling sidecar in W2.
 */
class NotConfiguredLayoutParser implements LayoutParser {

    private static final Logger LOG = LoggerFactory.getLogger(NotConfiguredLayoutParser.class);
    private static final String METRIC = "springai_fin_knowledge_layout_parser_not_configured_total";
    private static final String MSG =
            "L0: LayoutParser has no default impl yet. " +
            "Provide a @Bean LayoutParser or wait for the W1 Tika 3.3.0 default impl.";

    private final MeterRegistry registry;

    NotConfiguredLayoutParser(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public List<ContentBlock> parse(InputStream document, ParseOptions options) {
        registry.counter(METRIC, "spi", "LayoutParser", "method", "parse").increment();
        LOG.warn("L0: LayoutParser.parse called with no impl");
        throw new IllegalStateException(MSG);
    }
}
