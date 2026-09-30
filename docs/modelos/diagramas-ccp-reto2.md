---
title: Diagramas de arquitectura — Reto 2 CCP (v6)
---

# Diagramas de arquitectura — Reto 2 CCP (v6)

Versión 6 del 29 de septiembre de 2026. Dibuja las diez decisiones de [adrs-ccp-reto2.md](adrs-ccp-reto2.md) en cuatro vistas: componentes, concurrencia, información y despliegue. Tiene 40 diagramas. Uno muestra la arquitectura entera, y cada decisión y cada táctica tiene al menos un diagrama donde se abre el componente que la aloja: su caja blanca y la secuencia de su operación crítica.

Reemplaza la versión 5, que tenía 14 diagramas y abría solo cuatro componentes. Esta versión se hizo con la versión 1.2.0 de la skill `diagramar-uml-arquitectura`, que identifica cada táctica con el ID del catálogo del curso (DIS-17, SEG-13…) y exige que el precio de la táctica aparezca sobre el elemento que la aloja.

**Estado: propuesta.** Los diez ADR están en estado Propuesta, así que cada diagrama también lo está. Lo que aparece dibujado sin un ADR que lo respalde está marcado **propuesta** en el texto y listado en los huecos.

## Las cuatro vistas

| Vista | Qué responde | Diagramas | Página |
|---|---|---|---|
| **Componentes** | Qué componentes hay, por dónde se hablan y cómo funcionan por dentro los que sostienen cada ASR | 1 panorama · 3 de caja negra · 10 cajas blancas · 12 secuencias internas | [vista-componentes.md](vista-componentes.md) |
| **Concurrencia** | Qué corre al mismo tiempo, por qué colas pasa el trabajo, qué se sincroniza y cómo se cumple cada medida en el tiempo | 2 de objetos activos · 5 secuencias de punta a punta | [vista-concurrencia.md](vista-concurrencia.md) |
| **Información** | Qué datos sostienen cada táctica, quién es su dueño y por qué estados pasan | 3 de clases · 2 máquinas de estados | [vista-informacion.md](vista-informacion.md) |
| **Despliegue** | Dónde corre cada componente, con qué tecnología y qué queda como instancia única | 2 de despliegue | [vista-despliegue.md](vista-despliegue.md) |

Cada página se sostiene sola: trae su leyenda, su propósito y los enlaces a las demás. Los PNG de los 40 diagramas están en `png-v6/`.

## Dónde se abre cada decisión

La tabla dice, para cada ADR, en qué componente vive su táctica y qué diagramas la muestran por dentro. Las columnas N1 y N2 son la caja blanca y la secuencia interna de la [vista de componentes](vista-componentes.md).

| ADR | Tácticas (ID) | Componente que la aloja | N1 · caja blanca | N2 · por dentro | Otras vistas |
|---|---|---|---|---|---|
| ADR-001 · eventos, bróker durable y base transaccional | EST-03 · MOD-04 · DIS-17 | Todo el sistema · Inventario (la transacción local) | DG-CST-004 | DG-SEQ-004 | DG-CON-001 · DG-CON-002 · DG-DEP-001 · DG-DEP-002 |
| ADR-002 · Coordinador que orquesta con estado por etapa | INT-08 · DIS-15 | Coordinador de la cadena | DG-CST-008 | DG-SEQ-009 | DG-CON-002 · DG-CLS-001 · DG-STM-001 · DG-DEP-002 |
| ADR-003 · etapas consecutivas | INT-10 | Coordinador de la cadena | DG-CST-008 | DG-SEQ-009 | DG-SEQ-013 |
| ADR-004 · plazo vencido, barrido y sondeo | DIS-04 · DIS-03 · DIS-01 | Monitor de la cadena | DG-CST-009 | DG-SEQ-011 | DG-CON-002 · DG-SEQ-014 · DG-STM-001 · DG-DEP-002 |
| ADR-005 · idempotencia por pedido y etapa | DIS-17 | Facturación · Inventario | DG-CST-010 · DG-CST-004 | DG-SEQ-012 | DG-SEQ-015 · DG-CLS-001 |
| ADR-006 · un reintento y escalamiento | DIS-12 · DIS-14 | Coordinador de la cadena | DG-CST-008 | DG-SEQ-010 | DG-CON-002 · DG-SEQ-015 · DG-STM-001 |
| ADR-007 · huella del dispositivo verificada tras la sesión | SEG-02 · SEG-09 · SEG-15 | Gestor de sesión · Verificador de dispositivo · Notificador a seguridad | DG-CST-001 · DG-CST-002 · DG-CST-003 | DG-SEQ-001 · DG-SEQ-002 · DG-SEQ-003 | DG-CON-001 · DG-SEQ-016 · DG-CLS-003 |
| ADR-008 · detección por evento en la misma transacción | SEG-09 · SEG-18 · DIS-17 | Detector de escrituras indebidas · Inventario | DG-CST-005 · DG-CST-004 | DG-SEQ-006 · DG-SEQ-004 | DG-CON-001 · DG-SEQ-017 · DG-CLS-002 |
| ADR-009 · revocación en la puerta de entrada | SEG-02 · SEG-13 | Puerta de entrada de la API · Reacción | DG-CST-007 · DG-CST-006 | DG-SEQ-008 · DG-SEQ-007 | DG-CON-001 · DG-SEQ-017 · DG-STM-002 · DG-DEP-001 |
| ADR-010 · compensación dentro de una reacción ordenada | DIS-13 · SEG-13 · SEG-14 · SEG-15 | Reacción ante acceso indebido · Inventario · Gestor de sesión | DG-CST-006 · DG-CST-004 · DG-CST-001 | DG-SEQ-007 · DG-SEQ-005 | DG-SEQ-017 · DG-CLS-002 · DG-STM-002 |

### Los componentes que quedan como caja negra

| Componente | Por qué no se abre |
|---|---|
| App móvil | Calcula la huella, pero los identificadores del equipo que la forman no están definidos |
| Pedidos | Sigue la misma receta que Inventario: bitácora y outbox en la transacción, y anulación como compensación |
| Validación de despacho | Sigue la misma receta que Facturación, con la orden de despacho en lugar de la factura |
| Bandeja de pedidos escalados | Guarda el pedido escalado y se lo muestra a una persona; ninguna táctica vive dentro de ella |
| Lista de revocación · Bróker de mensajes · Base transaccional | Son productos comprados; su estructura se ve en el despliegue |
| Logística · Área de seguridad | Están fuera del alcance |

## Tácticas de los ADR con su ID del catálogo

Los ADR nombran sus tácticas sin el ID del catálogo del curso. La versión 1.2.0 de la skill exige el ID, así que esta tabla hace la traducción. La columna A2 de cada ADR puede copiarla tal cual.

| ADR | Táctica como la nombra el ADR | ID | Nombre en el catálogo | Nota |
|---|---|---|---|---|
| ADR-001 | Usar intermediarios (bróker de mensajes) | MOD-04 | Usar intermediarios | — |
| ADR-001 | Transacciones locales por servicio | DIS-17 | Transacciones | — |
| ADR-001 | (el estilo) | EST-03 | Dirigida por eventos | El ADR no cita el estilo; se añade porque es la decisión de estructura global |
| ADR-002 | Orquestación | INT-08 | Orquestación | — |
| ADR-002 | Log de transacciones (estado por pedido y etapa) | DIS-15 | Log de transacciones | — |
| ADR-003 | Protocolo de comportamiento (orden de las etapas) | INT-10 | Protocolo temporal y de comportamiento | El ADR la pone en la familia «cerrar distancia»; el catálogo la pone en «gestionar la interacción» |
| ADR-004 | Excepción / timeout (plazo vencido) | DIS-04 | Excepción / timeout | — |
| ADR-004 | Monitor | DIS-03 | Monitor | — |
| ADR-004 | Heartbeat (sondeo de salud, apoyo) | DIS-01 | Ping / echo | **Corrección.** En el heartbeat (DIS-02) el vigilado emite el latido. Aquí el Monitor pregunta, y eso es ping/echo |
| ADR-005 | Transacciones (idempotencia por clave única) | DIS-17 | Transacciones | — |
| ADR-006 | Reintento (un intento, sin espera creciente) | DIS-12 | Reintento | — |
| ADR-006 | Degradación con gracia (entrega a una persona) | DIS-14 | Degradación con gracia | — |
| ADR-007 | Identificar y autenticar actores (dispositivo incluido) | SEG-02 | Autenticar actores | — |
| ADR-007 | Detectar intrusiones | SEG-09 | Detectar intrusiones | — |
| ADR-007 | Informar | SEG-15 | Informar a los actores | — |
| ADR-008 | Detectar intrusiones (escritura contra permiso vigente) | SEG-09 | Detectar intrusiones | — |
| ADR-008 | Registro de auditoría | SEG-18 | Registro de auditoría | Cumplimiento parcial: ver huecos |
| ADR-009 | Revocar acceso | SEG-13 | Revocar el acceso | — |
| ADR-009 | Autenticar y autorizar en el borde | SEG-02 | Autenticar actores | La Puerta verifica el token; la autorización por permiso vigente la hace el Detector después |
| ADR-010 | Rollback por compensación | DIS-13 | Rollback | — |
| ADR-010 | Revocar, bloquear e informar (reacción ordenada) | SEG-13 · SEG-14 · SEG-15 | Revocar el acceso · Bloquear al actor · Informar a los actores | — |

## Piezas técnicas

Estos términos aparecen en las secuencias y en la vista de información.

| Término | Qué es |
|---|---|
| **Token · jti** | Token firmado que el Gestor de sesión entrega al abrir la sesión; jti es su identificador único. Revocar una sesión es anotar su jti en la Lista de revocación |
| **Huella del dispositivo** | Resumen de identificadores del equipo que la App móvil calcula al abrir sesión |
| **Outbox** | Tabla donde el servicio guarda el evento en la misma transacción que la escritura; un relevo lo publica después. Ninguna escritura queda sin evento |
| **Idempotencia** | Repetir la operación no produce un segundo efecto. Aquí la da una fila con clave única por (idPedido, etapa) |
| **Compensación** | Operación inversa que deshace el efecto de una escritura sin tocar lo que vino después |
| **Entrega al menos una vez** | El bróker reentrega todo mensaje que su consumidor no confirmó. No se pierde nada, pero un mensaje puede llegar dos veces |
| **Mensajes fallidos** | Destino al que la Cola de reintentos manda un mensaje que no se pudo procesar, en vez de perderlo. Aquí es la Bandeja de pedidos escalados |
| **Actualización condicional** | La fila cambia solo si sigue en el estado que el hilo espera. Resuelve la carrera entre dos hilos que escriben la misma fila |
| **t0 · t_det · t_stop · t_señal** | Apertura de la sesión (ASR-1), detección de la escritura indebida (ASR-2), instante en que la etapa deja de avanzar y instante de la señal (ASR-3). Desde ahí corren las medidas |
| **p99** | La duración que solo el 1 % de las ejecuciones supera |

## Validación

Las tres puertas de la skill se corrieron sobre los 40 diagramas.

| Vista | Diagramas | Sintaxis (mmdc 12.0.0) | Lint | Rúbrica | Lo que le resta puntos |
|---|---|---|---|---|---|
| Componentes | 26 | 26 compilan | 0 errores · 3 avisos justificados | 19/22 a 22/22 | El panorama tiene 19 elementos y aristas largas; se lee con el botón «Ampliar» |
| Concurrencia | 7 | 7 compilan | 0 errores · 1 aviso justificado | 18/20 a 20/20 | DG-CON-002 cruza dos aristas largas entre el Monitor y las etapas |
| Información | 5 | 5 compilan | 0 errores | 19/20 a 20/20 | Las regiones de DG-STM-002 no llevan nombre: Mermaid no lo permite |
| Despliegue | 2 | 2 compilan | 0 errores | 18/20 a 19/20 | Las rutas AMQP y JDBC convergen en el bróker y la base, y se cruzan antes de llegar |

Los cuatro avisos son de tamaño (AP-09), y cada página explica el suyo: el panorama (19 elementos), la caja blanca de Inventario (14), la caja negra de la cadena (13) y los hilos de la cadena (13).

El sitio publica los diagramas con Mermaid 11.4.1 (`docs/_config.yml`), y la validación local corrió con mmdc 12.0.0. Los diagramas usan el subconjunto que comparten las dos versiones y fijan en su cabecera el layout, el tema y el aspecto. El layout `elk` depende de un complemento de Mermaid; si el sitio no lo carga, el diagrama puede salir con otra disposición que la de los PNG. La verificación final es el render en GitHub Pages.

## Matriz ASR × ADR × diagrama

| ASR | ADR | Componentes | Eclosión (N1 · N2) | Concurrencia | Información y despliegue | Hueco |
|---|---|---|---|---|---|---|
| ASR-1 · suplantación del vendedor | ADR-001, ADR-007 | DG-CMP-001 · DG-CMP-002 | DG-CST-001 a 003 · DG-SEQ-001 a 003 | DG-CON-001 · DG-SEQ-016 | DG-CLS-003 · DG-DEP-001 | Identificadores de la huella; quién registra el cambio legítimo; canal del aviso; tendero sin señal (R-007a) |
| ASR-2 · escritura indebida | ADR-001, ADR-008, ADR-009, ADR-010 | DG-CMP-001 · DG-CMP-003 | DG-CST-004 a 007 · DG-SEQ-004 a 008 | DG-CON-001 · DG-SEQ-017 | DG-CLS-002 · DG-CLS-003 · DG-STM-002 · DG-DEP-001 | Lista de revocación caída (TO-009a); pedido indebido con la cadena en curso (R-010a); bitácora sin separar (SEG-18) |
| ASR-3 · cadena detenida | ADR-001 a ADR-004 | DG-CMP-001 · DG-CMP-004 | DG-CST-008 · DG-CST-009 · DG-SEQ-009 · DG-SEQ-011 | DG-CON-002 · DG-SEQ-013 · DG-SEQ-014 | DG-CLS-001 · DG-STM-001 · DG-DEP-002 | Plazo de cada etapa sin medir (TO-004a); Monitor como punto único (R-004a); dónde guarda sus señales |
| ASR-4 · reanudación sin duplicar | ADR-001 a ADR-006 | DG-CMP-001 · DG-CMP-004 | DG-CST-004 · DG-CST-008 · DG-CST-010 · DG-SEQ-010 · DG-SEQ-012 | DG-CON-002 · DG-SEQ-015 | DG-CLS-001 · DG-STM-001 · DG-DEP-002 | Confirmación que llega después de escalar; carga manual por transitorios (R-006a); factura en un sistema externo (NR-005a) |

## Huecos y ADR pendientes

Las preguntas abiertas no van dentro de los diagramas; están aquí.

**Decisiones que faltan (ADR pendientes).**

- **Sincronización de la fila `CadenaEtapa`.** Tres hilos la tocan: el que recibe la confirmación, el Reanudador y el barrido. DG-CON-002 dibuja una actualización condicional por estado, marcada propuesta. Ningún ADR la decide.
- **Confirmación que llega después de escalar.** Si la etapa confirma cuando la fila ya está Escalada, la actualización condicional la ignora, y el responsable recibe un pedido cuya etapa sí terminó. Hay que decidir si la fila pasa a Completada y el pedido sale de la Bandeja (DG-SEQ-009, DG-STM-001).
- **Qué hace la Puerta si la Lista de revocación no responde** (TO-009a): rechazar todo protege ASR-2 y deja el sistema sin servicio; dejar pasar hace lo contrario. DG-SEQ-008 no dibuja ese camino.
- **Separar la bitácora.** El registro de auditoría del catálogo (SEG-18) pide una traza fuera del alcance del atacante. Hoy la bitácora vive en la base del servicio que el actor escribió (DG-CLS-002).
- **Deduplicación del aviso.** El Notificador registra cada `idAlerta` para no avisar dos veces cuando el bróker repite la alerta (DG-CST-003). Es propuesta.

**Datos que faltan.**

- ¿Cuál es la duración p99 de cada etapa en operación normal? Sin ella no se fija el plazo de ADR-004. SUP-03 dice p99,9 y el glosario de la versión 5 decía p99; hay que fijar uno de los dos en el ADR.
- ¿Cuántos sondeos seguidos sin respuesta adelantan la señal de una etapa caída (el k de DG-SEQ-011 y DG-SEQ-014)?
- ¿Dónde guarda el Monitor sus señales? `RegistroSenales` existe en DG-CST-009, pero ningún conector de los ADR le da ruta a la base, y DG-DEP-002 no la dibuja.
- ¿Se corren dos instancias del Monitor con un candado en la base (R-004a)?
- ¿Qué identificadores expone el dispositivo suministrado, y quién registra un cambio legítimo de equipo por `IRegistroDispositivo`?
- ¿Por qué canal llega el aviso al área de seguridad?
- ¿Cómo se compensa un pedido indebido cuya cadena ya emitió factura o descargue (R-010a)?
- ¿Por qué protocolo recibe Logística el pedido listo?
- ¿Cuántos hilos consumidores necesita cada componente con la carga del Ambiente A?

**Dibujado sin ADR que lo respalde.** Las dos instancias de los servicios sin estado, la agrupación de componentes por nodo y la Bandeja junto al Coordinador (DG-DEP-001 y DG-DEP-002). También la actualización condicional y la deduplicación del aviso, listadas arriba.

## Líneas «Diagramas afectados» para las Consecuencias de cada ADR

Los ID del plan de diagramas de los ADR se conservan en DG-SEQ-013 a 017, DG-CLS-001, DG-CLS-002, DG-STM-001 y DG-STM-002. Cambian tres cosas. DG-CMP-001 es ahora el panorama; el antiguo DG-CMP-001 se partió en DG-CMP-002 (ASR-1) y DG-CMP-003 (ASR-2), y el antiguo DG-CMP-002 es DG-CMP-004. El único DG-DEP-001 se partió en DG-DEP-001 y DG-DEP-002.

- ADR-001 — `Diagramas afectados: DG-CMP-001 a 004, DG-CST-004, DG-SEQ-004, DG-CON-001, DG-CON-002, DG-DEP-001, DG-DEP-002`
- ADR-002 — `Diagramas afectados: DG-CMP-001, DG-CMP-004, DG-CST-008, DG-SEQ-009, DG-CON-002, DG-CLS-001, DG-STM-001, DG-DEP-002`
- ADR-003 — `Diagramas afectados: DG-CMP-004, DG-CST-008, DG-SEQ-009, DG-SEQ-013`
- ADR-004 — `Diagramas afectados: DG-CMP-004, DG-CST-009, DG-SEQ-011, DG-CON-002, DG-SEQ-014, DG-CLS-001, DG-STM-001, DG-DEP-002`
- ADR-005 — `Diagramas afectados: DG-CMP-004, DG-CST-004, DG-CST-010, DG-SEQ-012, DG-SEQ-015, DG-CLS-001`
- ADR-006 — `Diagramas afectados: DG-CMP-004, DG-CST-008, DG-SEQ-010, DG-CON-002, DG-SEQ-015, DG-STM-001, DG-DEP-002`
- ADR-007 — `Diagramas afectados: DG-CMP-002, DG-CST-001, DG-CST-002, DG-CST-003, DG-SEQ-001 a 003, DG-CON-001, DG-SEQ-016, DG-CLS-003`
- ADR-008 — `Diagramas afectados: DG-CMP-003, DG-CST-004, DG-CST-005, DG-SEQ-004, DG-SEQ-006, DG-CON-001, DG-SEQ-017, DG-CLS-002`
- ADR-009 — `Diagramas afectados: DG-CMP-003, DG-CST-006, DG-CST-007, DG-SEQ-007, DG-SEQ-008, DG-CON-001, DG-SEQ-017, DG-CLS-003, DG-STM-002, DG-DEP-001`
- ADR-010 — `Diagramas afectados: DG-CMP-003, DG-CST-001, DG-CST-004, DG-CST-006, DG-SEQ-005, DG-SEQ-007, DG-SEQ-017, DG-CLS-002, DG-CLS-003, DG-STM-002`

## Lucid

La copia en Lucid de la versión 5, [Reto 2 CCP v5 · Diagramas](https://lucid.app/lucidchart/2dcd45cd-d887-4194-a7a5-7648fdefc9fe/edit), quedó desactualizada con esta versión. La versión 6 todavía no tiene copia en Lucid. Cuando se genere, se deriva de estas páginas: un cambio se hace primero aquí y después se regenera Lucid.
