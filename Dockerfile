# Cycle 23: ローカル試運転用イメージ（外部配布・一般公開は禁止）
# multi-stage build。最終イメージへMaven・ソース・.git・docs・tmp・ログ・.envを含めない。

# ---------- build stage ----------
FROM maven:3.9.16-eclipse-temurin-17 AS builder
WORKDIR /build

# 依存解決を先にキャッシュする（pom.xmlだけを先にCOPY）
COPY pom.xml ./
RUN mvn -B -DskipTests dependency:go-offline

# アプリのソースだけをCOPY（リポジトリ全体はCOPYしない）
COPY src/main ./src/main

# 自動テストは通常のホストDBへ書き込む可能性があるため、image build中は実行しない
RUN mvn -B -DskipTests clean package

# ---------- runtime stage ----------
FROM eclipse-temurin:17-jre
WORKDIR /app

# 非rootユーザーで実行する
RUN groupadd --system appgroup && useradd --system --gid appgroup --create-home appuser

COPY --from=builder /build/target/*.jar /app/app.jar
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
