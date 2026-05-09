# Third-Party Notices

This file summarizes the open-source licenses of all Tier C dependencies
(infrastructure servers + Python OSS sidecars). Full license texts are
available in each cloned repo under `third_party/<name>/LICENSE` or at
the upstream URLs below.

## Infrastructure servers (Docker images)

| Name | License | Upstream |
|---|---|---|
| Postgres + pgvector | PostgreSQL License (permissive); pgvector extension: Apache-2.0 | https://github.com/pgvector/pgvector |
| Keycloak | Apache-2.0 | https://github.com/keycloak/keycloak |
| Temporal server | MIT | https://github.com/temporalio/temporal |
| Redpanda | BSL-1.1 (converts to Apache-2.0 after 4 years) | https://github.com/redpanda-data/redpanda |
| MinIO | AGPL-3.0 | https://github.com/minio/minio |
| Loki | AGPL-3.0 | https://github.com/grafana/loki |
| Grafana | AGPL-3.0 | https://github.com/grafana/grafana |
| Prometheus | Apache-2.0 | https://github.com/prometheus/prometheus |
| Tempo | AGPL-3.0 | https://github.com/grafana/tempo |
| OPA | Apache-2.0 | https://github.com/open-policy-agent/opa |
| OpenSearch | Apache-2.0 | https://github.com/opensearch-project/OpenSearch |

## Python community OSS sidecars (cloned source)

| Name | License | Upstream | Notes |
|---|---|---|---|
| mem0 | Apache-2.0 | https://github.com/mem0ai/mem0 | Full license text in `third_party/mem0/LICENSE` after cloning |
| Graphiti | Apache-2.0 | https://github.com/getzep/graphiti | Full license text in `third_party/graphiti/LICENSE` |
| Cognee | Apache-2.0 | https://github.com/topoteretes/cognee | Full license text in `third_party/cognee/LICENSE` |
| Docling-serve | Apache-2.0 | https://github.com/docling-project/docling-serve | IBM/LF AI&Data donation; full license text in `third_party/docling-serve/LICENSE` |
| RAGFlow | Apache-2.0 | https://github.com/infiniflow/ragflow | Full license text in `third_party/ragflow/LICENSE` |

## Usage terms summary

All five Python sidecars are licensed under Apache-2.0 which permits use,
modification, and distribution (including commercial) subject to attribution
and license notice preservation. They are consumed as standalone services
(via REST API) and are not linked into the SDK JARs.

Redpanda uses BSL-1.1: internal production use is permitted; resale as a
managed streaming service requires a commercial agreement. Evaluate this
restriction if the platform is offered as SaaS.

AGPL-3.0 components (MinIO, Loki, Grafana, Tempo): these are accessed as
standalone services. Their AGPL requirement to provide source code applies
to the service itself, not to the SDK that calls them via REST/gRPC APIs.
Consult legal counsel before embedding any AGPL library directly in the SDK JARs.
