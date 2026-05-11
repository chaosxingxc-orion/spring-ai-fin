package ascend.springai.platform.tenant;

// ThreadLocal cleared in TenantContextFilter.doFilterInternal finally{} per Rule 5.
public final class TenantContextHolder {
    private static final ThreadLocal<TenantContext> HOLDER = new ThreadLocal<>();
    private TenantContextHolder() {}
    public static TenantContext get() { return HOLDER.get(); }
    public static void set(TenantContext ctx) { HOLDER.set(ctx); }
    public static void clear() { HOLDER.remove(); }
}
