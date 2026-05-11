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

    /**
     * Checks that every required field declared in the pinned response schemas also appears
     * with a compatible type in the live spec. $ref references are resolved against
     * components/schemas. This catches response-shape drift that path-only comparison misses.
     */
    @SuppressWarnings("unchecked")
    static ComparisonResult compareResponseSchemas(Map<String, Object> pinned, Map<String, Object> live) {
        List<String> violations = new ArrayList<>();

        Map<String, Object> pinnedSchemas = resolveSchemas(pinned);
        Map<String, Object> liveSchemas = resolveSchemas(live);
        Map<String, Object> pinnedPaths = (Map<String, Object>) pinned.getOrDefault("paths", Map.of());
        Map<String, Object> livePaths = (Map<String, Object>) live.getOrDefault("paths", Map.of());

        for (Map.Entry<String, Object> pathEntry : pinnedPaths.entrySet()) {
            String path = pathEntry.getKey();
            if (!livePaths.containsKey(path)) continue; // already caught by compare()
            Map<String, Object> pinnedOps = (Map<String, Object>) pathEntry.getValue();
            Map<String, Object> liveOps = (Map<String, Object>) livePaths.get(path);
            for (Map.Entry<String, Object> opEntry : pinnedOps.entrySet()) {
                String method = opEntry.getKey();
                if (method.startsWith("x-") || !liveOps.containsKey(method)) continue;
                Map<String, Object> pinnedOp = (Map<String, Object>) opEntry.getValue();
                Map<String, Object> liveOp = (Map<String, Object>) liveOps.get(method);
                Map<String, Object> pinnedResponses = (Map<String, Object>) pinnedOp.getOrDefault("responses", Map.of());
                Map<String, Object> liveResponses = (Map<String, Object>) liveOp.getOrDefault("responses", Map.of());
                for (String code : pinnedResponses.keySet()) {
                    Map<String, Object> pinnedSchema = extractJsonSchema(pinnedResponses.get(code), pinnedSchemas);
                    Map<String, Object> liveSchema = extractJsonSchema(liveResponses.get(code), liveSchemas);
                    if (pinnedSchema == null || liveSchema == null) continue;
                    checkRequiredFields(method.toUpperCase() + " " + path + " " + code,
                            pinnedSchema, pinnedSchemas, liveSchema, liveSchemas, violations);
                }
            }
        }

        return new ComparisonResult(violations.isEmpty(), violations);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> resolveSchemas(Map<String, Object> spec) {
        Map<String, Object> components = (Map<String, Object>) spec.getOrDefault("components", Map.of());
        return (Map<String, Object>) components.getOrDefault("schemas", Map.of());
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> extractJsonSchema(Object responseObj, Map<String, Object> schemas) {
        if (!(responseObj instanceof Map)) return null;
        Map<String, Object> response = (Map<String, Object>) responseObj;
        Map<String, Object> content = (Map<String, Object>) response.get("content");
        if (content == null) return null;
        Map<String, Object> json = (Map<String, Object>) content.get("application/json");
        if (json == null) return null;
        Map<String, Object> schema = (Map<String, Object>) json.get("schema");
        if (schema == null) return null;
        return resolveRef(schema, schemas);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> resolveRef(Map<String, Object> schema, Map<String, Object> schemas) {
        String ref = (String) schema.get("$ref");
        if (ref == null) return schema;
        String name = ref.substring(ref.lastIndexOf('/') + 1);
        Object resolved = schemas.get(name);
        return resolved instanceof Map ? (Map<String, Object>) resolved : null;
    }

    @SuppressWarnings("unchecked")
    private static void checkRequiredFields(String context,
            Map<String, Object> pinnedSchema, Map<String, Object> pinnedSchemas,
            Map<String, Object> liveSchema, Map<String, Object> liveSchemas,
            List<String> violations) {
        List<String> required = (List<String>) pinnedSchema.getOrDefault("required", List.of());
        Map<String, Object> pinnedProps = (Map<String, Object>) pinnedSchema.getOrDefault("properties", Map.of());
        Map<String, Object> liveSchemaResolved = resolveRef(liveSchema, liveSchemas);
        if (liveSchemaResolved == null) {
            violations.add(context + ": live response schema could not be resolved");
            return;
        }
        Map<String, Object> liveProps = (Map<String, Object>) liveSchemaResolved.getOrDefault("properties", Map.of());
        for (String field : required) {
            if (!liveProps.containsKey(field)) {
                violations.add(context + ": required field '" + field + "' missing from live response schema");
                continue;
            }
            Map<String, Object> pinnedField = (Map<String, Object>) pinnedProps.getOrDefault(field, Map.of());
            Map<String, Object> liveField = (Map<String, Object>) liveProps.get(field);
            String pinnedType = (String) pinnedField.get("type");
            String liveType = (String) ((Map<?, ?>) liveField).get("type");
            if (pinnedType != null && !pinnedType.equals(liveType)) {
                violations.add(context + ": field '" + field + "' type changed from '" + pinnedType + "' to '" + liveType + "'");
            }
        }
    }
}
