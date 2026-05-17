/**
 * agent-execution-engine SPI — ExecutorAdapter / ExecutorDefinition /
 * engine-type-specific executor interfaces.
 *
 * <p>SPI-pure package per CLAUDE.md Rule 32: imports restricted to
 * {@code java.*} + own spi siblings + the {@code agent-middleware}
 * SPI (for {@link ascend.springai.middleware.spi.HookPoint}). Enforced
 * by {@code SpiPurityGeneralizedArchTest} (E48).
 *
 * <p>Authority: ADR-0072, Layer-0 principle P-M, Rule 43.
 */
package ascend.springai.engine.spi;
