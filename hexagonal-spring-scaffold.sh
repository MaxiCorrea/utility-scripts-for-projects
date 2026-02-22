#!/bin/bash
set -e

PROJECT_NAME=$1
BASE_PACKAGE=$2
shift 2
CONTEXTS=("$@")

if [ -z "$PROJECT_NAME" ] || [ -z "$BASE_PACKAGE" ] || [ ${#CONTEXTS[@]} -eq 0 ]; then
  echo "Uso:"
  echo "  ./mvn-ddd-multi-modules.sh <project-name> <base-package> <context1> <context2> ..."
  echo "Ejemplo:"
  echo "  ./mvn-ddd-multi-modules.sh mi-app com.empresa order inventory"
  exit 1
fi

PACKAGE_PATH=$(echo "$BASE_PACKAGE" | tr '.' '/')

echo "Creando proyecto enterprise: $PROJECT_NAME"

mkdir "$PROJECT_NAME"
cd "$PROJECT_NAME"

# =========================================
# CREAR CARPETAS FISICAS PRIMERO
# =========================================

mkdir shared-kernel

for CONTEXT in "${CONTEXTS[@]}"; do
    mkdir "$CONTEXT-context"
done

# =========================================
# ROOT POM
# =========================================

ARCHUNIT_VERSION="1.0.1"

cat > pom.xml <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>$BASE_PACKAGE</groupId>
    <artifactId>$PROJECT_NAME</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <modules>
        <module>shared-kernel</module>
EOF

for CONTEXT in "${CONTEXTS[@]}"; do
cat >> pom.xml <<EOF
        <module>$CONTEXT-context</module>
EOF
done

cat >> pom.xml <<EOF
    </modules>

    <properties>
        <java.version>1.8</java.version>
        <maven.compiler.source>\${java.version}</maven.compiler.source>
        <maven.compiler.target>\${java.version}</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <spring.boot.version>2.7.18</spring.boot.version>
        <archunit.version>$ARCHUNIT_VERSION</archunit.version>
    </properties>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>\${spring.boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>com.tngtech.archunit</groupId>
                <artifactId>archunit-junit4</artifactId>
                <version>\${archunit.version}</version>
                <scope>test</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>3.8.1</version>
                    <configuration>
                        <source>\${java.version}</source>
                        <target>\${java.version}</target>
                    </configuration>
                </plugin>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                    <version>\${spring.boot.version}</version>
                </plugin>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-surefire-plugin</artifactId>
                    <version>2.22.2</version>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>

</project>
EOF

# =========================================
# SHARED-KERNEL
# =========================================

cat > shared-kernel/pom.xml <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>$BASE_PACKAGE</groupId>
        <artifactId>$PROJECT_NAME</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>shared-kernel</artifactId>

    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

</project>
EOF

mkdir -p "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain"
mkdir -p "shared-kernel/src/test/java/$PACKAGE_PATH/shared/domain"

# --- AggregateRoot ---
cat > "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain/AggregateRoot.java" <<EOF
package $BASE_PACKAGE.shared.domain;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public abstract class AggregateRoot {

    private final List<DomainEvent> domainEvents = new ArrayList<>();

    protected void recordEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    public List<DomainEvent> pullDomainEvents() {
        List<DomainEvent> events = Collections.unmodifiableList(new ArrayList<>(domainEvents));
        domainEvents.clear();
        return events;
    }
}
EOF

# --- DomainEvent ---
cat > "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain/DomainEvent.java" <<EOF
package $BASE_PACKAGE.shared.domain;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

public abstract class DomainEvent implements Serializable {

    private final String eventId;
    private final Instant occurredOn;

    protected DomainEvent() {
        this.eventId = UUID.randomUUID().toString();
        this.occurredOn = Instant.now();
    }

    public String getEventId() {
        return eventId;
    }

    public Instant getOccurredOn() {
        return occurredOn;
    }
}
EOF

# --- ValueObject ---
cat > "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain/ValueObject.java" <<EOF
package $BASE_PACKAGE.shared.domain;

public abstract class ValueObject {

    @Override
    public abstract boolean equals(Object o);

    @Override
    public abstract int hashCode();

    @Override
    public String toString() {
        return getClass().getSimpleName();
    }
}
EOF

# --- DomainError ---
cat > "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain/DomainError.java" <<EOF
package $BASE_PACKAGE.shared.domain;

public abstract class DomainError extends RuntimeException {

    private final String errorCode;

    protected DomainError(String errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public String getErrorCode() {
        return errorCode;
    }
}
EOF

# --- UseCase port ---
cat > "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain/UseCase.java" <<EOF
package $BASE_PACKAGE.shared.domain;

public interface UseCase<C, R> {
    R execute(C command);
}
EOF

# --- UnitOfWork port ---
cat > "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain/UnitOfWork.java" <<EOF
package $BASE_PACKAGE.shared.domain;

public interface UnitOfWork {
    void commit();
}
EOF

# --- EventBus port ---
cat > "shared-kernel/src/main/java/$PACKAGE_PATH/shared/domain/EventBus.java" <<EOF
package $BASE_PACKAGE.shared.domain;

import java.util.List;

public interface EventBus {
    void publish(List<DomainEvent> events);
}
EOF

# =========================================
# CREAR CONTEXTOS
# =========================================

for CONTEXT in "${CONTEXTS[@]}"; do

echo "Creando contexto: $CONTEXT"

CONTEXT_DIR="$CONTEXT-context"
CONTEXT_ARTIFACT="$CONTEXT-context"
CONTEXT_CLASS="${CONTEXT^}"

# --- Context POM (aggregator) ---

cat > "$CONTEXT_DIR/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>$BASE_PACKAGE</groupId>
        <artifactId>$PROJECT_NAME</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>$CONTEXT_ARTIFACT</artifactId>
    <packaging>pom</packaging>

    <modules>
        <module>$CONTEXT-domain</module>
        <module>$CONTEXT-application</module>
        <module>$CONTEXT-infrastructure</module>
        <module>$CONTEXT-boot</module>
    </modules>

</project>
EOF

# =============================================
# DOMAIN (puro, sin dependencias de framework)
# =============================================

DOMAIN_PKG="$PACKAGE_PATH/$CONTEXT/domain"

mkdir -p "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/model"
mkdir -p "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/ports/in"
mkdir -p "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/ports/out"
mkdir -p "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/exceptions"
mkdir -p "$CONTEXT_DIR/$CONTEXT-domain/src/test/java/$DOMAIN_PKG/model"

cat > "$CONTEXT_DIR/$CONTEXT-domain/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>$BASE_PACKAGE</groupId>
        <artifactId>$CONTEXT_ARTIFACT</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>$CONTEXT-domain</artifactId>

    <dependencies>
        <dependency>
            <groupId>$BASE_PACKAGE</groupId>
            <artifactId>shared-kernel</artifactId>
            <version>\${project.version}</version>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

</project>
EOF

# Ejemplo: Aggregate Root en domain
cat > "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/model/${CONTEXT_CLASS}.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.domain.model;

import $BASE_PACKAGE.shared.domain.AggregateRoot;

public class $CONTEXT_CLASS extends AggregateRoot {

    private ${CONTEXT_CLASS}Id id;

    public $CONTEXT_CLASS(${CONTEXT_CLASS}Id id) {
        this.id = id;
    }

    public ${CONTEXT_CLASS}Id getId() {
        return id;
    }
}
EOF

# Ejemplo: Value Object Id
cat > "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/model/${CONTEXT_CLASS}Id.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.domain.model;

import $BASE_PACKAGE.shared.domain.ValueObject;
import java.util.Objects;
import java.util.UUID;

public final class ${CONTEXT_CLASS}Id extends ValueObject {

    private final String value;

    public ${CONTEXT_CLASS}Id(String value) {
        if (value == null || value.isEmpty()) {
            throw new IllegalArgumentException("${CONTEXT_CLASS}Id cannot be null or empty");
        }
        this.value = value;
    }

    public static ${CONTEXT_CLASS}Id generate() {
        return new ${CONTEXT_CLASS}Id(UUID.randomUUID().toString());
    }

    public String getValue() {
        return value;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        ${CONTEXT_CLASS}Id that = (${CONTEXT_CLASS}Id) o;
        return Objects.equals(value, that.value);
    }

    @Override
    public int hashCode() {
        return Objects.hash(value);
    }

    @Override
    public String toString() {
        return value;
    }
}
EOF

# Driven port (output): Repository interface en domain
cat > "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/ports/out/${CONTEXT_CLASS}Repository.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.domain.ports.out;

import $BASE_PACKAGE.$CONTEXT.domain.model.$CONTEXT_CLASS;
import $BASE_PACKAGE.$CONTEXT.domain.model.${CONTEXT_CLASS}Id;

import java.util.Optional;

public interface ${CONTEXT_CLASS}Repository {
    void save($CONTEXT_CLASS entity);
    Optional<$CONTEXT_CLASS> findById(${CONTEXT_CLASS}Id id);
}
EOF

# Domain exception
cat > "$CONTEXT_DIR/$CONTEXT-domain/src/main/java/$DOMAIN_PKG/exceptions/${CONTEXT_CLASS}NotFound.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.domain.exceptions;

import $BASE_PACKAGE.shared.domain.DomainError;

public final class ${CONTEXT_CLASS}NotFound extends DomainError {

    public ${CONTEXT_CLASS}NotFound(String id) {
        super("${CONTEXT}_not_found", "$CONTEXT_CLASS with id " + id + " not found");
    }
}
EOF

# =============================================
# APPLICATION (use cases, implementa ports/in)
# =============================================

APP_PKG="$PACKAGE_PATH/$CONTEXT/application"

mkdir -p "$CONTEXT_DIR/$CONTEXT-application/src/main/java/$APP_PKG/create"
mkdir -p "$CONTEXT_DIR/$CONTEXT-application/src/main/java/$APP_PKG/find"
mkdir -p "$CONTEXT_DIR/$CONTEXT-application/src/test/java/$APP_PKG/create"
mkdir -p "$CONTEXT_DIR/$CONTEXT-application/src/test/java/$APP_PKG/find"

cat > "$CONTEXT_DIR/$CONTEXT-application/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>$BASE_PACKAGE</groupId>
        <artifactId>$CONTEXT_ARTIFACT</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>$CONTEXT-application</artifactId>

    <dependencies>
        <dependency>
            <groupId>$BASE_PACKAGE</groupId>
            <artifactId>$CONTEXT-domain</artifactId>
            <version>\${project.version}</version>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

</project>
EOF

# Create use case - command
cat > "$CONTEXT_DIR/$CONTEXT-application/src/main/java/$APP_PKG/create/Create${CONTEXT_CLASS}Command.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.application.create;

public final class Create${CONTEXT_CLASS}Command {

    private final String id;

    public Create${CONTEXT_CLASS}Command(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}
EOF

# Create use case - handler
cat > "$CONTEXT_DIR/$CONTEXT-application/src/main/java/$APP_PKG/create/Create${CONTEXT_CLASS}UseCase.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.application.create;

import $BASE_PACKAGE.$CONTEXT.domain.model.$CONTEXT_CLASS;
import $BASE_PACKAGE.$CONTEXT.domain.model.${CONTEXT_CLASS}Id;
import $BASE_PACKAGE.$CONTEXT.domain.ports.out.${CONTEXT_CLASS}Repository;
import $BASE_PACKAGE.shared.domain.EventBus;
import $BASE_PACKAGE.shared.domain.UseCase;

public final class Create${CONTEXT_CLASS}UseCase implements UseCase<Create${CONTEXT_CLASS}Command, Void> {

    private final ${CONTEXT_CLASS}Repository repository;
    private final EventBus eventBus;

    public Create${CONTEXT_CLASS}UseCase(${CONTEXT_CLASS}Repository repository, EventBus eventBus) {
        this.repository = repository;
        this.eventBus = eventBus;
    }

    @Override
    public Void execute(Create${CONTEXT_CLASS}Command command) {
        $CONTEXT_CLASS entity = new $CONTEXT_CLASS(new ${CONTEXT_CLASS}Id(command.getId()));
        repository.save(entity);
        eventBus.publish(entity.pullDomainEvents());
        return null;
    }
}
EOF

# Find use case - query
cat > "$CONTEXT_DIR/$CONTEXT-application/src/main/java/$APP_PKG/find/Find${CONTEXT_CLASS}Query.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.application.find;

public final class Find${CONTEXT_CLASS}Query {

    private final String id;

    public Find${CONTEXT_CLASS}Query(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}
EOF

# Find use case - response
cat > "$CONTEXT_DIR/$CONTEXT-application/src/main/java/$APP_PKG/find/${CONTEXT_CLASS}Response.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.application.find;

public final class ${CONTEXT_CLASS}Response {

    private final String id;

    public ${CONTEXT_CLASS}Response(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}
EOF

# Find use case - handler
cat > "$CONTEXT_DIR/$CONTEXT-application/src/main/java/$APP_PKG/find/Find${CONTEXT_CLASS}UseCase.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.application.find;

import $BASE_PACKAGE.$CONTEXT.domain.model.$CONTEXT_CLASS;
import $BASE_PACKAGE.$CONTEXT.domain.model.${CONTEXT_CLASS}Id;
import $BASE_PACKAGE.$CONTEXT.domain.ports.out.${CONTEXT_CLASS}Repository;
import $BASE_PACKAGE.$CONTEXT.domain.exceptions.${CONTEXT_CLASS}NotFound;
import $BASE_PACKAGE.shared.domain.UseCase;

public final class Find${CONTEXT_CLASS}UseCase implements UseCase<Find${CONTEXT_CLASS}Query, ${CONTEXT_CLASS}Response> {

    private final ${CONTEXT_CLASS}Repository repository;

    public Find${CONTEXT_CLASS}UseCase(${CONTEXT_CLASS}Repository repository) {
        this.repository = repository;
    }

    @Override
    public ${CONTEXT_CLASS}Response execute(Find${CONTEXT_CLASS}Query query) {
        $CONTEXT_CLASS entity = repository.findById(new ${CONTEXT_CLASS}Id(query.getId()))
                .orElseThrow(() -> new ${CONTEXT_CLASS}NotFound(query.getId()));
        return new ${CONTEXT_CLASS}Response(entity.getId().getValue());
    }
}
EOF

# =============================================
# INFRASTRUCTURE (adapters: persistence, web, config)
# =============================================

INFRA_PKG="$PACKAGE_PATH/$CONTEXT/infrastructure"

mkdir -p "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/persistence"
mkdir -p "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/rest"
mkdir -p "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/config"
mkdir -p "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/resources"
mkdir -p "$CONTEXT_DIR/$CONTEXT-infrastructure/src/test/java/$INFRA_PKG/persistence"
mkdir -p "$CONTEXT_DIR/$CONTEXT-infrastructure/src/test/java/$INFRA_PKG/rest"

cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>$BASE_PACKAGE</groupId>
        <artifactId>$CONTEXT_ARTIFACT</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>$CONTEXT-infrastructure</artifactId>

    <dependencies>
        <dependency>
            <groupId>$BASE_PACKAGE</groupId>
            <artifactId>$CONTEXT-domain</artifactId>
            <version>\${project.version}</version>
        </dependency>
        <dependency>
            <groupId>$BASE_PACKAGE</groupId>
            <artifactId>$CONTEXT-application</artifactId>
            <version>\${project.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

</project>
EOF

# JPA Entity (infrastructure-only, mapea al domain model)
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/persistence/${CONTEXT_CLASS}Entity.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.persistence;

import $BASE_PACKAGE.$CONTEXT.domain.model.$CONTEXT_CLASS;
import $BASE_PACKAGE.$CONTEXT.domain.model.${CONTEXT_CLASS}Id;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "${CONTEXT}s")
public class ${CONTEXT_CLASS}Entity {

    @Id
    private String id;

    protected ${CONTEXT_CLASS}Entity() {}

    public static ${CONTEXT_CLASS}Entity fromDomain($CONTEXT_CLASS domain) {
        ${CONTEXT_CLASS}Entity entity = new ${CONTEXT_CLASS}Entity();
        entity.id = domain.getId().getValue();
        return entity;
    }

    public $CONTEXT_CLASS toDomain() {
        return new $CONTEXT_CLASS(new ${CONTEXT_CLASS}Id(this.id));
    }

    public String getId() {
        return id;
    }
}
EOF

# Spring Data JPA repository (infrastructure internal)
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/persistence/Spring${CONTEXT_CLASS}DataRepository.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

interface Spring${CONTEXT_CLASS}DataRepository extends JpaRepository<${CONTEXT_CLASS}Entity, String> {
}
EOF

# Adapter: implements domain port using Spring Data
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/persistence/Jpa${CONTEXT_CLASS}Repository.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.persistence;

import $BASE_PACKAGE.$CONTEXT.domain.model.$CONTEXT_CLASS;
import $BASE_PACKAGE.$CONTEXT.domain.model.${CONTEXT_CLASS}Id;
import $BASE_PACKAGE.$CONTEXT.domain.ports.out.${CONTEXT_CLASS}Repository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public final class Jpa${CONTEXT_CLASS}Repository implements ${CONTEXT_CLASS}Repository {

    private final Spring${CONTEXT_CLASS}DataRepository jpaRepository;

    public Jpa${CONTEXT_CLASS}Repository(Spring${CONTEXT_CLASS}DataRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public void save($CONTEXT_CLASS entity) {
        jpaRepository.save(${CONTEXT_CLASS}Entity.fromDomain(entity));
    }

    @Override
    public Optional<$CONTEXT_CLASS> findById(${CONTEXT_CLASS}Id id) {
        return jpaRepository.findById(id.getValue())
                .map(${CONTEXT_CLASS}Entity::toDomain);
    }
}
EOF

# InMemory EventBus (adapter for shared-kernel port)
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/config/InMemoryEventBus.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.config;

import $BASE_PACKAGE.shared.domain.DomainEvent;
import $BASE_PACKAGE.shared.domain.EventBus;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.logging.Logger;

@Component
public final class InMemoryEventBus implements EventBus {

    private static final Logger LOG = Logger.getLogger(InMemoryEventBus.class.getName());

    @Override
    public void publish(List<DomainEvent> events) {
        events.forEach(event ->
            LOG.info("Domain event published: " + event.getClass().getSimpleName() + " [" + event.getEventId() + "]")
        );
    }
}
EOF

# Spring @Configuration: wires use cases as beans
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/config/${CONTEXT_CLASS}BeanConfig.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.config;

import $BASE_PACKAGE.$CONTEXT.application.create.Create${CONTEXT_CLASS}UseCase;
import $BASE_PACKAGE.$CONTEXT.application.find.Find${CONTEXT_CLASS}UseCase;
import $BASE_PACKAGE.$CONTEXT.domain.ports.out.${CONTEXT_CLASS}Repository;
import $BASE_PACKAGE.shared.domain.EventBus;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ${CONTEXT_CLASS}BeanConfig {

    @Bean
    public Create${CONTEXT_CLASS}UseCase create${CONTEXT_CLASS}UseCase(
            ${CONTEXT_CLASS}Repository repository, EventBus eventBus) {
        return new Create${CONTEXT_CLASS}UseCase(repository, eventBus);
    }

    @Bean
    public Find${CONTEXT_CLASS}UseCase find${CONTEXT_CLASS}UseCase(${CONTEXT_CLASS}Repository repository) {
        return new Find${CONTEXT_CLASS}UseCase(repository);
    }
}
EOF

# REST Controller (driving adapter)
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/rest/${CONTEXT_CLASS}Controller.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.rest;

import $BASE_PACKAGE.$CONTEXT.application.create.Create${CONTEXT_CLASS}Command;
import $BASE_PACKAGE.$CONTEXT.application.create.Create${CONTEXT_CLASS}UseCase;
import $BASE_PACKAGE.$CONTEXT.application.find.Find${CONTEXT_CLASS}Query;
import $BASE_PACKAGE.$CONTEXT.application.find.Find${CONTEXT_CLASS}UseCase;
import $BASE_PACKAGE.$CONTEXT.application.find.${CONTEXT_CLASS}Response;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/${CONTEXT}s")
public final class ${CONTEXT_CLASS}Controller {

    private final Create${CONTEXT_CLASS}UseCase createUseCase;
    private final Find${CONTEXT_CLASS}UseCase findUseCase;

    public ${CONTEXT_CLASS}Controller(
            Create${CONTEXT_CLASS}UseCase createUseCase,
            Find${CONTEXT_CLASS}UseCase findUseCase) {
        this.createUseCase = createUseCase;
        this.findUseCase = findUseCase;
    }

    @PostMapping
    public ResponseEntity<Void> create(@RequestBody Create${CONTEXT_CLASS}Request request) {
        createUseCase.execute(new Create${CONTEXT_CLASS}Command(request.getId()));
        return ResponseEntity.status(HttpStatus.CREATED).build();
    }

    @GetMapping("/{id}")
    public ResponseEntity<${CONTEXT_CLASS}Response> findById(@PathVariable String id) {
        ${CONTEXT_CLASS}Response response = findUseCase.execute(new Find${CONTEXT_CLASS}Query(id));
        return ResponseEntity.ok(response);
    }
}
EOF

# REST request DTO
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/rest/Create${CONTEXT_CLASS}Request.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.rest;

public final class Create${CONTEXT_CLASS}Request {

    private String id;

    public Create${CONTEXT_CLASS}Request() {}

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }
}
EOF

# Global exception handler
cat > "$CONTEXT_DIR/$CONTEXT-infrastructure/src/main/java/$INFRA_PKG/rest/GlobalExceptionHandler.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.infrastructure.rest;

import $BASE_PACKAGE.shared.domain.DomainError;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(DomainError.class)
    public ResponseEntity<Map<String, String>> handleDomainError(DomainError error) {
        Map<String, String> body = new HashMap<>();
        body.put("error_code", error.getErrorCode());
        body.put("message", error.getMessage());
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(body);
    }
}
EOF

# =============================================
# BOOT (composition root - solo arranca)
# =============================================

BOOT_PKG="$PACKAGE_PATH/$CONTEXT/boot"

mkdir -p "$CONTEXT_DIR/$CONTEXT-boot/src/main/java/$BOOT_PKG"
mkdir -p "$CONTEXT_DIR/$CONTEXT-boot/src/main/resources"
mkdir -p "$CONTEXT_DIR/$CONTEXT-boot/src/test/java/$BOOT_PKG"

cat > "$CONTEXT_DIR/$CONTEXT-boot/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>$BASE_PACKAGE</groupId>
        <artifactId>$CONTEXT_ARTIFACT</artifactId>
        <version>1.0.0-SNAPSHOT</version>
    </parent>

    <artifactId>$CONTEXT-boot</artifactId>

    <dependencies>
        <dependency>
            <groupId>$BASE_PACKAGE</groupId>
            <artifactId>$CONTEXT-infrastructure</artifactId>
            <version>\${project.version}</version>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>com.tngtech.archunit</groupId>
            <artifactId>archunit-junit4</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <mainClass>$BASE_PACKAGE.$CONTEXT.boot.${CONTEXT_CLASS}Application</mainClass>
                </configuration>
                <executions>
                    <execution>
                        <goals>
                            <goal>repackage</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>

</project>
EOF

# Application class (EntityScan apunta SOLO a infrastructure.persistence)
cat > "$CONTEXT_DIR/$CONTEXT-boot/src/main/java/$BOOT_PKG/${CONTEXT_CLASS}Application.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.boot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication(scanBasePackages = "$BASE_PACKAGE.$CONTEXT.infrastructure")
@EntityScan(basePackages = "$BASE_PACKAGE.$CONTEXT.infrastructure.persistence")
@EnableJpaRepositories(basePackages = "$BASE_PACKAGE.$CONTEXT.infrastructure.persistence")
public class ${CONTEXT_CLASS}Application {

    public static void main(String[] args) {
        SpringApplication.run(${CONTEXT_CLASS}Application.class, args);
    }
}
EOF

cat > "$CONTEXT_DIR/$CONTEXT-boot/src/main/resources/application.properties" <<EOF
spring.application.name=$CONTEXT-service
server.port=0
spring.datasource.url=jdbc:h2:mem:${CONTEXT}db;DB_CLOSE_DELAY=-1
spring.datasource.driver-class-name=org.h2.Driver
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=false
EOF

# =============================================
# ARCHUNIT TESTS (enforcement de arquitectura)
# =============================================

cat > "$CONTEXT_DIR/$CONTEXT-boot/src/test/java/$BOOT_PKG/ArchitectureTest.java" <<EOF
package $BASE_PACKAGE.$CONTEXT.boot;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;

public class ArchitectureTest {

    private final JavaClasses classes = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("$BASE_PACKAGE.$CONTEXT");

    @Test
    public void domain_should_not_depend_on_infrastructure() {
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
            .check(classes);
    }

    @Test
    public void domain_should_not_depend_on_application() {
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("..application..")
            .check(classes);
    }

    @Test
    public void domain_should_not_use_spring() {
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("org.springframework..")
            .check(classes);
    }

    @Test
    public void domain_should_not_use_javax_persistence() {
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("javax.persistence..")
            .check(classes);
    }

    @Test
    public void application_should_not_depend_on_infrastructure() {
        noClasses()
            .that().resideInAPackage("..application..")
            .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
            .check(classes);
    }

    @Test
    public void application_should_not_use_spring() {
        noClasses()
            .that().resideInAPackage("..application..")
            .should().dependOnClassesThat().resideInAPackage("org.springframework..")
            .check(classes);
    }
}
EOF

done

echo ""
echo "Estructura creada correctamente"
echo ""
echo "Estructura generada:"
echo "  $PROJECT_NAME/"
echo "  +-- shared-kernel/          (AggregateRoot, ValueObject, DomainEvent, ports base)"
echo "  +-- <context>-context/"
echo "      +-- <context>-domain/          (modelo puro, ports/in, ports/out, exceptions)"
echo "      +-- <context>-application/     (use cases con Command/Query/Response)"
echo "      +-- <context>-infrastructure/  (JPA entities, adapters, REST, config)"
echo "      +-- <context>-boot/            (composition root + ArchUnit tests)"
echo ""
echo "Para compilar: cd $PROJECT_NAME && mvn clean install"
