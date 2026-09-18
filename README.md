# TaskFlow API (Backend)

The backend service for the TaskFlow application, built with **Java 21**, **Spring Boot 3.4.3**, **Spring Security (JWT)**, and **Spring Data JPA** connecting to a managed **PostgreSQL database (Supabase)**.

---

## 🏛 Architecture Overview

The backend is structured following a standard **Layered Clean Architecture** pattern:

```
task-manager-api/
├── src/main/java/com/taskmanager/
│   ├── config/              # Cross-origin (CORS) & application configuration
│   ├── controller/          # REST API controllers & endpoint definitions
│   │   ├── AuthController.java
│   │   └── TaskController.java
│   ├── dto/                 # Request & response data transfer objects with Jakarta validation
│   │   ├── AuthRequest.java
│   │   ├── AuthResponse.java
│   │   ├── RegisterRequest.java
│   │   ├── TaskRequest.java
│   │   └── TaskResponse.java
│   ├── entity/              # JPA database entities & status enumerations
│   │   ├── Task.java
│   │   ├── TaskStatus.java  (TODO, IN_PROGRESS, COMPLETED)
│   │   └── User.java
│   ├── exception/           # Global exception handler & custom API exceptions
│   │   ├── ApiException.java
│   │   ├── GlobalExceptionHandler.java
│   │   └── ResourceNotFoundException.java
│   ├── repository/          # Spring Data JPA repositories with query filtering
│   │   ├── TaskRepository.java
│   │   └── UserRepository.java
│   ├── security/            # Spring Security 6 stateless JWT authentication chain
│   │   ├── JwtAuthenticationFilter.java
│   │   ├── JwtService.java
│   │   ├── SecurityConfig.java
│   │   ├── UserDetailsServiceImpl.java
│   │   └── UserPrincipal.java
│   └── service/             # Business logic layer
│       ├── AuthService.java
│       └── TaskService.java
└── src/main/resources/
    └── application.properties # Supabase connection, HikariCP, and JWT settings
```

### Key Architectural Layers:
1. **Controller Layer**: Handles incoming HTTP requests, validates incoming DTO payloads with `@Valid`, and delegates business operations to services.
2. **Service Layer**: Implements core business logic, user ownership checks, search and status filtering, and BCrypt password hashing.
3. **Repository Layer**: Utilizes Spring Data JPA interfaces for database operations, custom JPQL queries for user-isolated task queries, and database pagination/search.
4. **Security Layer**: Stateless authentication with custom JWT token parser/validator filter (`JwtAuthenticationFilter`), BCrypt password encoder, and role-based / principal annotations (`@AuthenticationPrincipal`).
5. **Exception Handling Layer**: Centralized `@RestControllerAdvice` formatting errors into consistent JSON responses with error status codes and field-level validation messages.

---

## 🛠 Technical Choices & Rationale

| Tool / Technology | Choice | Rationale |
| :--- | :--- | :--- |
| **Language & Runtime** | Java 21 (LTS) | Modern language features (virtual threads ready, pattern matching, record-like structures) and long-term stability. |
| **Framework** | Spring Boot 3.4.3 | Enterprise-grade standard for microservices and RESTful APIs, offering dependency injection, auto-configuration, and robust ecosystem. |
| **Persistence** | Spring Data JPA (Hibernate) | ORM abstraction facilitating automated schema management, relationship mappings (`@ManyToOne`), and audit timestamps (`@CreationTimestamp`, `@UpdateTimestamp`). |
| **Database** | PostgreSQL (Supabase Pooler) | Reliable ACID-compliant relational storage accessed via transaction-mode pooler over IPv4. |
| **Connection Pooling** | HikariCP | High-performance, lightweight JDBC connection pool with configurable idle and connection timeouts. |
| **Security & Auth** | Spring Security 6 + JJWT 0.12.6 | Stateless JWT session architecture using HMAC-SHA256 tokens; eliminates server session state and enables horizontal scalability. |
| **Validation** | Jakarta Bean Validation | Declarative request payload validation (`@NotBlank`, `@Size`, `@Email`) providing instant feedback on malformed input. |
| **Containerization** | Eclipse Temurin 21 (Alpine) | Multi-stage Docker build producing a minimal, lightweight, non-root runner image. |

---

## 📋 REST API Endpoints

### Authentication (`/api/auth`)
| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `POST` | `/api/auth/register` | Register a new user account | ❌ |
| `POST` | `/api/auth/login` | Authenticate user and obtain JWT token | ❌ |

### Task Management (`/api/tasks`)
| Method | Endpoint | Query Parameters | Description | Auth Required |
| :--- | :--- | :--- | :--- | :---: |
| `GET` | `/api/tasks` | `status` (optional), `search` (optional) | Fetch all tasks belonging to current user | ✅ |
| `GET` | `/api/tasks/{id}` | — | Get task details by ID (user-isolated) | ✅ |
| `POST` | `/api/tasks` | — | Create a new task | ✅ |
| `PUT` | `/api/tasks/{id}` | — | Update existing task title, description, or status | ✅ |
| `DELETE` | `/api/tasks/{id}` | — | Delete a task belonging to current user | ✅ |

---

## 🚀 Installation & Execution Instructions

### Prerequisites
- **JDK 21** or higher
- **Maven 3.8+** (or use the included `./mvnw` wrapper)
- Active PostgreSQL connection or Docker

---

### Method 1: Run Locally with Maven Wrapper

1. **Navigate to the Backend Directory**:
   ```bash
   cd task-manager-api
   ```

2. **Configure Database Connection**:
   The default configuration connects to the Supabase PostgreSQL database in `src/main/resources/application.properties`. You can override properties via environment variables or directly in `application.properties`:
   ```properties
   spring.datasource.url=jdbc:postgresql://aws-0-eu-north-1.pooler.supabase.com:6543/postgres?sslmode=require&prepareThreshold=0
   spring.datasource.username=postgres.bqoyrbvycajclnykgjwx
   spring.datasource.password=KhYAVmDZQ78JtujS
   server.port=5000
   ```

3. **Build the Application**:
   ```bash
   ./mvnw clean package -DskipTests
   ```
   *(On Windows Command Prompt: `mvnw.cmd clean package -DskipTests`)*

4. **Run the Spring Boot Application**:
   ```bash
   ./mvnw spring-boot:run
   ```
   *(Or run the generated JAR: `java -jar target/task-manager-api-0.0.1-SNAPSHOT.jar`)*

5. **Verify the API**:
   The API will start on port `5000`:
   ```bash
   curl http://localhost:5000/api/tasks
   ```
   *(Expected response: `401 Unauthorized` since authentication token is required).*

---

### Method 2: Run with Docker

1. **Build the Docker Image**:
   ```bash
   docker build -t taskflow-backend .
   ```

2. **Run the Container**:
   ```bash
   docker run -d \
     -p 5000:5000 \
     --name taskflow-backend \
     taskflow-backend
   ```

---

## 🔒 Security Configuration

- **Stateless Sessions**: `SessionCreationPolicy.STATELESS` configured in `SecurityConfig`.
- **JWT Lifespan**: Default token expiration is 24 hours (86,400,000 ms).
- **Password Security**: Passwords are saved with BCrypt one-way adaptive hashing.
- **Cross-Origin Resource Sharing (CORS)**: Configured to accept incoming requests from `http://localhost:5173`, `http://localhost:3000`, and `http://localhost`.
