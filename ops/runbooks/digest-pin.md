# Image Digest Re-pin Runbook

> Owner: platform-engineering | Maturity: L0 | Posture: all | Last refreshed: 2026-05-10

## Trigger

- Base image CVE published requiring patch.
- Monthly scheduled digest rotation.
- Dependabot PR for image digest update.

## Scope

Dockerfile base image. Helm chart image tag. CI build cache.

## Prerequisites

- Docker Hub / ECR access.
- Branch write access.

## Procedure

1. Pull latest digest: `docker pull eclipse-temurin:21-jre-alpine && docker inspect eclipse-temurin:21-jre-alpine | jq '.[0].RepoDigests'`
2. Update `Dockerfile`: replace `FROM eclipse-temurin:21-jre-alpine@sha256:<old>` with new sha256 digest.
3. Update `ops/helm/spring-ai-ascend/values.yaml` image.tag if applicable.
4. Run CI: `./mvnw -B verify` -- confirms build passes with new base.
5. Open PR. Label `security-patch`.
6. After merge, verify deployed image digest matches: `kubectl get pod -o jsonpath='{.spec.containers[0].image}'`

## Verification

CI green. Trivy scan (`trivy image springaifin/agent-platform:<tag>`) shows no CRITICAL CVEs.

## Rollback

Revert Dockerfile commit. Re-trigger CI.
