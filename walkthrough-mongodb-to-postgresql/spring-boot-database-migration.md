# Spring Boot Database Migration Walkthrough: MongoDB to PostgreSQL

This document describes the migration of a generic application from a document database (MongoDB) to a relational database (PostgreSQL).

## Final Implementation

### 1. Dependencies

```xml
<!-- Relational database dependencies -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
</dependency>
```

### 2. Configuration

**File**: `application.yaml`
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/application_db
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
  flyway:
    enabled: true
    baseline-on-migrate: true
```

### 3. Database Migration Scripts

**File**: `resources/db.migration/V1__create_records_table.sql`
```sql
-- Create main table with JSONB column for flexible data storage
CREATE TABLE IF NOT EXISTS records (
    id VARCHAR(255) PRIMARY KEY,
    data JSONB NOT NULL,
);
```

### 4. Domain Models

The application uses two separate model types:

**Domain Model**: `model/Record.kt`
```kotlin
// Domain model for business logic
data class Record(
    val id: String,
    val title: String?,
    val description: String?,
    val contactPoint: ContactInfo?
)
```

**Database Entity**: `model/RecordEntity.kt`
```kotlin
// Database entity for persistence
@Entity
@Table(name = "records")
data class RecordEntity(
    @Id
    @Column(name = "id")
    val id: String,

    @Type(JsonType::class)
    @Column(name = "data", columnDefinition = "jsonb", nullable = false)
    val data: Record
)
```

### 5. Repository Layer

**File**: `repository/RecordRepository.kt`
```kotlin
interface RecordRepository : JpaRepository<RecordEntity, String>
```

### 6. Service Layer

**File**: `service/RecordService.kt`
```kotlin
@Service
class RecordService(
    private val repository: RecordRepository
) {
    fun save(record: Record): Record {
        val entity = RecordEntity(
            id = record.id,
            data = record
        )
        return repository.save(entity).values
    }

    fun findById(id: String): Record? {
        return repository.findById(id)
            .map { it.values }
            .orElse(null)
    }
}
```

### 7. Controller Layer

**File**: `controller/RecordController.kt`
```kotlin
// Controller layer should be unchanged
@RestController
@RequestMapping("/api/records")
class RecordController(
    private val recordService: RecordService
) {
    @GetMapping("/{id}")
    fun getRecord(@PathVariable id: String): ResponseEntity<Record> {
        val record = recordService.findById(id)
        return record?.let { ResponseEntity.ok(it) }
            ?: ResponseEntity.notFound().build()
    }
    
    @PostMapping
    fun createRecord(@RequestBody record: Record): ResponseEntity<Record> {
        val saved = recordService.save(record)
        return ResponseEntity.ok(saved)
    }
}
```

---

## Key Architecture Decisions

### Separation of Domain and Persistence Models

The application uses two distinct model types:
- **Domain Model (`Record`)**: Used by business logic and API layer
- **Entity Model (`RecordEntity`)**: Used by persistence layer with JPA annotations

This separation allows the API to remain stable while database schema evolves.

### JSONB Column for Flexibility

The `data` JSONB column stores the complete domain model, providing:
- Schema flexibility similar to document databases
- Full ACID transaction support from PostgreSQL
- Efficient querying with GIN indexes

### Entity Conversion Pattern

The service layer handles conversion between domain and entity models:
- `save()`: Domain → Entity → Database
- `findById()`: Database → Entity → Domain

This keeps controllers clean and maintains separation of concerns.

---

## Migration Checklist

When performing a similar migration:

- Update dependencies (add JPA, PostgreSQL, Flyway)
- Create database schema with Flyway migration
- Create database entity classes with JPA annotations
- Implement JPA repositories
- Update service layer with entity conversion logic
- Add custom JSON formatters for JSONB columns
- Update application configuration (datasource, JPA, Flyway)
- Update deployment configuration (environment variables, secrets)
- Update tests with Testcontainers PostgreSQL
- Add database indexes for performance
- Run data migration scripts (ETL process)
