---
title: Vista de concurrencia — Reto 2 CCP (v6)
---

# Vista de concurrencia — Reto 2 CCP (v6)

Esta página dibuja qué corre al mismo tiempo, por qué colas pasa el trabajo y qué estado comparten los hilos. Abre con dos diagramas de objetos activos, uno por cada camino del reto. Siguen cinco secuencias de punta a punta, una por decisión que se demuestra en el tiempo: el orden de la cadena y los cuatro ASR, cada uno con su camino de fallo y su medida.

**Estado: propuesta.** Los diez ADR de [adrs-ccp-reto2.md](adrs-ccp-reto2.md) están en estado Propuesta. La portada de los diagramas, con la matriz de trazabilidad y los huecos, está en [diagramas-ccp-reto2.md](diagramas-ccp-reto2.md). Los componentes que aparecen aquí son los de la [vista de componentes](vista-componentes.md), con el mismo nombre.

## Cómo leer esta página

| Diagrama | Qué responde | ASR · ADR |
|---|---|---|
| DG-CON-001 | Qué hilos y colas llevan los caminos de seguridad, y qué estado comparten | ASR-1, ASR-2 · ADR-001, ADR-007 a ADR-010 |
| DG-CON-002 | Qué hilos y colas llevan la cadena del pedido, y qué se sincroniza en la fila de cada etapa | ASR-3, ASR-4 · ADR-001 a ADR-006 |
| DG-SEQ-013 | Cómo recorre un pedido las tres etapas en orden hasta logística | ASR-3, ASR-4 · ADR-003 |
| DG-SEQ-014 | Cómo se nota en ≤ 30 s un pedido detenido en una etapa que sigue viva | ASR-3 · ADR-004 |
| DG-SEQ-015 | Cómo se reanuda la etapa en ≤ 5 s sin duplicar, y cuándo va a una persona | ASR-4 · ADR-005, ADR-006 |
| DG-SEQ-016 | Cómo llega en ≤ 2 s el aviso de una sesión abierta desde otro dispositivo | ASR-1 · ADR-007 |
| DG-SEQ-017 | Cómo se detecta la escritura indebida y se revoca, bloquea y revierte en ≤ 5 s | ASR-2 · ADR-008, ADR-009, ADR-010 |

Los ID DG-SEQ-013 a 017 son los del plan de diagramas de los ADR (sección 6 de [adrs-ccp-reto2.md](adrs-ccp-reto2.md)).

## Leyenda

| Notación | Significado |
|---|---|
| ‖ «process» ‖ | Proceso: un programa en ejecución, con su multiplicidad (×1, ×2) |
| ‖ «thread» ‖ | Hilo o grupo de hilos dentro de un proceso, con su multiplicidad (1..N) |
| «queue» | Cola durable del bróker. Guarda cada mensaje hasta que su consumidor lo confirma |
| «entity» | Estado que comparten varios hilos; la arista dice cómo se sincroniza |
| Línea continua | Llamada o escritura síncrona |
| Línea punteada | Mensaje que no se pudo procesar y va a otro destino |
| `-)` en una secuencia | Mensaje asíncrono: quien lo envía no espera respuesta |
| Amarillo | Elemento que aloja una táctica de un ADR |
| Nota con banderín | ADR y precio de la decisión anclada |

**Qué significa «el bróker entrega al menos una vez».** El bróker de ADR-001 vuelve a entregar todo mensaje que su consumidor no confirmó. Eso protege contra la pérdida, pero un mismo evento puede llegar dos veces. Por eso cada consumidor de esta página tiene una clave que le impide actuar dos veces sobre lo mismo.

**Presupuestos de tiempo.** Las secuencias de ASR-1 y ASR-2 reparten la medida entre sus tramos. Esos repartos son una asignación de diseño, no una medición: sirven para saber qué tramo revisar primero cuando la prueba de carga de R-12 no cumpla.

---

## DG-CON-001 · Hilos y colas de los caminos de seguridad

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Objetos activos (concurrencia) | ASR-1 · ASR-2 | ADR-001 · ADR-007 · ADR-008 · ADR-009 · ADR-010 | propuesta |

```mermaid
---
title: "DG-CON-001 · ¿Qué hilos y colas llevan la sesión y la escritura, y qué comparten?"
config:
  layout: elk
  theme: default
  look: classic
---
%% id: DG-CON-001 | tipo: concurrencia (objetos activos) | asr: [ASR-1, ASR-2] | adr: [ADR-001, ADR-007, ADR-008, ADR-009, ADR-010] | estado: propuesta
%% leyenda: documento
flowchart LR
    GWT["‖ «thread» Puerta de entrada ‖<br/>1..N hilos en cada una de 2 instancias"]
    LRV["«entity» «T1»<br/>Lista de revocación"]
    SESP["‖ «process» Gestor de sesión ‖"]
    QSES[["«queue»<br/>sesion.abierta"]]
    VDIT["‖ «thread» Verificador ‖<br/>consumidores 1..N"]
    RELT["‖ «thread» RelevoOutbox ‖<br/>uno por instancia de Pedidos e Inventario"]
    QESC[["«queue»<br/>escritura.realizada"]]
    DETT["‖ «thread» Detector ‖<br/>consumidores 1..N"]
    REAP["‖ «process» Reacción ‖<br/>una reacción por idEscritura"]
    QALE[["«queue»<br/>alerta.seguridad"]]
    NOTT["‖ «thread» Notificador ‖<br/>un aviso por idAlerta"]

    GWT -- "lee en cada petición, sin lock" --> LRV
    SESP -- "publica al abrir sesión" --> QSES
    QSES -- "entrega al menos una vez" --> VDIT
    VDIT -- "publica si no coincide" --> QALE
    RELT -- "publica lo confirmado" --> QESC
    QESC -- "entrega al menos una vez" --> DETT
    DETT -- "reaccionar" --> REAP
    REAP -- "escritura atómica con vencimiento" --> LRV
    REAP -- "publica" --> QALE
    QALE -- "entrega al menos una vez" --> NOTT

    N1>"ADR-009 · un escritor, muchos lectores sin lock"]
    N1 -.- LRV
    classDef tactica fill:#fff4d6,stroke:#b8860b
    class LRV,VDIT,DETT,REAP,NOTT tactica
```

| Marca | ID | Táctica (curso) | Elemento | ADR | Precio → cobra a |
|---|---|---|---|---|---|
| T1 | SEG-13 | Revocar el acceso: la Reacción escribe la clave y todas las instancias de la Puerta la leen | Lista de revocación | ADR-009 | Una lectura por petición en el camino crítico → disponibilidad del borde (R-1) |
| — | MOD-04 | Intermediario con colas durables entre quien produce y quien consume | Las tres colas | ADR-001 | Un salto por cola → latencia de ASR-1 y ASR-2 (TO-001a) |

**Qué se sincroniza y cómo.**

| Estado compartido | Quién escribe · quién lee | Cómo se protege | De dónde sale |
|---|---|---|---|
| Lista de revocación | Escribe solo la Reacción · leen todos los hilos de las dos instancias de la Puerta | Cada clave se escribe de forma atómica con su vencimiento; la lectura no toma lock | ADR-009 |
| Registro de reacciones | Los consumidores del Detector pueden pedir dos veces la misma reacción si el evento se repite | Clave única `idEscritura`: la segunda petición encuentra la reacción ya abierta | ADR-010 (NR-010a) |
| Avisos entregados | Una alerta repetida por el bróker llega dos veces al Notificador | Clave única `idAlerta`, registrada después de entregar | **propuesta**: ningún ADR decide la deduplicación del aviso |
| Outbox de cada instancia | Cada instancia de Pedidos e Inventario tiene su propio relevo | El relevo solo lee las filas de su transacción ya confirmada; si publica dos veces, el Detector y la Reacción absorben el duplicado | ADR-008 |

**Qué muestra:** ningún control de seguridad corre en el hilo que atiende al usuario. La sesión y la escritura terminan, y su evento se procesa en otro hilo, en paralelo. El único estado que comparten el camino del usuario y el de la reacción es la Lista de revocación. · **Decisión que refleja:** ADR-001 (colas durables), ADR-007 y ADR-008 (consumidores por evento), ADR-009 (la Lista) y ADR-010 (una reacción por escritura). · **Qué no muestra:** el número de hilos de cada consumidor, que depende de la prueba de carga con el Ambiente A (11 transacciones por segundo).

---

## DG-CON-002 · Hilos y colas de la cadena del pedido

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Objetos activos (concurrencia) | ASR-3 · ASR-4 | ADR-001 · ADR-002 · ADR-004 · ADR-006 | propuesta |

```mermaid
---
title: "DG-CON-002 · ¿Qué hilos tocan la fila de cada etapa y cómo no se pisan?"
config:
  layout: elk
  theme: default
  look: classic
---
%% id: DG-CON-002 | tipo: concurrencia (objetos activos) | asr: [ASR-3, ASR-4] | adr: [ADR-001, ADR-002, ADR-004, ADR-006] | estado: propuesta
%% leyenda: documento
flowchart LR
    subgraph COOP["‖ «process» Coordinador de la cadena ×1 ‖"]
        CMT["‖ «thread» «T1» ‖<br/>ConsumidorMensajes"]
        RNT["‖ «thread» «T2» ‖<br/>Reanudador · espera 3 s"]
    end
    subgraph MONP["‖ «process» Monitor de la cadena ×1 ‖"]
        BPT["‖ «thread» «T3» ‖<br/>BarridoPlazos · cada 5 s"]
        SST["‖ «thread» «T3» ‖<br/>SondeoSalud · cada 5 s"]
    end
    EST["«entity»<br/>CadenaEtapa"]
    QEJ[["«queue»<br/>etapa.ejecutar · una por etapa"]]
    ETP["‖ «process» Etapas ×2 ‖<br/>consumidores 1..N"]
    QCO[["«queue»<br/>etapa.completada"]]
    QRE[["«queue»<br/>Cola de reintentos"]]
    BES["‖ «process» Bandeja de pedidos escalados ‖"]

    CMT -- "update condicional: si sigue en curso" --> EST
    RNT -- "update condicional: si sigue en reintento" --> EST
    BPT -- "lee vencidas, sin escribir" --> EST
    CMT -- "publica la siguiente" --> QEJ
    RNT -- "reenvía la detenida" --> QEJ
    QEJ -- "entrega" --> ETP
    ETP -- "publica" --> QCO
    QCO -- "entrega" --> CMT
    SST -- "sondea" --> ETP
    BPT -- "encola la señal" --> QRE
    QRE -- "entrega" --> RNT
    QRE -. "mensajes fallidos" .-> BES
    RNT -- "publica cadena.escalada" --> BES

    N1>"propuesta · sincroniza la fila por su estado"]
    N1 -.- EST
    classDef tactica fill:#fff4d6,stroke:#b8860b
    class CMT,RNT,BPT,SST,QRE tactica
```

| Marca | ID | Táctica (curso) | Elemento | ADR | Precio → cobra a |
|---|---|---|---|---|---|
| T1 | INT-08 · DIS-15 | Orquestación con estado por etapa: el mismo hilo que recibe la confirmación publica la etapa siguiente | ConsumidorMensajes | ADR-002 | Un solo proceso: si cae, ninguna cadena avanza → ASR-4 (R-002a) |
| T2 | DIS-12 · DIS-14 | Un reintento con espera de 3 s, y escalamiento si no llega la confirmación | Reanudador | ADR-006 | La espera vive en memoria: si el proceso cae, la recoge el barrido siguiente, hasta 5 s tarde → ASR-4 (R-002a) |
| T3 | DIS-04 · DIS-03 · DIS-01 | Barrido de plazos y sondeo de salud, cada uno en su hilo programado | BarridoPlazos · SondeoSalud | ADR-004 | Un solo proceso Monitor → ASR-3 (R-004a) |
| — | MOD-04 | Colas durables: el comando espera aunque la etapa esté caída; lo que la Cola no puede entregar va a la Bandeja | Colas | ADR-001 · ADR-006 | Pieza común de los cuatro caminos (R-001a) |

**Qué se sincroniza y cómo.** Tres hilos tocan la misma fila `CadenaEtapa`: el que recibe la confirmación, el que reanuda y el que barre. El barrido solo lee. Los otros dos escriben con una **actualización condicional**: la fila cambia solo si sigue en el estado que el hilo espera, y si no, el hilo no hace nada. Así, si la etapa confirma justo cuando el Reanudador va a escalar, gana el primero que escribe y el otro encuentra la fila cambiada. Esta sincronización es **propuesta**: ADR-002 guarda el estado en la base, pero ningún ADR decide cómo se resuelve la carrera (ver Huecos en la portada).

**Aviso del lint justificado (AP-09, 13 elementos).** El conteo incluye los dos marcos de proceso, que agrupan a los hilos del Coordinador y del Monitor. Sin ellos, el diagrama no diría que cada par de hilos vive en un proceso único, que es el riesgo de R-002a y R-004a.

**Qué muestra:** que el Coordinador y el Monitor son procesos únicos, con dos hilos cada uno, y que todo el trabajo entre ellos y las etapas pasa por colas durables. · **Decisión que refleja:** ADR-001 (colas), ADR-002 (estado por etapa), ADR-004 (barrido y sondeo) y ADR-006 (reintento y Bandeja). · **Qué no muestra:** el número de consumidores de cada etapa, que depende de la prueba de carga con el Ambiente A.

---

## DG-SEQ-013 · El pedido recorre las tres etapas en orden hasta logística

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia | ASR-3 · ASR-4 | ADR-003 | propuesta |

```mermaid
---
title: "DG-SEQ-013 · ¿Cómo recorre un pedido las tres etapas en orden, y qué pasa si una se detiene?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-013 | tipo: secuencia | asr: [ASR-3, ASR-4] | adr: [ADR-003] | estado: propuesta
sequenceDiagram
    autonumber
    actor TEN as Tendero
    participant APP as App móvil
    participant PED as Pedidos
    participant COO as Coordinador de la cadena
    participant BRK as Bróker de mensajes
    participant FAC as Facturación
    participant INV as Inventario
    participant DES as Validación de despacho
    participant LOG as Logística
    TEN->>+APP: confirmar pedido
    APP->>+PED: crearPedido(líneas)
    PED->>+COO: iniciar(idPedido)
    COO-)BRK: etapa.ejecutar(FACTURACION) con plazo
    COO-->>-PED: cadena iniciada
    PED-->>-APP: pedido confirmado
    APP-->>-TEN: pedido confirmado
    BRK-)FAC: etapa.ejecutar(FACTURACION)
    FAC-)BRK: etapa.completada(FACTURACION)
    BRK-)COO: etapa.completada(FACTURACION)
    COO-)BRK: etapa.ejecutar(INVENTARIO) con plazo
    BRK-)INV: etapa.ejecutar(INVENTARIO)
    INV-)BRK: etapa.completada(INVENTARIO)
    BRK-)COO: etapa.completada(INVENTARIO)
    COO-)BRK: etapa.ejecutar(DESPACHO) con plazo
    BRK-)DES: etapa.ejecutar(DESPACHO)
    alt despacho responde
        DES-)BRK: etapa.completada(DESPACHO)
        BRK-)COO: etapa.completada(DESPACHO)
        COO-)BRK: pedido.listo
        BRK-)LOG: pedido.listo
    else despacho no responde ni señala error
        Note over COO,DES: la fila queda en curso · sigue en DG-SEQ-014
    end
    Note over TEN,LOG: ADR-003 · Σ tres etapas ≤ 25 s · en preparación ≤ 60 s
```

**Qué muestra:** que en cada momento hay a lo sumo una etapa en curso por pedido, que es el caso que ASR-4 describe. El tendero recibe la confirmación antes de que empiece la primera etapa. · **Decisión que refleja:** ADR-003, que descarta las etapas en paralelo del BPMN. · **Qué no muestra:** la reserva de cantidades al confirmar (R-5) ni el aviso de «en preparación» al tendero.

**La medida.** Los 60 s que el tendero espera antes de ver su pedido en preparación (S-7) menos los 35 s del presupuesto conjunto de ASR-3 y ASR-4 dejan 25 s para las tres etapas. En serie, la cadena tarda la suma de las tres, no la más lenta (R-003a). El experimento de ADR-003 mide esa suma con la carga del Ambiente A antes de aceptar el ADR.

---

## DG-SEQ-014 · ASR-3: el pedido detenido en una etapa que sigue viva

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia | ASR-3 | ADR-004 | propuesta |

```mermaid
---
title: "DG-SEQ-014 · ¿Cómo se nota en ≤ 30 s un pedido detenido en una etapa que sigue viva?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-014 | tipo: secuencia | asr: [ASR-3] | adr: [ADR-004] | estado: propuesta
sequenceDiagram
    autonumber
    participant COO as Coordinador de la cadena
    participant BRK as Bróker de mensajes
    participant DES as Validación de despacho
    participant MON as Monitor de la cadena
    participant COL as Cola de reintentos
    COO-)BRK: etapa.ejecutar(DESPACHO) · plazoEn = ahora + plazo
    BRK-)DES: etapa.ejecutar(DESPACHO)
    Note over DES: t_stop · la etapa sigue viva, el pedido no avanza
    loop cada 5 s
        alt la etapa responde al sondeo
            MON->>+DES: salud()
            DES-->>-MON: ok · el sondeo no ve el pedido quieto
        else k sondeos seguidos sin respuesta
            MON-xDES: salud()
            MON->>MON: adelantar la señal de toda la etapa
        end
        MON->>+COO: vencidas(ahora)
        alt ahora < plazoEn
            COO-->>MON: ninguna
        else ahora ≥ plazoEn
            COO-->>MON: idPedido, DESPACHO, intento 0
            MON-)COL: encolar(idPedido, DESPACHO) · t_señal
        end
        deactivate COO
    end
    Note over COO,COL: ASR-3 · señal ≤ plazo (≤ 25 s) + barrido (5 s) = 30 s
```

**Qué muestra:** por qué el sondeo de salud no basta. La etapa responde al sondeo mientras el pedido sigue quieto, y solo el plazo vencido lo delata. La señal llega, a más tardar, un barrido después de vencer el plazo. · **Decisión que refleja:** ADR-004, que descarta el latido solo del BPMN. · **Qué no muestra:** el valor del plazo de cada etapa, que depende de medir su p99 en operación normal; ni el número k de sondeos.

**La medida.** t_señal − t_stop ≤ plazo de la etapa + periodo del barrido. Con el plazo en 25 s y el barrido en 5 s (SUP-02, SUP-03), la señal cabe en los 30 s de ASR-3. La otra mitad de la medida, ≤ 1 falsa alarma por hora, depende de que el plazo quede por encima de la duración normal de la etapa (TO-004a).

---

## DG-SEQ-015 · ASR-4: la etapa detenida se reanuda o llega a una persona

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia | ASR-4 | ADR-005 · ADR-006 | propuesta |

```mermaid
---
title: "DG-SEQ-015 · ¿Cómo se reanuda la etapa en ≤ 5 s sin duplicar, y cuándo va a una persona?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-015 | tipo: secuencia | asr: [ASR-4] | adr: [ADR-005, ADR-006] | estado: propuesta
sequenceDiagram
    autonumber
    participant COL as Cola de reintentos
    participant COO as Coordinador de la cadena
    participant BRK as Bróker de mensajes
    participant FAC as Facturación
    participant BES as Bandeja de pedidos escalados
    actor RES as Responsable del pedido escalado
    COL-)COO: reanudar(idPedido, FACTURACION) · t_señal
    COO->>COO: marcarReintento · plazoEn = ahora + 3 s
    COO-)BRK: etapa.ejecutar(FACTURACION) solo esa etapa
    BRK-)FAC: etapa.ejecutar(FACTURACION)
    alt la etapa confirma en ≤ 3 s
        FAC->>FAC: insertar (idPedido, FACTURACION) · si existe, no emite otra
        FAC-)BRK: etapa.completada(FACTURACION)
        BRK-)COO: etapa.completada(FACTURACION)
        Note over COO: la cadena sigue con la etapa siguiente
    else sin confirmación a los 3 s
        COO->>COO: marcarEscalada(etapa y motivo)
        COO-)BRK: cadena.escalada
        BRK-)BES: cadena.escalada con etapa y motivo
        RES->>+BES: consultar la bandeja
        BES-->>-RES: pedido, etapa detenida y motivo
    end
    opt el Coordinador no procesa el mensaje
        COL-)BES: mensaje fallido con el pedido señalado
    end
    Note over COL,RES: ASR-4 · reanudada o en la Bandeja ≤ 5 s · 0 duplicados
```

**Qué muestra:** los dos finales que admite ASR-4 y por qué ninguno duplica. Si la factura ya existía, la clave única de ADR-005 impide emitir otra y la etapa solo confirma. Si la etapa no confirma en 3 s, el pedido llega a la Bandeja con la etapa y el motivo, y la Cola manda allí lo que el Coordinador no alcanza a procesar. · **Decisión que refleja:** ADR-005 y ADR-006. · **Qué no muestra:** qué hace el responsable con el pedido, que es HU-14.

**La medida.** El intento dura 3 s (SUP-04); publicar el escalamiento toma milisegundos. Los dos caben en los 5 s de ASR-4, y sumados a los 30 s de ASR-3 dan los 35 s del presupuesto conjunto.

---

## DG-SEQ-016 · ASR-1: el aviso de la sesión abierta desde otro dispositivo

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia | ASR-1 | ADR-007 | propuesta |

```mermaid
---
title: "DG-SEQ-016 · ¿Cómo llega en ≤ 2 s el aviso de una sesión abierta desde otro dispositivo?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-016 | tipo: secuencia | asr: [ASR-1] | adr: [ADR-007] | estado: propuesta
sequenceDiagram
    autonumber
    actor TER as Tercero con credenciales de un vendedor
    participant APP as App móvil
    participant GW as Puerta de entrada de la API
    participant SES as Gestor de sesión
    participant BRK as Bróker de mensajes
    participant VDI as Verificador de dispositivo
    participant NOT as Notificador a seguridad
    actor AREA as Área de seguridad
    TER->>+APP: ingresar credenciales correctas
    APP->>APP: calcular la huella del dispositivo
    APP->>+GW: abrirSesion(credenciales, huella)
    GW->>+SES: abrirSesion(credenciales, huella)
    SES-)BRK: sesion.abierta(actor, huella, t0)
    SES-->>-GW: token con jti
    GW-->>-APP: sesión abierta
    APP-->>-TER: sesión abierta · el tercero ya opera
    BRK-)VDI: sesion.abierta · salto ≤ 0,5 s
    VDI->>VDI: huellaVigente(vendedor) · consulta indexada ≤ 0,5 s
    alt la huella coincide con la registrada
        Note over VDI: sin aviso · también tras un cambio ya registrado
    else no coincide
        VDI-)BRK: alerta.seguridad(vendedor, dispositivo, hora)
        BRK-)NOT: alerta.seguridad
        NOT-)AREA: aviso · entrega ≤ 1 s
    end
    Note over TER,AREA: ASR-1 · aviso ≤ 2 s desde t0 · ≤ 1 falsa alarma/100
```

**Qué muestra:** que el tercero entra, porque sus credenciales son correctas, y que el aviso sale después sin frenarlo. El reparto de los 2 s asigna medio segundo al salto por el bróker, medio a la comparación y uno a la entrega. · **Decisión que refleja:** ADR-007 sobre el estilo por eventos de ADR-001. · **Qué no muestra:** lo que hace el área de seguridad con el aviso, que queda fuera del sistema, ni el tendero, que no tiene un dispositivo contra el cual comparar (R-007a).

**La medida.** El reloj corre desde t0, la apertura de la sesión, hasta el aviso. La segunda mitad de la medida, ≤ 1 falsa alarma por cada 100 cambios legítimos de dispositivo, depende de que cada cambio se registre antes de usarse (DG-CST-002).

---

## DG-SEQ-017 · ASR-2: la escritura indebida, detectada y revertida

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia | ASR-2 | ADR-008 · ADR-009 · ADR-010 | propuesta |

```mermaid
---
title: "DG-SEQ-017 · ¿Cómo se detecta la escritura indebida y se bloquea, cierra y revierte en ≤ 5 s?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-017 | tipo: secuencia | asr: [ASR-2] | adr: [ADR-008, ADR-009, ADR-010] | estado: propuesta
sequenceDiagram
    autonumber
    actor USR as Usuario con perfil de consulta
    participant GW as Puerta de entrada de la API
    participant INV as Inventario
    participant BRK as Bróker de mensajes
    participant DET as Detector de escrituras indebidas
    participant SES as Gestor de sesión
    participant REA as Reacción ante acceso indebido
    participant LRV as Lista de revocación
    participant NOT as Notificador a seguridad
    USR->>+GW: descargar(producto, cantidad)
    GW->>+INV: descargar(actor, producto, cantidad)
    INV-->>-GW: hecho · bitácora y outbox en la transacción
    GW-->>-USR: hecho
    INV-)BRK: escritura.realizada tras el commit
    BRK-)DET: escritura.realizada
    DET->>+SES: permisosVigentes(actor)
    SES-->>-DET: solo consulta · t_det
    DET->>+REA: reaccionar(idEscritura, actor, jti, t_det)
    REA->>LRV: 1 revocar(jti, actor) · en ms
    REA->>SES: 2 bloquear(actor)
    REA->>+INV: 3 compensar(idEscritura)
    alt compensada
        INV-->>REA: ok · suma lo descontado
        REA-)BRK: 4 alerta.seguridad con la reacción completa
    else conflicto o sin respuesta
        INV-->>REA: fallo
        REA-)BRK: 4 alerta.seguridad con la reversión sin hacer
    end
    deactivate INV
    REA-->>-DET: reacción cerrada
    BRK-)NOT: alerta.seguridad
    USR->>+GW: segunda escritura
    GW->>+LRV: revocada(jti, actor)
    LRV-->>-GW: sí
    GW-->>-USR: rechazo 403
    Note over USR,NOT: ASR-2 · ≤ 5 s desde t_det · 0 escrituras más · 0 a 60 s
```

**Qué muestra:** el camino completo del ataque. La escritura indebida ocurre y responde con éxito; el Detector la ve después, fija t_det y la Reacción corta la sesión antes de revertir. La segunda escritura del mismo actor ya no llega a Inventario. · **Decisión que refleja:** ADR-008 (detección por evento), ADR-009 (la Lista consultada en el borde) y ADR-010 (el orden de la reacción y la compensación). · **Qué no muestra:** la escritura sobre un pedido cuya cadena ya arrancó, que exige compensar también sus etapas y que ningún ADR resuelve (R-010a).

**La medida.** Revocar toma milisegundos y va primero: desde ese instante, cero escrituras posteriores. Bloquear y compensar consumen el resto de los 5 s. Si la compensación falla, el efecto residual puede pasar de 60 s, y el aviso sale con la reversión sin hacer para que una persona la termine.
