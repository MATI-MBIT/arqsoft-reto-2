---
title: Vista de despliegue — Reto 2 CCP (v6)
---

# Vista de despliegue — Reto 2 CCP (v6)

Esta página dibuja dónde corre cada componente, con qué tecnología, por qué protocolo se hablan los nodos y qué pieza queda como instancia única. Son dos diagramas, uno por cada camino del reto: el de seguridad y el de la cadena del pedido. Es la única vista que nombra productos.

**Estado: propuesta.** Los diez ADR de [adrs-ccp-reto2.md](adrs-ccp-reto2.md) están en estado Propuesta. La pila (Java 21 y Spring Boot 3, PostgreSQL, RabbitMQ y Redis) es el supuesto SUP-01 de ese documento: ningún producto viene del enunciado. La portada de los diagramas está en [diagramas-ccp-reto2.md](diagramas-ccp-reto2.md).

## Cómo leer esta página

| Diagrama | Qué responde | ASR · ADR |
|---|---|---|
| DG-DEP-001 | Dónde corren la Puerta de entrada, la identidad y las escrituras, y qué pieza del borde queda única | ASR-1, ASR-2 · ADR-001, ADR-007 a ADR-010 |
| DG-DEP-002 | Dónde corren la cadena, el Coordinador y el Monitor, y cuáles quedan como instancia única | ASR-3, ASR-4 · ADR-001 a ADR-006 |

El plan de diagramas de los ADR tenía un solo DG-DEP-001. Aquí se parte en dos para que cada diagrama quepa en una pantalla. La portada trae las líneas «Diagramas afectados» que actualizan esa referencia.

## Leyenda

| Notación | Significado |
|---|---|
| «device» | Nodo físico o virtual: un teléfono, un servidor o el nodo de un producto comprado |
| «executionEnvironment» | Entorno de ejecución dentro de un nodo; aquí, la JVM que corre el servicio |
| «artifact» (hoja con esquina doblada) | Lo que se despliega en el nodo |
| ×N | Número de instancias. ×1 marca una pieza sin réplica |
| Línea sin punta | Ruta de comunicación, con su protocolo y su puerto |
| Amarillo | Nodo que aloja una táctica de un ADR o un riesgo de instancia única |
| Nota con banderín | ADR o riesgo anclado al nodo |
| Aproximación | Mermaid no dibuja el cubo 3D del nodo UML; el marco con «device» o «executionEnvironment» lo reemplaza |

---

## DG-DEP-001 · Dónde corren la Puerta de entrada, la identidad y las escrituras

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Despliegue | ASR-1 · ASR-2 | ADR-001 · ADR-007 · ADR-008 · ADR-009 · ADR-010 | propuesta |

```mermaid
---
title: "DG-DEP-001 · ¿Dónde corren el borde, la identidad y las escrituras, y qué queda único?"
config:
  layout: elk
  theme: default
  look: classic
---
%% id: DG-DEP-001 | tipo: despliegue | asr: [ASR-1, ASR-2] | adr: [ADR-001, ADR-007, ADR-008, ADR-009, ADR-010] | estado: propuesta
%% leyenda: documento · nodo UML (cubo) aproximado con marco «device»/«executionEnvironment»
flowchart LR
    subgraph TEL["«device» Teléfono ×N · vendedor o tendero"]
        APK@{ shape: doc, label: "«artifact»<br/>app-ccp.apk" }
    end
    subgraph NGW["«executionEnvironment» JVM 21 ×2 · Puerta de entrada de la API"]
        JGW@{ shape: doc, label: "«artifact»<br/>puerta-entrada.jar" }
    end
    subgraph NSEG["«executionEnvironment» JVM 21 ×2 · Identidad y seguridad"]
        JSEG@{ shape: doc, label: "«artifact»<br/>identidad-seguridad.jar" }
    end
    subgraph NESC["«executionEnvironment» JVM 21 ×2 · Pedidos e Inventario"]
        JESC@{ shape: doc, label: "«artifact»<br/>pedidos-inventario.jar" }
    end
    RED["«device» ×1<br/>Redis · Lista de revocación"]
    BRK["«device» ×1<br/>RabbitMQ · Bróker de mensajes"]
    PG["«device» ×1<br/>PostgreSQL · Base transaccional"]

    TEL ---|"«HTTPS» 443"| NGW
    NGW ---|"«RESP» 6379 · consulta en cada petición"| RED
    NGW ---|"«HTTPS» · sesión"| NSEG
    NGW ---|"«HTTPS» · escrituras y consultas"| NESC
    NSEG ---|"«RESP» 6379 · revocar"| RED
    NSEG ---|"«HTTPS» · compensar"| NESC
    NSEG ---|"«AMQP» 5672"| BRK
    NSEG ---|"«JDBC» 5432"| PG
    NESC ---|"«AMQP» 5672 · outbox"| BRK
    NESC ---|"«JDBC» 5432"| PG

    N1>"×1 en el camino de cada petición · ADR-009"]
    N1 -.- RED
    classDef tactica fill:#fff4d6,stroke:#b8860b
    class RED,BRK,PG tactica
```

| Nodo | Instancias | Componentes que corren ahí | De dónde sale |
|---|---|---|---|
| Teléfono | ×N | App móvil. El del vendedor lo suministra CCP (R-2); el del tendero es suyo (R-11) | contexto |
| Puerta de entrada | ×2 | Puerta de entrada de la API | ADR-009 |
| Identidad y seguridad | ×2 | Gestor de sesión, Verificador de dispositivo, Detector de escrituras indebidas, Reacción ante acceso indebido, Notificador a seguridad | **propuesta**: agrupa lo que observa la sesión y la escritura |
| Pedidos e Inventario | ×2 | Pedidos, Inventario, con su relevo del outbox | **propuesta**: son las dos funciones que escriben (ADR-008) |
| Redis | ×1 | Lista de revocación | ADR-009 |
| RabbitMQ | ×1 | Bróker de mensajes: `sesion.abierta`, `escritura.realizada`, `alerta.seguridad` | ADR-001 |
| PostgreSQL | ×1 | Base transaccional, con un esquema por servicio; la bitácora y el outbox viven en el de Pedidos e Inventario | ADR-001 · ADR-008 |

| Marca | ID | Táctica (curso) | Nodo | ADR | Precio → cobra a |
|---|---|---|---|---|---|
| — | DIS-11 | Réplicas de servicios sin estado en memoria: cualquier instancia atiende | Puerta · Identidad y seguridad · Pedidos e Inventario (×2) | **propuesta** | El estado sale a la base, el bróker y la Lista, que quedan ×1 → disponibilidad de esos tres |
| — | SEG-13 | La revocación vive fuera de las instancias de la Puerta, así que alcanza a las dos | Redis | ADR-009 | En el camino de cada petición → disponibilidad del borde (R-1, TO-009a) |
| — | MOD-04 | Intermediario durable | RabbitMQ | ADR-001 | Pieza común de los cuatro caminos (R-001a) |

**Qué muestra:** los servicios sin estado en memoria corren con dos instancias, y todo su estado vive en tres piezas únicas: la base, el bróker y la Lista de revocación. La Lista es la más expuesta, porque la Puerta la consulta en cada petición. · **Decisión que refleja:** ADR-001 (bróker y base), ADR-008 (outbox en la base de Pedidos e Inventario), ADR-009 (la Lista consultada desde el borde) y ADR-007 y ADR-010 (los componentes de identidad y reacción). · **Qué no muestra:** la nube, el orquestador de contenedores, la red y la redundancia de la base, el bróker y la Lista. S-3 deja las fallas de infraestructura fuera del alcance. Tampoco muestra el canal hacia el Área de seguridad, que sigue sin definir.

---

## DG-DEP-002 · Dónde corren la cadena, el Coordinador y el Monitor

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Despliegue | ASR-3 · ASR-4 | ADR-001 · ADR-002 · ADR-004 · ADR-005 · ADR-006 | propuesta |

```mermaid
---
title: "DG-DEP-002 · ¿Dónde corre la cadena del pedido y qué queda como instancia única?"
config:
  layout: elk
  theme: default
  look: classic
---
%% id: DG-DEP-002 | tipo: despliegue | asr: [ASR-3, ASR-4] | adr: [ADR-001, ADR-002, ADR-004, ADR-005, ADR-006] | estado: propuesta
%% leyenda: documento · nodo UML (cubo) aproximado con marco «device»/«executionEnvironment»
flowchart LR
    subgraph NESC["«executionEnvironment» JVM 21 ×2 · Pedidos e Inventario"]
        JESC@{ shape: doc, label: "«artifact»<br/>pedidos-inventario.jar" }
    end
    subgraph NETA["«executionEnvironment» JVM 21 ×2 · Facturación y Validación de despacho"]
        JETA@{ shape: doc, label: "«artifact»<br/>etapas.jar" }
    end
    subgraph NCOO["«executionEnvironment» JVM 21 ×1 · Coordinador y Bandeja"]
        JCOO@{ shape: doc, label: "«artifact»<br/>coordinador.jar" }
    end
    subgraph NMON["«executionEnvironment» JVM 21 ×1 · Monitor de la cadena"]
        JMON@{ shape: doc, label: "«artifact»<br/>monitor.jar" }
    end
    BRK["«device» ×1<br/>RabbitMQ · temas y Cola de reintentos"]
    PG["«device» ×1<br/>PostgreSQL · un esquema por servicio"]

    NESC ---|"«HTTPS» · iniciar"| NCOO
    NESC ---|"«AMQP» 5672"| BRK
    NESC ---|"«JDBC» 5432"| PG
    NETA ---|"«AMQP» 5672"| BRK
    NETA ---|"«JDBC» 5432"| PG
    NCOO ---|"«AMQP» 5672"| BRK
    NCOO ---|"«JDBC» 5432"| PG
    NMON ---|"«HTTPS» · vencidas cada 5 s"| NCOO
    NMON ---|"«HTTPS» · salud cada 5 s"| NETA
    NMON ---|"«AMQP» · encolar"| BRK

    N1>"×1 sin réplica: R-002a y R-004a"]
    N1 -.- JMON
    classDef tactica fill:#fff4d6,stroke:#b8860b
    class JCOO,JMON,BRK tactica
```

| Nodo | Instancias | Componentes que corren ahí | De dónde sale |
|---|---|---|---|
| Pedidos e Inventario | ×2 | Pedidos, que arranca la cadena, e Inventario, que es su segunda etapa | **propuesta** |
| Etapas | ×2 | Facturación, Validación de despacho | **propuesta**: son las dos etapas que sondea el Monitor |
| Coordinador | ×1 | Coordinador de la cadena, Bandeja de pedidos escalados | ADR-002; la Bandeja junto al Coordinador es **propuesta** |
| Monitor | ×1 | Monitor de la cadena | ADR-004 |
| RabbitMQ | ×1 | Bróker de mensajes: `etapa.ejecutar`, `etapa.completada`, `cadena.escalada`, `pedido.listo` y la Cola de reintentos | ADR-001 · ADR-006 |
| PostgreSQL | ×1 | Base transaccional: `CadenaEtapa` en el esquema del Coordinador; `EtapaProcesada` y el efecto en el de cada etapa | ADR-001 · ADR-002 · ADR-005 |

| Marca | ID | Táctica (curso) | Nodo | ADR | Precio → cobra a |
|---|---|---|---|---|---|
| — | INT-08 · DIS-15 | Orquestación con estado persistido: el estado sobrevive a la caída del Coordinador porque vive en la base | Coordinador ×1 · PostgreSQL | ADR-002 | Si el Coordinador cae, ninguna cadena avanza hasta que vuelva → ASR-4 (R-002a) |
| — | DIS-03 | Monitor dedicado | Monitor ×1 | ADR-004 | Si el Monitor cae, nadie detecta nada → ASR-3 (R-004a) |
| — | DIS-01 | Sondeo de salud a las etapas | Ruta Monitor → Etapas | ADR-004 | Tráfico de sondeo cada 5 s → desempeño |
| — | MOD-04 · DIS-14 | Colas durables; lo que la Cola de reintentos no entrega va a la Bandeja | RabbitMQ | ADR-001 · ADR-006 | Pieza común de los cuatro caminos (R-001a) |

**Qué muestra:** el Coordinador y el Monitor corren como instancia única, y ese es el precio que ADR-002 y ADR-004 aceptaron. Dibujar la réplica que no existe escondería el riesgo. El resto de los servicios corre con dos instancias, porque su estado vive en la base. · **Decisión que refleja:** ADR-001 (bróker y base), ADR-002 (Coordinador ×1), ADR-004 (Monitor ×1 y el sondeo), ADR-005 (la clave única en la base de cada etapa) y ADR-006 (la Cola de reintentos y la Bandeja). · **Qué no muestra:** Logística, cuyo protocolo de entrada no está definido. Tampoco la ruta del Monitor a la base: el Monitor guarda sus señales, pero ningún conector de los ADR dice dónde (ver Huecos).

**Por qué no se dibuja redundancia en el Coordinador ni en el Monitor.** El catálogo del curso pide, para disponibilidad, un despliegue con la redundancia visible. Aquí la redundancia visible es la de los servicios ×2; la de las dos piezas centrales no existe todavía. ADR-004 deja abierta la opción de dos Monitores con un candado en la base (R-004a), y ningún ADR propone un segundo Coordinador. Cuando uno lo decida, este diagrama cambia.
