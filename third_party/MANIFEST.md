# Third-Party Tier C Manifest

All entries in this file are evaluated and pinned as of 2026-05-10.
Source clones live in `third_party/<name>/` (gitignored -- run `clone-all.sh` to populate).
Docker images are pulled by `ops/compose/` overlays.

## Section A: Infrastructure servers (Docker images)

| Name | Docker Image | Version Tag | Purpose | License |
|---|---|---|---|---|
| Postgres + pgvector | `pgvector/pgvector` | `pg16` | Primary data store + vector extension | PostgreSQL License + Apache-2.0 |
| Keycloak | `quay.io/keycloak/keycloak` | `25.0` | OIDC identity provider (dev) | Apache-2.0 |
| Temporal server | `temporalio/auto-setup` | `1.25.2` | Workflow orchestration server | MIT |
| Redpanda | `redpandadata/redpanda` | `v24.3.x` | Kafka-compatible event bus | BSL-1.1 |
| MinIO | `minio/minio` | `RELEASE.2025-05-01T14-51-17Z` | Object storage | AGPL-3.0 |
| Loki | `grafana/loki` | `3.4.x` | Log aggregation | AGPL-3.0 |
| Grafana | `grafana/grafana` | `11.6.x` | Dashboards | AGPL-3.0 |
| Prometheus | `prom/prometheus` | `v3.x` | Metrics store | Apache-2.0 |
| Tempo | `grafana/tempo` | `2.7.x` | Distributed tracing | AGPL-3.0 |
| OPA | `openpolicyagent/opa` | `0.65.0` | Policy engine daemon | Apache-2.0 |
| OpenSearch | `opensearchproject/opensearch` | `2.x` | Full-text search (optional) | Apache-2.0 |

## Section B: Python community OSS sidecars (git-cloned)

These repos are cloned with `git clone --depth 1 --branch <tag>` into `third_party/<name>/`.
Run `third_party/clone-all.sh` to populate after checking out this repo.

| Name | Upstream | Tag | SHA (HEAD at tag) | License | SDK adapter | Intended use |
|---|---|---|---|---|---|---|
| **mem0** | `https://github.com/mem0ai/mem0.git` | `v2.0.2` | `9043fbf61e60c9e2f2e60ddddc849adebc273608` | Apache-2.0 | `spring-ai-ascend-mem0-starter` | Long-term hierarchical memory; implements `LongTermMemoryRepository` SPI |
| **Graphiti** | `https://github.com/getzep/graphiti.git` | `v0.29.0` | `56cf7b369a671084112ad86d64411362d19f6d56` | Apache-2.0 | `spring-ai-ascend-graphmemory-starter` | Knowledge-graph memory; implements `GraphMemoryRepository` SPI |
| **Cognee** | `https://github.com/topoteretes/cognee.git` | `v1.0.9` | `b0f513b43df8cb2d62063e3fb43e673738fd0552` | Apache-2.0 | none (evaluation alternative to Graphiti; cycle-15 picks one) | Graph memory evaluation alternative |
| **Docling-serve** | `https://github.com/docling-project/docling-serve.git` | `v1.18.0` | `60846e5264c9b5e401aa133c5d654a7b2fe03228` | Apache-2.0 | `spring-ai-ascend-docling-starter` | Layout-aware PDF parsing; implements `LayoutParser` SPI |
| **RAGFlow** | `https://github.com/infiniflow/ragflow.git` | `v0.25.2` | `57b24be6d6db2f46265eb10b06ddc2e46b7c2728` | Apache-2.0 | none (alt RAG platform; consumer integrates via RAGFlow API) | Full-stack RAG platform alternative |

## How to clone Section B repos

```sh
#!/bin/sh
# Run from the repo root: sh third_party/clone-all.sh
cd third_party
git clone --depth 1 --branch v2.0.2   https://github.com/mem0ai/mem0.git       mem0
git clone --depth 1 --branch v0.29.0  https://github.com/getzep/graphiti.git    graphiti
git clone --depth 1 --branch v1.0.9   https://github.com/topoteretes/cognee.git cognee
git clone --depth 1 --branch v1.18.0  https://github.com/docling-project/docling-serve.git docling-serve
git clone --depth 1 --branch v0.25.2  https://github.com/infiniflow/ragflow.git ragflow
```

## Notes

- All Docker image versions in Section A are pinned to a specific release channel; pin to exact digest in `ops/compose/` for reproducibility.
- Section B SHAs were captured on 2026-05-10. Re-verify on each pull-and-test cycle.
- Cognee and Graphiti are both evaluated for `GraphMemoryRepository` SPI; cycle-15 picks one. Both are cloned so the team can run side-by-side evaluation.
- RAGFlow is NOT wired into any SDK adapter; consumers integrate via RAGFlow's own REST API if they choose this platform.
