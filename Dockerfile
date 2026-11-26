# syntax=docker/dockerfile:1
# Offline API da calculadora do regime regular.
# Gera calculadora/db/calculadora-pro.db com o Flyway do projeto e sobe o perfil offline.
# Build: docker build -t calculadora-rtc-regime-regular:local .

FROM eclipse-temurin:25-jdk-noble AS build

WORKDIR /src

COPY .mvn .mvn
COPY mvnw pom.xml ./
COPY flyway flyway

RUN sed -i 's/\r$//' mvnw \
    && chmod +x mvnw \
    && find flyway -type f -exec sed -i 's/\r$//' {} + \
    && mkdir -p calculadora/db

RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw -B -ntp flyway:migrate -Dflyway.configFiles=./flyway/flyway-pro.conf

COPY src src

RUN --mount=type=cache,target=/root/.m2 \
    ./mvnw -B -ntp -Dmaven.test.skip=true package

FROM eclipse-temurin:25-jre-noble

ENV TZ=America/Sao_Paulo \
    SPRING_PROFILES_ACTIVE=offline \
    JAVA_TOOL_OPTIONS="-XX:-UseBASE64Intrinsics -Duser.timezone=America/Sao_Paulo"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --home-dir /app --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=build --chown=app:app /src/target/api-regime-geral.jar /app/app.jar
COPY --from=build --chown=app:app /src/calculadora/db/calculadora-pro.db /app/calculadora/db/calculadora-pro.db

USER app

EXPOSE 8080 9101

HEALTHCHECK --interval=15s --timeout=5s --start-period=120s --retries=8 \
    CMD curl -fsS http://127.0.0.1:9101/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
