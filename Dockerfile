# spring-ai-ascend agent-platform Dockerfile.
#
# Per docs/cross-cutting/supply-chain-controls.md: distroless runtime + digest pin.
# The :nonroot tag below should be replaced with a sha256 digest in CI before
# release; see ops/runbooks/digest-pin.md (W2+).
#
# Build stage uses the official Maven image (Java 21 + Maven 3.9). Runtime
# stage is distroless Java 21.

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml ./
COPY agent-platform/pom.xml ./agent-platform/
COPY agent-runtime/pom.xml ./agent-runtime/
COPY agent-eval/pom.xml ./agent-eval/
# Pre-fetch deps to leverage Docker layer cache.
RUN mvn -B -ntp -pl agent-platform -am dependency:go-offline -DskipTests
COPY agent-platform/src ./agent-platform/src
COPY agent-runtime/src ./agent-runtime/src
COPY agent-eval/src ./agent-eval/src
RUN mvn -B -ntp -pl agent-platform -am package -DskipTests

FROM gcr.io/distroless/java21-debian12:nonroot
WORKDIR /app
COPY --from=build /workspace/agent-platform/target/agent-platform-*.jar /app/app.jar

ENV APP_POSTURE=dev
ENV APP_SHA=dev

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
