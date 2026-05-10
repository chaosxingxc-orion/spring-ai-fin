package fin.springai.runtime.docling;

import fin.springai.runtime.spi.knowledge.LayoutParser;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.InputStream;
import java.util.List;

/**
 * L0 sentinel for the Docling layout-parser adapter.
 * Activated only when springai.fin.docling.enabled=true.
 * REST client wiring lands in W2.
 */
class NotImplementedYetDoclingLayoutParser implements LayoutParser {

    private static final Logger LOG = LoggerFactory.getLogger(NotImplementedYetDoclingLayoutParser.class);
    private static final String METRIC = "springai_fin_docling_adapter_not_implemented_total";
    private static final String MSG =
            "L0: Docling adapter enabled but REST client not yet wired. " +
            "W2 will add RestClient wiring. baseUrl=%s";

    private final MeterRegistry registry;
    private final DoclingProperties properties;

    NotImplementedYetDoclingLayoutParser(MeterRegistry registry, DoclingProperties properties) {
        this.registry = registry;
        this.properties = properties;
        LOG.info("spring-ai-fin-docling-starter activated at L0; REST client pending W2; baseUrl={}", properties.getBaseUrl());
    }

    @Override
    public List<ContentBlock> parse(InputStream document, ParseOptions options) {
        registry.counter(METRIC, "spi", "LayoutParser", "method", "parse").increment();
        LOG.warn("L0: Docling parse called before W2 REST client");
        throw new IllegalStateException(String.format(MSG, properties.getBaseUrl()));
    }
}
