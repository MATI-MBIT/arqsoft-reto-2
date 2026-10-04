---
title: Vista de concurrencia — Reto 2 CCP (v7)
---

# Vista de concurrencia — Reto 2 CCP (v7)

Esta página dibuja qué corre al mismo tiempo, por qué colas pasa el trabajo y cómo se cumple cada medida en el tiempo. Son tres secuencias, una por cada escenario que se demuestra con un reloj: ASR-1, ASR-2, y ASR-3 junto con ASR-4, que comparten el presupuesto de 35 s. Las líneas de vida son los procesos y los hilos que ejecutan cada paso, así que la misma secuencia dice qué corre en paralelo y qué estado se comparte.

**Estado: propuesta.** Los diez ADR de [adrs-ccp-reto2.md](adrs-ccp-reto2.md) están en estado Propuesta. La portada de los diagramas, con la matriz de trazabilidad y los huecos, está en [diagramas-ccp-reto2.md](diagramas-ccp-reto2.md). Los componentes y las partes que aparecen aquí son los de la [vista de componentes](vista-componentes.md), con el mismo nombre.

**Fuente: draw.io.** El original es [drawio/vista-concurrencia.drawio](drawio/vista-concurrencia.drawio), con una pestaña por diagrama. La imagen de cada sección se exporta de ese archivo, y el bloque Mermaid que la sigue es una copia.

## Cómo leer esta página

| Diagrama | Qué responde | ASR · ADR |
|---|---|---|
| DG-SEQ-001 | Cómo llega en ≤ 2 s el aviso de una sesión abierta desde otro dispositivo | ASR-1 · ADR-001, ADR-007 |
| DG-SEQ-002 | Cómo se detecta la escritura indebida y se revoca, bloquea y revierte en ≤ 5 s | ASR-2 · ADR-001, ADR-008, ADR-009, ADR-010 |
| DG-SEQ-003 | Cómo se señala en ≤ 30 s la etapa detenida y se reanuda o llega a una persona en ≤ 5 s, sin duplicar | ASR-3, ASR-4 · ADR-001 a ADR-006 |

## Leyenda

| Notación | Significado |
|---|---|
| ‖ «process» ‖ | Línea de vida de un proceso, con su multiplicidad (×1, ×2) |
| ‖ «thread» ‖ | Línea de vida de un hilo o de un grupo de hilos dentro de un proceso (1..N) |
| «queue» | Cola durable del bróker. Guarda cada mensaje hasta que su consumidor lo confirma |
| «entity» · «datastore» | Estado que comparten varios hilos |
| Flecha con punta llena | Llamada síncrona: quien llama espera |
| Flecha con punta abierta | Mensaje asíncrono: quien lo envía no espera |
| Flecha discontinua | Respuesta |
| `alt` · `loop` · `opt` | Fragmentos combinados: alternativas, repetición y paso opcional, con su guarda entre corchetes |
| Cota roja `{≤ n s}` | Restricción de duración: el tiempo que el ASR permite entre los dos mensajes que marca |
| Amarillo | Línea de vida que aloja una táctica de un ADR |
| Nota | ADR y medida que la secuencia demuestra |

**Qué significa «el bróker entrega al menos una vez».** El bróker de ADR-001 vuelve a entregar todo mensaje que su consumidor no confirmó. Eso protege contra la pérdida, pero un mismo evento puede llegar dos veces. Por eso cada consumidor de esta página tiene una clave que le impide actuar dos veces sobre lo mismo.

**Presupuestos de tiempo.** Las secuencias reparten la medida entre sus tramos. Esos repartos son una asignación de diseño, no una medición: sirven para saber qué tramo revisar primero cuando la prueba de carga de R-12 no cumpla.

---

## DG-SEQ-001 · ASR-1: el aviso de la sesión abierta desde otro dispositivo

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia (concurrencia) | ASR-1 | ADR-001 · ADR-007 | propuesta |

![DG-SEQ-001 · Secuencia del aviso de ASR-1](png-v7/04-DG-SEQ-001.png)

| Línea de vida | Qué corre | Por qué importa a la medida |
|---|---|---|
| Puerta de entrada · 1..N hilos | Atiende la petición del usuario | Responde antes de que empiece la verificación |
| Gestor de sesión · proceso | Abre la sesión y publica `sesion.abierta` | Fija t0, desde donde corren los 2 s |
| Verificador · consumidores 1..N | Comparan la huella en paralelo con la sesión ya abierta | Su número depende de la carga del Ambiente A |
| Notificador · hilo | Entrega el aviso; registra cada `idAlerta` para no avisar dos veces | La deduplicación es **propuesta**: ningún ADR la decide |

**Qué muestra:** que el tercero entra, porque sus credenciales son correctas, y que el aviso sale después sin frenarlo. El reparto de los 2 s asigna medio segundo al salto por el bróker, medio a la comparación y uno a la entrega. · **Decisión que refleja:** ADR-007 sobre el estilo por eventos de ADR-001. · **Qué no muestra:** lo que hace el área de seguridad con el aviso, que queda fuera del sistema, ni el tendero, que no tiene un dispositivo contra el cual comparar (R-007a).

**La medida.** El reloj corre desde t0, la apertura de la sesión, hasta el aviso. La segunda mitad de la medida, ≤ 1 falsa alarma por cada 100 cambios legítimos de dispositivo, depende de que cada cambio se registre antes de usarse, por el ControladorRegistro de DG-CMP-002.

### Copia en Mermaid

```mermaid
---
title: "DG-SEQ-001 · ASR-1: ¿cómo llega en ≤ 2 s el aviso de una sesión abierta desde otro dispositivo?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-001 | tipo: secuencia | asr: [ASR-1] | adr: [ADR-001, ADR-007] | estado: propuesta
%% copia del original en drawio/vista-concurrencia.drawio
sequenceDiagram
    autonumber
    actor TER as Tercero con credenciales de un vendedor
    participant APP as App móvil
    participant GW as ‖thread 1..N‖ Puerta de entrada
    participant SES as ‖process‖ Gestor de sesión
    participant BRK as queue sesion.abierta · alerta.seguridad
    participant VDI as ‖thread 1..N‖ Verificador de dispositivo
    participant NOT as ‖thread‖ Notificador a seguridad
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
    Note over TER,AREA: ADR-007 · aviso ≤ 2 s desde t0 · ≤ 1 falsa alarma/100
```

---

## DG-SEQ-002 · ASR-2: la escritura indebida, detectada y revertida

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia (concurrencia) | ASR-2 | ADR-001 · ADR-008 · ADR-009 · ADR-010 | propuesta |

![DG-SEQ-002 · Secuencia de la reacción de ASR-2](png-v7/05-DG-SEQ-002.png)

| Estado compartido | Quién escribe · quién lee | Cómo se protege | De dónde sale |
|---|---|---|---|
| Lista de revocación | Escribe solo la Reacción · leen todos los hilos de las dos instancias de la Puerta | Cada clave se escribe de forma atómica con su vencimiento; la lectura no toma lock | ADR-009 |
| Registro de reacciones | Los consumidores del Detector pueden pedir dos veces la misma reacción si el evento se repite | Clave única `idEscritura`: la segunda petición encuentra la reacción ya abierta | ADR-010 (NR-010a) |
| Outbox de cada instancia | Cada instancia de Pedidos e Inventario tiene su propio relevo | El relevo solo lee las filas de su transacción ya confirmada; si publica dos veces, el Detector y la Reacción absorben el duplicado | ADR-008 |

**Qué muestra:** el camino completo del ataque. La escritura indebida ocurre y responde con éxito. El Detector la ve después en otro hilo, fija t_det, y la Reacción corta la sesión antes de revertir. La segunda escritura del mismo actor ya no llega a Inventario. · **Decisión que refleja:** ADR-008 (detección por evento), ADR-009 (la Lista consultada en el borde) y ADR-010 (el orden de la reacción y la compensación). · **Qué no muestra:** la escritura sobre un pedido cuya cadena ya arrancó, que exige compensar también sus etapas y que ningún ADR resuelve (R-010a).

**La medida.** Revocar toma milisegundos y va primero: desde ese instante, cero escrituras posteriores. Bloquear y compensar consumen el resto de los 5 s. Si la compensación falla, el efecto residual puede pasar de 60 s, y el aviso sale con la reversión pendiente para que una persona la termine.

### Copia en Mermaid

```mermaid
---
title: "DG-SEQ-002 · ASR-2: ¿cómo se detecta la escritura indebida y se revoca, bloquea y revierte en ≤ 5 s?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-002 | tipo: secuencia | asr: [ASR-2] | adr: [ADR-001, ADR-008, ADR-009, ADR-010] | estado: propuesta
%% copia del original en drawio/vista-concurrencia.drawio
sequenceDiagram
    autonumber
    actor USR as Usuario con perfil de consulta
    participant GW as ‖thread 1..N‖ Puerta de entrada
    participant INV as ‖process ×2‖ Inventario
    participant BRK as queue escritura.realizada · alerta.seguridad
    participant DET as ‖thread 1..N‖ Detector
    participant SES as ‖process‖ Gestor de sesión
    participant REA as ‖process‖ Reacción · una por idEscritura
    participant LRV as Lista de revocación
    participant NOT as ‖thread‖ Notificador a seguridad
    USR->>+GW: descargar(producto, cantidad)
    GW->>+INV: descargar(actor, producto, cantidad)
    INV-->>-GW: hecho · bitácora y outbox en la transacción
    GW-->>-USR: hecho
    INV-)BRK: escritura.realizada · el relevo publica tras el commit
    BRK-)DET: escritura.realizada
    DET->>+SES: permisosVigentes(actor)
    SES-->>-DET: solo consulta · t_det
    DET->>+REA: reaccionar(idEscritura, actor, jti, t_det)
    REA->>LRV: 1 · revocar(jti, actor) · en ms
    REA->>SES: 2 · bloquear(actor)
    REA->>+INV: 3 · compensar(idEscritura)
    alt compensada
        INV-->>REA: ok · suma lo descontado
        REA-)BRK: 4 · alerta.seguridad con la reacción completa
    else conflicto o sin respuesta
        INV-->>REA: fallo
        REA-)BRK: 4 · alerta.seguridad con la reversión pendiente
    end
    deactivate INV
    REA-->>-DET: reacción cerrada
    BRK-)NOT: alerta.seguridad
    USR->>+GW: segunda escritura
    GW->>+LRV: revocada(jti, actor)
    LRV-->>-GW: sí
    GW-->>-USR: rechazo 403
    Note over USR,NOT: ADR-010 · ≤ 5 s desde t_det · 0 escrituras más
```

---

## DG-SEQ-003 · ASR-3 y ASR-4: la etapa detenida, señalada y reanudada

| Tipo | ASR | ADR | Estado |
|---|---|---|---|
| Secuencia (concurrencia) | ASR-3 · ASR-4 | ADR-001 a ADR-006 | propuesta |

![DG-SEQ-003 · Secuencia de la señal de ASR-3 y la reanudación de ASR-4](png-v7/06-DG-SEQ-003.png)

| Estado compartido | Quién escribe · quién lee | Cómo se protege | De dónde sale |
|---|---|---|---|
| Fila `CadenaEtapa` | Escriben ConsumidorMensajes y Reanudador · lee BarridoPlazos | **Actualización condicional**: la fila cambia solo si sigue en el estado que el hilo espera; si no, el hilo no hace nada | **propuesta**: ADR-002 guarda el estado en la base, pero ningún ADR decide cómo se resuelve la carrera |
| Señal por pedido, etapa e intento | BarridoPlazos | Clave única (idPedido, etapa, intento): un barrido repetido no encola dos veces | ADR-004 (NR-004a) |
| `EtapaProcesada` de Facturación | Los consumidores 1..N de la etapa, si el comando llega dos veces | Clave única (idPedido, etapa) en la misma transacción que la factura | ADR-005 |

**Qué muestra:** por qué el sondeo de salud no basta. La etapa responde al sondeo mientras el pedido sigue quieto, y solo el plazo vencido lo delata. Después, el Reanudador reenvía solo esa etapa y la clave única impide una segunda factura. Si la etapa confirma justo cuando el Reanudador va a escalar, gana el primero que escribe la fila y el otro la encuentra cambiada. · **Decisión que refleja:** ADR-002 (estado por etapa), ADR-003 (una etapa a la vez), ADR-004 (plazo y barrido), ADR-005 (idempotencia) y ADR-006 (un reintento y la Bandeja). · **Qué no muestra:** el camino del sondeo que adelanta la señal cuando k sondeos seguidos no responden, ni el número k, que sigue sin fijar.

**La medida.** t_señal − t_stop ≤ plazo de la etapa + periodo del barrido. Con el plazo en 25 s y el barrido en 5 s (SUP-02, SUP-03), la señal cabe en los 30 s de ASR-3. El intento dura 3 s (SUP-04) y publicar el escalamiento toma milisegundos, así que los dos finales caben en los 5 s de ASR-4. Sumados dan los 35 s del presupuesto conjunto.

### Copia en Mermaid

```mermaid
---
title: "DG-SEQ-003 · ASR-3 y ASR-4: ¿cómo se señala en ≤ 30 s la etapa detenida y se reanuda o llega a una persona en ≤ 5 s?"
config:
  theme: default
  look: classic
---
%% id: DG-SEQ-003 | tipo: secuencia | asr: [ASR-3, ASR-4] | adr: [ADR-001, ADR-002, ADR-003, ADR-004, ADR-005, ADR-006] | estado: propuesta
%% copia del original en drawio/vista-concurrencia.drawio
sequenceDiagram
    autonumber
    participant CMT as ‖thread‖ ConsumidorMensajes
    participant EST as entity CadenaEtapa
    participant BRK as queue etapa.ejecutar · etapa.completada · cadena.escalada
    participant FAC as ‖process ×2‖ Facturación
    participant SON as ‖thread‖ SondeoSalud
    participant BAR as ‖thread‖ BarridoPlazos
    participant COL as queue Cola de reintentos
    participant RNA as ‖thread‖ Reanudador
    participant BES as ‖process‖ Bandeja de pedidos escalados
    CMT->>EST: marcarEnCurso(FACTURACION) · plazoEn = ahora + plazo
    CMT-)BRK: etapa.ejecutar(FACTURACION)
    BRK-)FAC: etapa.ejecutar(FACTURACION)
    Note over FAC: t_stop · la etapa sigue viva y el pedido no avanza
    loop cada 5 s, hasta que vence el plazo
        SON->>+FAC: salud()
        FAC-->>-SON: ok · el sondeo no ve el pedido quieto
        BAR->>+EST: vencidas(ahora) por IEstadoCadena · solo lee
        EST-->>-BAR: ahora ≥ plazoEn · idPedido, FACTURACION, intento 0
    end
    BAR-)COL: encolar(idPedido, FACTURACION) · t_señal
    COL-)+RNA: reanudar(idPedido, FACTURACION)
    RNA->>EST: update condicional EN_CURSO → EN_REINTENTO · plazoEn = ahora + 3 s
    RNA-)BRK: etapa.ejecutar(FACTURACION) solo esa etapa
    BRK-)FAC: etapa.ejecutar(FACTURACION)
    alt la etapa confirma en ≤ 3 s
        FAC->>FAC: insertar (idPedido, FACTURACION) · si ya existe, no emite otra factura
        FAC-)BRK: etapa.completada(FACTURACION)
        BRK-)CMT: etapa.completada(FACTURACION)
        CMT->>EST: update condicional EN_REINTENTO → COMPLETADA · sigue la etapa siguiente
    else sin confirmación a los 3 s
        RNA->>EST: update condicional EN_REINTENTO → ESCALADA (etapa y motivo)
        RNA-)BRK: cadena.escalada
        BRK-)BES: cadena.escalada con etapa y motivo
    end
    deactivate RNA
    opt el Reanudador no procesa el mensaje
        COL-)BES: mensaje fallido con el pedido señalado
    end
    Note over CMT,BES: ADR-004 · ADR-006 · 30 s + 5 s = 35 s · 0 duplicados
```
