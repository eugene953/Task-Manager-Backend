# ==========================================
# Stage 1: Build Java Spring Boot Application
# ==========================================
FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder

WORKDIR /app

# Copy POM for dependency resolution caching
COPY pom.xml ./

# Download dependencies offline (cached layer)
RUN mvn dependency:go-offline -B

# Copy project source code
COPY src ./src

# Build production jar skipping tests (tests should be run in CI phase)
RUN mvn clean package -DskipTests -B

# ==========================================
# Stage 2: Minimal & Secure Runtime
# ==========================================
FROM eclipse-temurin:21-jre-alpine AS runner

WORKDIR /app

# Create unprivileged system user for improved security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy built jar from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Adjust ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Spring Boot Server Port
EXPOSE 5000

# JVM container options
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
