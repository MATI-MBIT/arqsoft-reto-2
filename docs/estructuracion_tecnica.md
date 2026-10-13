# Estructuración Técnica - Experimentos E01 y E02

Documento de referencia técnica para la implementación de los experimentos de seguridad (E01) y disponibilidad (E02) del Reto 2 de ARTI4109.

---

## 1. STACK TECNOLÓGICO

### Componentes principales

```
Lenguaje y Framework
├── Java 21 (JDK 21+)
├── Spring Boot 3
└── Spring Web, Spring AMQP, Spring JDBC

Infraestructura
├── PostgreSQL 17 (base de datos)
├── RabbitMQ 4.1 (bróker de mensajes)
├── Docker & Docker Compose (orquestación)
└── Colima (para macOS)

Observabilidad
├── Micrometer (métricas)
├── Prometheus (recolección)
└── Grafana (visualización)

Pruebas de carga
├── k6 (generador de carga)
└── Arribo aleatorio (1 pedido/seg, 10 consultas/seg)
```

### Herramientas de build

- **Gradle 8.x**: Multi-proyecto, task graph
- **Docker Buildx**: Imágenes multi-stage
- **Make**: Orquestación de comandos

---

## 2. ESTRUCTURA DE PAQUETES Y PROYECTOS

### Árbol de servicios

```
services/
├── comun/                          # Librería compartida (no es Boot app)
│   ├── src/main/java/co/mati/reto2/comun/
│   │   ├── Registro.java           # Anotador de eventos para veredicto
│   │   ├── Bus.java                # Abstracción RabbitMQ (constantes de colas)
│   │   └── Http.java               # Factory de RestClient reutilizable
│   └── build.gradle.kts
│
├── sesiones/                       # E01: Gestor de sesión (detección)
│   └── SesionController.java       # POST /sesiones
│
├── usuario-no-valido/              # E01: Verificador de dispositivo
│   └── VerificadorDeDispositivo.java  # Consumer RabbitMQ
│
├── monitor/                        # E02: Sondeo de etapas (detección)
│   └── MonitorDeLaCadena.java      # @Scheduled, sondea /salud
│
├── ventas/                         # E02: Coordinador (reacción)
│   ├── EnvioALaDeadLetterQueue.java # POST /fallas/etapa
│   ├── Despachador.java            # Gestor de pedidos
│   └── PedidoController.java       # POST /pedidos
│
├── etapa/                          # 3 instancias: facturación, inventario, despacho
│   ├── TrabajoController.java      # POST /trabajo (procesa pedido)
│   └── ReciboDeEtapa.java          # GET /salud (punto de salud)
│
├── logistica/
├── notificador/
├── receptor-sms/
├── onboarding/
├── auditor-cola/
└── ... (11 micros totales)

load/                               # Scripts de pruebas
├── experimento.sh                  # Orquestador maestro (bash)
├── experimento.ps1                 # Versión PowerShell
├── e2e.sh                          # Prueba de punta a punta
├── smoke.sh                        # Humo (~7 min)
├── plan.tsv                        # Matriz de corridas (T, N, variantes)
└── evidencias-captura.sh           # Captura de pantallas Grafana

deploy/                             # Configuración e infraestructura
├── docker-compose.yml              # 12 micros + PostgreSQL + RabbitMQ + Prometheus + Grafana
├── Dockerfile                      # Multi-stage: compilación → runtime
├── postgres/
│   ├── 01-esquema.sql              # DDL: tablas, vistas
│   ├── 02-semilla.sql              # Datos iniciales
│   └── 03-vistas.sql               # Cruces para veredicto
├── observabilidad/
│   ├── prometheus.yml              # Scrape targets
│   └── grafana/dashboards/
│       ├── e01.json                # Dashboard E01
│       ├── e02.json                # Dashboard E02
│       ├── evidencias-e01.json     # E01 con trazas
│       └── evidencias-e02.json     # E02 con trazas
└── inyector/
    └── inyectar.sh                 # Inyecta fallos (stop -STOP, congelamiento)

analisis/                           # Post-processing de resultados
├── e01.sql                         # Veredicto E01 (cruces entrada-salida)
├── e02.sql                         # Veredicto E02 (idempotencia, tiempos)
└── resultados/
    ├── e01-s1-20261012-*/
    │   ├── k6-cadena.txt           # Salida de k6
    │   ├── tablero.txt             # Capturas Grafana
    │   ├── plan.tsv                # Parámetros usados
    │   └── veredicto.txt           # PASS/FAIL por criterio
    └── ...
```

### Configuración de build

**`build.gradle.kts`** (raíz):
```kotlin
// Java 21 obligatorio
extensions.configure<JavaPluginExtension> {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

// Cada micro Spring Boot genera app.jar (nombre fijo)
tasks.named<BootJar>("bootJar") {
    archiveFileName.set("app.jar")
}
```

**`services/comun/build.gradle.kts`**: Sin Spring Boot, solo librería.

---

## 3. PATRONES DE DISEÑO IMPLEMENTADOS

### 3.1 E01 - Detección (Seguridad: ASR-1)

#### Componentes

- **Sesiones** (8081): Abre sesión y publica evento
- **Usuario-No-Válido** (8082): Verificador que compara huella
- **Notificador** (8097): Emite alerta a seguridad

#### Flujo técnico

```
1. Cliente solicita: POST /sesiones
   {
     "sesionId": "s-uuid",
     "vendedorId": "v-123",
     "password": "...",
     "dispositivoId": "d-456"
   }

2. SesionController.abrir() [Sesiones]
   ├─ jdbc.queryForList(SELECT password_hash ...)
   ├─ Valida: Hash.sha256(password) == BD_hash
   ├─ SI VÁLIDA:
   │  ├─ INSERT INTO operacion.sesion(id, vendedor_id, dispositivo_id, abierta_en)
   │  ├─ registro.anotar(NOW(), "sesion.abierta", sesionId, ...) ← t0 E01
   │  ├─ bus.convertAndSend("seguridad", "sesion-abierta", SesionAbierta{...})
   │  └─ 201 Created + sesionId
   └─ SI NO: 401 Unauthorized

3. VerificadorDeDispositivo [Usuario-No-Válido]
   Consumer RabbitMQ en cola "verificador.sesiones"
   ├─ Recibe: SesionAbierta{sesionId, vendedorId, dispositivoId, abiertaEn}
   ├─ Consulta: SELECT * FROM operacion.dispositivo
   │            WHERE id = :dispositivoId AND registrado = true
   ├─ SI NO EXISTE:
   │  ├─ registro.anotar(NOW(), "aviso.emitido", sesionId, ...) ← t1 E01
   │  ├─ bus.convertAndSend("notificador", "alertas", Alerta{...})
   │  └─ log.warn("dispositivo no registrado: {}", dispositivoId)
   └─ SI EXISTE: noop (dispositivo registrado)

4. Notificador [8097]
   Consumer RabbitMQ en cola "notificador.alertas"
   ├─ Recibe: Alerta{vendedorId, dispositivoId, ...}
   ├─ Envía: email/SMS (simulado)
   └─ registro.anotar(NOW(), "alerta.notificada", ...)
```

#### Código clave: `SesionController.java`

```java
@PostMapping("/sesiones")
ResponseEntity<Map<String, String>> abrir(@RequestBody Apertura a) {
    // Validar credencial
    List<String> hash = jdbc.queryForList(
            "SELECT password_hash FROM operacion.vendedor WHERE id = ?", 
            String.class, a.vendedorId());
    
    if (hash.isEmpty() || !hash.getFirst().equals(Hash.sha256(a.password()))) {
        rechazos.increment();
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
    
    // Guardar sesión en BD
    Instant abierta = Instant.now();
    jdbc.update("INSERT INTO operacion.sesion (id, vendedor_id, dispositivo_id, abierta_en) " +
                "VALUES (?, ?, ?, ?)",
            a.sesionId(), a.vendedorId(), a.dispositivoId(), Timestamp.from(abierta));
    
    // t0: Anotar evento
    registro.anotar(Instant.now(), "sesion.abierta", a.sesionId(), null, null,
            Map.of("vendedorId", a.vendedorId(), "dispositivoId", a.dispositivoId()));
    
    // Publicar evento para Verificador
    aperturas.increment();
    bus.convertAndSend(Bus.SEGURIDAD, Bus.SESION_ABIERTA,
            new SesionAbierta(a.sesionId(), a.vendedorId(), a.dispositivoId(), abierta.toString()));
    
    return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("sesionId", a.sesionId()));
}
```

#### Métricas clave

- `sesiones.aperturas`: Counter de sesiones abiertas
- `sesiones.credencial.rechazada`: Counter de fallos de autenticación
- Prometheus scrape: `http://localhost:8081/actuator/prometheus`

#### Criterios de aceptación (E01)

- **S1**: 50 sesiones no registradas → 50 avisos en ≤2s cada uno
- **S2**: 100 cambios legítimos → ≤1 falso aviso
- **S3**: 20 aperturas <1s post-registro → 0 avisos

---

### 3.2 E02 - Detección y Reacción (Disponibilidad: ASR-3 + ASR-4)

#### Componentes

- **Monitor** (8095): Sondea salud de etapas
- **Ventas** (8090): Coordinador, reacciona a fallos
- **Etapas** (8091-8093): Facturación, inventario, despacho

#### Fase 1: DETECCIÓN

##### `MonitorDeLaCadena.java` - Sondeo periódico

```java
@Component
class MonitorDeLaCadena {
    private final long tMs;           // SONDEO_T_MS: período en ms
    private final int n;              // SONDEO_N: fallos consecutivos
    private final long umbralMs;      // UMBRAL_ATASCO_MS: tiempo máximo sin terminar
    
    @PostConstruct
    void arrancar() {
        // Programar sondeo cada T milisegundos
        ciclo.scheduleAtFixedRate(this::sondear, tMs, tMs, TimeUnit.MILLISECONDS);
    }
    
    private void sondear() {
        // Lanzar sondeo en paralelo para 3 etapas (virtual threads)
        Map<String, Future<Sondeo>> respuestas = new LinkedHashMap<>();
        etapas.forEach((etapa, cliente) -> 
            respuestas.put(etapa, trabajo.submit(() -> sondeo(cliente)))
        );
        
        // Esperar respuestas (con timeout < T)
        respuestas.forEach((etapa, futuro) -> {
            Sondeo sondeo;
            try {
                sondeo = futuro.get();  // timeout integrado en cliente HTTP
            } catch (Exception ex) {
                sondeo = Sondeo.sinRespuesta(ex.getClass().getSimpleName());
            }
            
            // Registrar conteo de fallos
            aplicar(etapa, sondeo.causa());
            
            // Si etapa respondió, procesar pedidos atascados
            if (sondeo.causa() == null) {
                atascados(etapa, sondeo.atascados());
            }
        });
    }
    
    private Sondeo sondeo(RestClient cliente) {
        try {
            // GET /salud?mayorQueMs=U
            Map<?, ?> salud = cliente.get()
                .uri("/salud?mayorQueMs={u}", umbralMs)
                .retrieve()
                .body(Map.class);
            
            // Extraer lista de pedidos atascados
            List<String> atascados = new ArrayList<>();
            if (salud != null && salud.get("atascados") instanceof List<?> lista) {
                for (Object p : lista) {
                    if (p instanceof Map<?, ?> pedido) {
                        atascados.add(pedido.get("pedidoId").toString());
                    }
                }
            }
            return new Sondeo(null, atascados);  // null = sin error
        } catch (Exception ex) {
            return Sondeo.sinRespuesta(ex.getClass().getSimpleName());
        }
    }
    
    private void aplicar(String etapa, String causa) {
        CuentaDeSondeos cuenta = cuentas.get(etapa);
        if (causa != null) {
            cuenta.registrarFallo();
        } else {
            cuenta.resetear();
        }
        
        // Si suma N fallos → notificar al Coordinador
        if (cuenta.detenida()) {
            notificarCoordinador(etapa);
        }
    }
    
    private void notificarCoordinador(String etapa) {
        ventas.post()
            .uri("/fallas/etapa")
            .body(new FallaDeEtapa(etapa))
            .retrieve()
            .toBodilessEntity();
    }
}

record Sondeo(String causa, List<String> atascados) {
    static Sondeo sinRespuesta(String causa) {
        return new Sondeo(causa, List.of());
    }
}
```

##### Punto de salud: `ReciboDeEtapa.java`

```java
@GetMapping("/salud")
Map<String, Object> salud(@RequestParam(defaultValue = "0") long mayorQueMs) {
    List<Map<String, String>> atascados = new ArrayList<>();
    
    if (mayorQueMs > 0) {
        // Encontrar pedidos que llevan más de U sin terminar
        List<String> pedidosLargos = jdbc.queryForList("""
            SELECT pedido_id FROM operacion.pedido_etapa
            WHERE etapa = ? AND estado = 'EN_CURSO'
            AND EXTRACT(EPOCH FROM (NOW() - enviado_en)) * 1000 > ?
            """, String.class, etapa, mayorQueMs);
        
        for (String id : pedidosLargos) {
            atascados.add(Map.of("pedidoId", id));
        }
    }
    
    return Map.of(
        "estado", "UP",
        "etapa", etapa,
        "atascados", atascados
    );
}
```

##### Parámetros variacionales (sin código)

Vienen de variables de entorno, inyectadas en tiempo de startup:

| Parámetro | Variable entorno | Significado | Default |
|-----------|------------------|-------------|---------|
| T | `SONDEO_T_MS` | Período de sondeo (ms) | 2000 |
| N | `SONDEO_N` | Fallos consecutivos para declarar detenida | 3 |
| Espera | `SONDEO_ESPERA_MS` | Timeout HTTP por sondeo | 500 |
| U | `UMBRAL_ATASCO_MS` | Tiempo máximo sin terminar (ms) | 15000 |

**En `experimento.sh`**:
```bash
SONDEO_T_MS="$T" SONDEO_N="$N" SONDEO_ESPERA_MS="$ESPERA_MS" \
UMBRAL_ATASCO_MS="$UMBRAL_ATASCO_MS" \
docker compose up -d --force-recreate monitor
```

---

#### Fase 2: REACCIÓN

##### `EnvioALaDeadLetterQueue.java` - Coordinador

```java
@RestController
class EnvioALaDeadLetterQueue {
    
    static final String ETAPA_CAIDA = "ETAPA_CAIDA";
    static final String PEDIDO_ATASCADO = "PEDIDO_ATASCADO";
    
    @PostMapping("/fallas/etapa")
    ResponseEntity<Void> etapaCaida(@RequestBody FallaDeEtapa f) {
        // Async, sin bloquear respuesta
        AtomicBoolean ocupado = enviando.computeIfAbsent(f.etapa(), e -> new AtomicBoolean());
        
        if (ocupado.compareAndSet(false, true)) {
            trabajo.submit(() -> {
                try {
                    enviarPendientes(f.etapa());
                } finally {
                    ocupado.set(false);
                }
            });
        }
        
        return ResponseEntity.accepted().build();
    }
    
    private void enviarPendientes(String etapa) {
        // Listar todos los pedidos en curso en esa etapa
        List<Map<String, Object>> pendientes = jdbc.queryForList("""
            SELECT pedido_id, enviado_en FROM operacion.pedido_etapa
            WHERE etapa = ? AND estado = 'EN_CURSO' ORDER BY enviado_en
            """, etapa);
        
        for (Map<String, Object> p : pendientes) {
            enviar(
                (String) p.get("pedido_id"),
                ((Timestamp) p.get("enviado_en")).toInstant(),
                etapa,
                ETAPA_CAIDA
            );
        }
    }
    
    private void enviar(String pedidoId, Instant enviadoEn, String etapa, String causa) {
        Instant detectado = Instant.now();
        
        // IDEMPOTENCIA (ADR-005): clave única (pedido, etapa, intento)
        // ON CONFLICT DO NOTHING evita reintentos duplicados
        int nueva = jdbc.update("""
            INSERT INTO operacion.senal (pedido_id, etapa, intento, detectada_en) 
            VALUES (?, ?, ?, ?)
            ON CONFLICT DO NOTHING
            """, pedidoId, etapa, INTENTO, Timestamp.from(detectado));
        
        if (nueva == 0) {
            // Ya fue procesado, no reintentar
            return;
        }
        
        String clave = pedidoId + ":" + etapa + ":" + INTENTO;
        
        try {
            // Enviar con confirmación (NR-004a de ADR-004)
            CorrelationData correlacion = new CorrelationData(clave);
            bus.convertAndSend(
                Bus.CADENA, 
                Bus.PEDIDO_DETENIDO,
                new PedidoDetenido(
                    pedidoId, etapa, causa, INTENTO, 
                    enviadoEn.toString(), detectado.toString(),
                    Duration.between(enviadoEn, detectado).toMillis()
                ),
                m -> {
                    m.getMessageProperties().setMessageId(clave);
                    m.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                    return m;
                },
                correlacion
            );
            
            // ESPERAR ACK DEL BRÓKER (5s timeout)
            CorrelationData.Confirm confirmacion = 
                correlacion.getFuture().get(ESPERA_CONFIRMACION_MS, TimeUnit.MILLISECONDS);
            
            if (!confirmacion.isAck()) {
                throw new IllegalStateException(
                    "el bróker rechazó el mensaje: " + confirmacion.getReason()
                );
            }
        } catch (Exception ex) {
            // Sin confirmación: rollback, reintentar en próximo ciclo
            log.warn("sin confirmación para {}, se reintenta en el próximo aviso: {}", 
                     clave, ex.getMessage());
            jdbc.update("DELETE FROM operacion.senal WHERE pedido_id = ? AND etapa = ? AND intento = ?",
                    pedidoId, etapa, INTENTO);
            return;
        }
        
        // CONFIRMADA: actualizar timestamp y anotar evento
        Instant confirmada = Instant.now();
        jdbc.update(
            "UPDATE operacion.senal SET confirmada_en = ? WHERE pedido_id = ? AND etapa = ? AND intento = ?",
            Timestamp.from(confirmada), pedidoId, etapa, INTENTO
        );
        
        // t1 de E02: evento de éxito
        registro.anotar(
            confirmada, 
            "pedido.encolado", 
            null, 
            pedidoId, 
            etapa,
            Map.of(
                "intento", INTENTO, 
                "causa", causa,
                "transcurridoMs", Duration.between(enviadoEn, confirmada).toMillis()
            )
        );
        
        log.info("pedido {} → Dead-Letter-Queue · falta {} · causa {} · detenido {} ms",
                pedidoId, etapa, causa, 
                Duration.between(enviadoEn, confirmada).toMillis());
        
        metricas.counter("ventas.pedidos.encolados", "etapa", etapa).increment();
    }
}

record FallaDeEtapa(String etapa) {}
record PedidoDetenido(String pedidoId, String etapa, String causa, int intento, 
                      String enviadoEn, String detectadoEn, long transcurridoMs) {}
```

##### Ruta del evento (cadena de componentes)

```
Monitor (8095)
  ├─ scheduleAtFixedRate() cada T ms
  ├─ GET /salud?mayorQueMs=U (etapa)
  ├─ SI timeout || N fallos: aplicar(etapa, "TimeoutException")
  └─ POST http://ventas:8080/fallas/etapa {etapa}
     
Ventas (8090) - EnvioALaDeadLetterQueue
  ├─ SELECT pedido_etapa WHERE etapa='X' AND estado='EN_CURSO'
  ├─ FOR EACH pedido:
  │  ├─ INSERT senal(pedido, etapa, 1) ON CONFLICT DO NOTHING
  │  ├─ RabbitMQ.convertAndSend("cadena", "pedido.detenido", {...})
  │  ├─ CorrelationData: esperar ACK (5s)
  │  ├─ SI ACK: UPDATE senal.confirmada_en, anotar "pedido.encolado" (t1)
  │  └─ SI NO ACK: DELETE senal, log.warn, reintenta en próximo ciclo
  └─ Métrica: ventas.pedidos.encolados[etapa]++

RabbitMQ (bróker)
  ├─ Recibe: cadena.pedido-detenido
  ├─ Routea a: dead-letter-queue (T11, durable)
  └─ ACK: CorrelationData.Confirm.isAck() = true

Dead-Letter-Queue (T11)
  └─ Nadie consume (ASR-4 está fuera de alcance E02)
```

---

## 4. REGISTRO DE EVENTOS Y VEREDICTO

### Tabla central: `operacion.evento`

```sql
CREATE TABLE operacion.evento (
    id BIGSERIAL PRIMARY KEY,
    cuando TIMESTAMP NOT NULL DEFAULT NOW(),
    evento VARCHAR(50) NOT NULL,      -- ej: "sesion.abierta", "pedido.encolado"
    sesion_id VARCHAR(50),             -- para E01
    pedido_id VARCHAR(50),             -- para E02
    etapa VARCHAR(20),                 -- facturacion, inventario, despacho
    datos JSONB                        -- parámetros extra
);

CREATE INDEX ON operacion.evento(evento);
CREATE INDEX ON operacion.evento(sesion_id);
CREATE INDEX ON operacion.evento(pedido_id);
```

### Anotación desde código

Cada componente llama:

```java
registro.anotar(
    Instant.now(),              // timestamp
    "evento.nombre",            // evento único
    sesionId,                   // null si no aplica
    pedidoId,                   // null si no aplica
    etapa,                      // null si no aplica
    Map.of(                     // datos contextuales
        "key1", value1,
        "key2", value2
    )
);
```

### Veredicto E01: `analisis/e01.sql`

```sql
-- Cruce entrada → salida
SELECT 
    s.sesion_id,
    s.cuando AS t0_apertura,
    s.datos->>'vendedorId' AS vendedor,
    s.datos->>'dispositivoId' AS dispositivo,
    v.cuando AS t1_aviso,
    EXTRACT(EPOCH FROM (v.cuando - s.cuando)) * 1000 AS demora_ms,
    CASE 
        WHEN v.id IS NULL THEN 'SIN_AVISO'
        WHEN EXTRACT(EPOCH FROM (v.cuando - s.cuando)) * 1000 > 2000 THEN 'FUERA_PLAZO'
        ELSE 'OK'
    END AS estado
FROM operacion.evento s
LEFT JOIN operacion.evento v 
    ON s.sesion_id = v.sesion_id 
    AND v.evento = 'aviso.emitido'
WHERE s.evento = 'sesion.abierta'
  AND s.datos->>'dispositivoId' NOT IN (SELECT id FROM operacion.dispositivo WHERE registrado)
ORDER BY s.cuando;
```

**Criterios**:
- S1: 50 sesiones no registradas → 50 avisos cada uno ≤2s ✓
- S2: 100 cambios legítimos → ≤1 falso aviso ✓
- S3: 20 aperturas <1s post-registro → 0 avisos ✓

### Veredicto E02: `analisis/e02.sql`

```sql
-- Idempotencia: un pedido NO debe aparecer >1 en dead-letter-queue
SELECT 
    pedido_id,
    COUNT(*) AS veces_encolado,
    CASE 
        WHEN COUNT(*) > 1 THEN 'DUPLICADO'
        WHEN COUNT(*) = 1 THEN 'OK'
        ELSE 'PERDIDO'
    END AS estado
FROM operacion.evento
WHERE evento = 'pedido.encolado'
GROUP BY pedido_id
HAVING COUNT(*) > 1
ORDER BY veces_encolado DESC;

-- Tiempos: demora desde enviado_en hasta pedido.encolado
SELECT 
    pedido_id,
    etapa,
    MAX(CAST(datos->>'transcurridoMs' AS BIGINT)) AS demora_ms,
    CASE 
        WHEN MAX(CAST(datos->>'transcurridoMs' AS BIGINT)) <= 6400 THEN 'OK'
        ELSE 'FUERA_PLAZO'
    END AS estado
FROM operacion.evento
WHERE evento = 'pedido.encolado'
GROUP BY pedido_id, etapa
ORDER BY demora_ms DESC;
```

**Criterios**:
- D1 (sin fallos): baseline de rendimiento
- D2 (caídas de etapa): todos los pedidos en Dead-Letter-Queue ≤6.4s
- D3 (congelamiento): detectar y enviar pedidos atascados
- D5 (entregas repetidas): cero duplicados en Dead-Letter-Queue

---

## 5. LANZAMIENTO DE PRUEBAS

### Orquestador maestro: `load/experimento.sh`

```bash
#!/usr/bin/env bash

# Parámetros globales
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE=(docker compose -f "$ROOT/deploy/docker-compose.yml")
PLAN="$ROOT/load/plan.tsv"                    # Matriz de variantes (T, N, etc.)
RESULTADOS="$ROOT/analisis/resultados"
STAMP="$(date +%Y%m%d-%H%M%S)"

# k6 → Prometheus
export K6_PROMETHEUS_RW_SERVER_URL="http://localhost:9090/api/v1/write"
export K6_PROMETHEUS_RW_PUSH_INTERVAL="5s"

# Validación: batería
if pmset -g batt | grep -q "Battery Power"; then
  echo "El equipo está con batería. Conéctalo a la corriente."
  exit 1
fi

# Ciclo por cada línea de plan.tsv
for linea in $(tail -n +2 "$PLAN"); do
  EXPERIMENTO=$(echo "$linea" | cut -f1)
  T=$(echo "$linea" | cut -f2)
  N=$(echo "$linea" | cut -f3)
  
  log "Corrida: $EXPERIMENTO, T=$T, N=$N"
  
  # 1. PREPARAR
  preparar "$EXPERIMENTO" "$T" "$N"
  
  # 2. CALENTAR (5 min, descartados)
  k6 run $K6_OUT --duration 5m load/carga.js
  
  # 3. MEDIR (según fase)
  case "$EXPERIMENTO" in
    E01)
      # S1: 50 sesiones no registradas, medir avisos ≤2s
      k6 run $K6_OUT load/e01.js
      ;;
    E02)
      # D1: sin fallos
      # D2: detener etapas X veces
      # D3: congelar pedidos
      # D5: entregas repetidas
      inyector -fases D1 D2 D3 D5 -plan "$linea"
      ;;
  esac
  
  # 4. CERRAR (20s más, para salidas tardías)
  k6 run $K6_OUT --duration 20s load/carga.js
  
  # 5. VEREDICTO
  veredicto "$EXPERIMENTO" "$STAMP"
done
```

### Ciclo de una corrida

```
preparar(E02, T=2000, N=3)
├─ docker compose up -d               # Levanta 12 micros + infra
├─ esperar_salud 8081 8082 ... 8097   # Loop 90s, curl /actuator/health
├─ sql: SELECT operacion.reiniciar_e02()  # Truncate tablas
├─ Vaciar colas RabbitMQ
└─ SONDEO_T_MS=2000 SONDEO_N=3 docker compose up -d monitor

calentar()
├─ k6 run --duration 5m load/carga.js
└─ Esto NO entra en veredicto

medir()
├─ E02 D1: k6 con carga normal (baseline)
├─ E02 D2: docker stop etapa-X → Monitor detecta → Ventas reacciona
├─ E02 D3: inyector congela pedidos → Monitor detecta pedidos.atascados
└─ E02 D5: entregas repetidas (inyectar)

cerrar()
├─ k6 run --duration 20s load/carga.js
└─ Tiempo para que lleguen respuestas tardías

veredicto()
├─ psql: \i analisis/e02.sql
├─ Genera: analisis/resultados/e02-...-TIMESTAMP/veredicto.txt
└─ PASS/FAIL por criterio
```

### Validación de corrida

Una corrida es **INVÁLIDA** si:

```bash
HUECO_MAX_S=30   # Plazo máximo entre dos pedidos (carga de fondo 1/s)

# Hueco > 30s → máquina se congeló o suspendió
if [[ $(last_arrival_gap) > 30 ]]; then
  log "Corrida contaminada: reintentando..."
  REINTENTOS=$((REINTENTOS - 1))
  continue
fi

# k6 > 1% fallos
if k6_error_rate > 1%; then
  exit 1
fi
```

---

## 6. TOPOLOGÍA DE CONTENEDORES

### `deploy/docker-compose.yml`

```yaml
version: "3.8"
name: reto2

services:
  # --- Infraestructura -------------------------------------------------------
  postgres:
    image: postgres:17-alpine
    ports: ["5433:5432"]
    volumes:
      - ./postgres/01-esquema.sql:/docker-entrypoint-initdb.d/01-esquema.sql:ro
      - ./postgres/02-semilla.sql:/docker-entrypoint-initdb.d/02-semilla.sql:ro
      - ./postgres/03-vistas.sql:/docker-entrypoint-initdb.d/03-vistas.sql:ro
      - datos:/var/lib/postgresql/data

  rabbitmq:
    image: rabbitmq:4.1-management-alpine
    ports: ["15672:15672"]
    environment:
      RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS: "+sbwt none"  # Sin busy-wait

  prometheus:
    image: prom/prometheus:latest
    ports: ["9090:9090"]
    volumes:
      - ./deploy/observabilidad/prometheus.yml:/etc/prometheus/prometheus.yml:ro

  grafana:
    image: grafana/grafana:latest
    ports: ["3000:3000"]
    volumes:
      - ./deploy/observabilidad/grafana/dashboards/:/etc/grafana/provisioning/dashboards/:ro

  # --- E01 -------------------------------------------------------------------
  sesiones:
    image: reto2/sesiones
    build: { context: .., dockerfile: deploy/Dockerfile, args: { SERVICE: sesiones } }
    ports: ["8081:8080"]
    environment: &env
      DB_URL: jdbc:postgresql://postgres:5432/reto2
      RABBIT_HOST: rabbitmq

  usuario-no-valido:
    image: reto2/usuario-no-valido
    ports: ["8082:8080"]
    environment: *env

  notificador:
    image: reto2/notificador
    ports: ["8097:8080"]
    environment: *env

  # --- E02 -------------------------------------------------------------------
  monitor:
    image: reto2/monitor
    ports: ["8095:8080"]
    environment:
      <<: *env
      SONDEO_T_MS: ${SONDEO_T_MS:-2000}
      SONDEO_N: ${SONDEO_N:-3}
      SONDEO_ESPERA_MS: ${SONDEO_ESPERA_MS:-500}
      UMBRAL_ATASCO_MS: ${UMBRAL_ATASCO_MS:-15000}

  ventas:
    image: reto2/ventas
    ports: ["8090:8080"]
    environment: *env

  etapa-facturacion:
    image: reto2/etapa
    build: { context: .., dockerfile: deploy/Dockerfile, args: { SERVICE: etapa } }
    ports: ["8091:8080"]
    environment: &etapa_env
      <<: *env
      ETAPA: facturacion

  etapa-inventario:
    image: reto2/etapa
    ports: ["8092:8080"]
    environment:
      <<: *etapa_env
      ETAPA: inventario

  etapa-despacho:
    image: reto2/etapa
    ports: ["8093:8080"]
    environment:
      <<: *etapa_env
      ETAPA: despacho

  # ... más micros

volumes:
  datos:
  prometheus:
```

### Puertos del host

```
8081  sesiones
8082  usuario-no-valido (Verificador)
8083  receptor-sms
8084  onboarding
8090  ventas
8091  etapa-facturacion
8092  etapa-inventario
8093  etapa-despacho
8094  logistica
8095  monitor
8096  auditor-cola
8097  notificador

3000  Grafana
5433  PostgreSQL (5432 interno)
9090  Prometheus
15672 RabbitMQ Management
```

---

## 7. OBSERVABILIDAD EN VIVO

### Métricas de aplicación (Micrometer)

```
# E01
sesiones.aperturas                  (Counter)
sesiones.credencial.rechazada       (Counter)

# E02 - Monitor
monitor.etapa.detenida[etapa]       (Gauge: 0/1)
monitor.sondeos.fallidos_seguidos   (Gauge)
monitor.config.t_ms                 (Gauge: parámetro T)
monitor.config.n                    (Gauge: parámetro N)
monitor.config.umbral_ms            (Gauge: parámetro U)

# E02 - Ventas
ventas.pedidos.encolados[etapa]     (Counter)

# k6 (remote write)
http_reqs                           (count, rate)
http_req_duration                   (ms, p50/p95/p99)
http_req_failed                     (count, %)
```

### Dashboards Grafana

- **e01.json**: Aperturas/s, avisos/s, demora (ms) por fase
- **e02.json**: Pedidos en cola, etapas detenidas, demora detección
- **evidencias-e01.json**: Trazas con anotaciones de caída
- **evidencias-e02.json**: Trazas con caídas inyectadas

---

## 8. PATRONES DE RESILIENCIA Y GARANTÍAS

### IDEMPOTENCIA (ADR-005)

```
Problema: Si el bróker ACK se pierde, Ventas reintenta → duplicado
Solución: Clave única (pedido, etapa, intento)

INSERT INTO operacion.senal (pedido_id, etapa, intento, detectada_en)
VALUES (?, ?, ?, ?)
ON CONFLICT DO NOTHING    ← Ignora reintentos

Status:
├─ 0 filas → Ya fue procesado → return (noop)
└─ 1 fila → Nuevo → procesar y publicar
```

### ENTREGA GARANTIZADA (NR-004a)

```
Monitor notifica → Ventas publica con CorrelationData
     ↓
bus.convertAndSend(..., correlacion)
     ↓
Espera ack: correlacion.getFuture().get(5000 ms)
     ↓
SI ack:   UPDATE senal.confirmada_en → éxito
SI NO:    DELETE senal → reintenta en próximo ciclo
```

### DETECTABILIDAD

```
Cada evento entra en tabla operacion.evento:
  - Timestamp exacto
  - Sesión o pedido (identificador único)
  - Contexto (etapa, vendedor, dispositivo)
  - Datos (demoras, causas)

Veredicto: SQL que cruza entrada → salida
  - t0 sesion.abierta
  - t1 aviso.emitido
  - demora = t1 - t0
  - PASS si ≤ 2s y único por sesión
```

---

## 9. CONFIGURACIÓN DE BUILD

### Gradle multi-proyecto

```
build.gradle.kts (raíz)
├── Declara plugins: Spring Boot, dependency-management
├── Configura Java 21 para todos los subprojectos
└── Define repos y dependencias comunes

services/comun/build.gradle.kts
├── No aplica Spring Boot
└── Define Registro.java, Bus.java, Http.java

services/sesiones/build.gradle.kts
├── Aplica Spring Boot
├── Hereda Java 21
├── Importa BOM de Spring Boot
└── Genera app.jar → /services/sesiones/build/libs/app.jar

... (similar para cada micro)
```

### Docker: Multi-stage build

```dockerfile
# Etapa 1: Compilación
FROM eclipse-temurin:21-jdk AS builder
COPY . /src
WORKDIR /src
RUN ./gradlew build -x test

# Etapa 2: Runtime
FROM eclipse-temurin:21-jre
ARG SERVICE
COPY --from=builder /src/services/${SERVICE}/build/libs/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

**Invocación**:
```bash
docker build --build-arg SERVICE=sesiones -t reto2/sesiones .
docker build --build-arg SERVICE=monitor -t reto2/monitor .
```

---

## 10. SUMARIO: FLUJO COMPLETO E01

```
1. k6: POST /sesiones {sesionId, vendedorId, password, dispositivoId}

2. SesionController:
   ├─ Valida password_hash vs BD
   ├─ INSERT operacion.sesion
   ├─ anotar("sesion.abierta")  ← t0
   └─ publish("seguridad/sesion-abierta")

3. RabbitMQ: "seguridad" exchange → "verificador.sesiones" queue

4. VerificadorDeDispositivo:
   ├─ SELECT dispositivo WHERE id=? AND registrado=true
   ├─ SI NO EXISTS: anotar("aviso.emitido")  ← t1
   └─ publish("notificador/alertas")

5. RabbitMQ: "notificador" exchange → "notificador.alertas" queue

6. Notificador:
   ├─ Email/SMS (simulado)
   └─ anotar("alerta.notificada")

7. Veredicto SQL:
   SELECT s, v, (v.cuando - s.cuando) as demora
   FROM evento s LEFT JOIN evento v
   WHERE s.evento='sesion.abierta' AND v.evento='aviso.emitido'
   AND dispositivoId NOT IN (SELECT FROM dispositivo WHERE registrado)
   
   PASS: 50 avisos cada uno ≤2s, ≤1 falso por 100 legítimos
```

---

## 11. SUMARIO: FLUJO COMPLETO E02

```
1. Monitor.scheduleAtFixedRate(T ms):
   ├─ GET /salud?mayorQueMs=U (etapa-facturacion, inventario, despacho) en paralelo
   ├─ SI timeout: cuenta.registrarFallo()
   ├─ SI N fallos: aplicar(ETAPA_CAIDA)
   └─ POST /fallas/etapa {etapa}

2. EnvioALaDeadLetterQueue:
   ├─ SELECT pedido_etapa WHERE etapa=? AND estado='EN_CURSO'
   ├─ FOR pedido:
   │  ├─ INSERT senal ON CONFLICT DO NOTHING
   │  ├─ RabbitMQ.convertAndSend() con CorrelationData
   │  ├─ Espera ack (5s)
   │  ├─ SI ack: UPDATE senal.confirmada_en, anotar("pedido.encolado")  ← t1
   │  └─ SI NO: DELETE senal, reintenta próximo ciclo
   └─ Métrica: ventas.pedidos.encolados++

3. RabbitMQ: "cadena" exchange → "dead-letter-queue" (T11)

4. Veredicto SQL:
   SELECT pedido_id, COUNT(*) FROM evento WHERE evento='pedido.encolado'
   GROUP BY pedido_id HAVING COUNT(*)>1
   
   PASS: Cero duplicados, ≤6.4s demora
```

---

## Referencias

- `docs/experiments.md`: Hipótesis y criterios detallados
- `docs/quality-attributes.md`: ASR-1 a ASR-4
- `notas/plan-implementacion-experimentos.md`: Supuestos S-1 a S-12
- `analisis/e01.sql`, `analisis/e02.sql`: Veredictos exactos

---

**Última actualización**: 2026-10-12  
**Compilado para**: Java 21, Spring Boot 3, PostgreSQL 17, RabbitMQ 4.1
