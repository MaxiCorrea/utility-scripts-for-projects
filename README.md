# Scripts

Coleccion de scripts utilitarios para automatizar tareas de desarrollo.

## hexagonal-spring-scaffold.sh

Genera un proyecto Maven multi-modulo con **Arquitectura Hexagonal (Ports & Adapters)** sobre Spring Boot 2.7.

### Uso

```bash
./hexagonal-spring-scaffold.sh <project-name> <base-package> <context1> [context2] ...
```

```bash
# Ejemplo: proyecto con dos bounded contexts
./hexagonal-spring-scaffold.sh ecommerce com.empresa order inventory
```

### Estructura generada

```
ecommerce/
├── pom.xml                          # Root POM (aggregator)
├── shared-kernel/                   # Abstracciones base del dominio
│   └── src/main/java/.../shared/domain/
│       ├── AggregateRoot.java       # Base con domain events
│       ├── ValueObject.java         # Fuerza equals/hashCode
│       ├── DomainEvent.java         # Evento inmutable
│       ├── DomainError.java         # Excepcion base con error code
│       ├── UseCase.java             # Port generico UseCase<C, R>
│       ├── EventBus.java            # Port de salida para eventos
│       └── UnitOfWork.java          # Port de salida transaccional
├── order-context/
│   ├── order-domain/                # Modelo puro, sin frameworks
│   │   └── model/                   # Aggregates, Value Objects
│   │   └── ports/in/                # Driving ports
│   │   └── ports/out/               # Driven ports (Repository, etc)
│   │   └── exceptions/              # Errores de dominio tipados
│   ├── order-application/           # Use cases (Command/Query/Response)
│   │   └── create/                  # CreateOrderUseCase
│   │   └── find/                    # FindOrderUseCase
│   ├── order-infrastructure/        # Adapters (Spring, JPA, REST)
│   │   └── persistence/             # JPA Entity separada del domain model
│   │   └── rest/                    # Controllers + DTOs
│   │   └── config/                  # @Configuration, EventBus impl
│   └── order-boot/                  # Composition root
│       └── ArchitectureTest.java    # ArchUnit enforcement
└── inventory-context/
    └── (misma estructura)
```

### Principios que aplica

- **Domain puro**: cero dependencias de Spring, JPA o cualquier framework
- **Ports & Adapters**: el dominio define interfaces, infrastructure las implementa
- **JPA Entity separada**: `OrderEntity` (infra) mapea desde/hacia `Order` (domain) con `fromDomain()`/`toDomain()`
- **Use cases explicitos**: cada operacion es un `UseCase<Command, Response>` en la capa application
- **ArchUnit enforcement**: 6 tests que fallan el build si alguien acopla domain a frameworks

### ArchUnit tests incluidos

| Regla | Que previene |
|---|---|
| domain no depende de infrastructure | Import directo de adapters |
| domain no depende de application | Dependencia circular |
| domain no usa Spring | `@Autowired`, `@Component`, etc en domain |
| domain no usa javax.persistence | `@Entity`, `@Id`, etc en domain |
| application no depende de infrastructure | Use case acoplado a adapter |
| application no usa Spring | `@Service`, `@Transactional`, etc en use cases |

### Requisitos

- Bash 4+
- Maven 3.6+
- Java 8+

## restart-liquidaciones-script.sh

Script para reiniciar servicios de liquidaciones.
