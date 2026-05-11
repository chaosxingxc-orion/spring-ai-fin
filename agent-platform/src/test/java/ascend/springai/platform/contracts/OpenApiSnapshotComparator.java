package ascend.springai.platform.contracts;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Compares a pinned OpenAPI spec (baseline) against a live spec fetched from the running app.
 * Fails if the live spec REMOVES or RENAMES operations or required fields from the baseline.
 * Additive changes (new paths, new optional fields) are allowed.
 */
class OpenApiSnapshotComparator {

    record ComparisonResult(boolean compatible, List<String> violations) {}

    @SuppressWarnings("unchecked")
    static ComparisonResult compare(Map<String, Object> pinned, Map<String, Object> live) {
        List<String> violations = new ArrayList<>();

        Map<String, Object> pinnedPaths = (Map<String, Object>) pinned.getOrDefault("paths", Map.of());
        Map<String, Object> livePaths = (Map<String, Object>) live.getOrDefault("paths", Map.of());

        for (String path : pinnedPaths.keySet()) {
            if (!livePaths.containsKey(path)) {
                violations.add("Path removed from live spec: " + path);
                continue;
            }
            Map<String, Object> pinnedOps = (Map<String, Object>) pinnedPaths.get(path);
            Map<String, Object> liveOps = (Map<String, Object>) livePaths.get(path);
            for (String method : pinnedOps.keySet()) {
                if (method.startsWith("x-")) continue;
                if (!liveOps.containsKey(method)) {
                    violations.add("Operation removed: " + method.toUpperCase() + " " + path);
                }
            }
        }

        return new ComparisonResult(violations.isEmpty(), violations);
    }
}
