---
title: Diagramas de arquitectura — Reto 2 CCP (v7)
---

# Diagramas de arquitectura — Reto 2 CCP (v7)

Versión 7 del 3 de octubre de 2026. Dibuja las diez decisiones de [adrs-ccp-reto2.md](adrs-ccp-reto2.md) en cuatro vistas: componentes, concurrencia, información y despliegue. Tiene diez diagramas, entre uno y tres por vista, y cada ASR tiene un diagrama de estructura, uno de comportamiento con su medida y uno de datos.

**Fuente: draw.io.** Desde esta versión, el original de cada diagrama es un archivo draw.io por vista, en [drawio/](https://github.com/MATI-MBIT/arqsoft-reto-2/tree/main/docs/modelos/drawio). Los enlaces de la tabla los abren en draw.io web. Las imágenes de `png-v7/` se exportan de esos archivos, y el bloque Mermaid que acompaña cada imagen es una copia. Un cambio se hace primero en el draw.io, se exporta la imagen y después se copia al Mermaid.

**Estado: propuesta.** Los diez ADR están en estado Propuesta, así que cada diagrama también lo está. Lo que aparece dibujado sin un ADR que lo respalde está marcado **propuesta** en el texto y listado en los huecos.

## Las cuatro vistas

| Vista | Qué responde | Diagramas | Archivo draw.io | Página |
|---|---|---|---|---|
| **Componentes** | Qué componentes hay, por dónde se hablan y cómo funcionan por dentro los que sostienen cada ASR | DG-CMP-001 panorama · DG-CMP-002 seguridad · DG-CMP-003 cadena del pedido | [vista-componentes.drawio](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2FMATI-MBIT%2Farqsoft-reto-2%2Fmain%2Fdocs%2Fmodelos%2Fdrawio%2Fvista-componentes.drawio) | [vista-componentes.md](vista-componentes.md) |
| **Concurrencia** | Qué procesos e hilos ejecutan cada paso, qué estado comparten y cómo se cumple cada medida en el tiempo | DG-SEQ-001 ASR-1 · DG-SEQ-002 ASR-2 · DG-SEQ-003 ASR-3 y ASR-4 | [vista-concurrencia.drawio](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2FMATI-MBIT%2Farqsoft-reto-2%2Fmain%2Fdocs%2Fmodelos%2Fdrawio%2Fvista-concurrencia.drawio) | [vista-concurrencia.md](vista-concurrencia.md) |
| **Información** | Qué datos sostienen cada táctica, en qué base viven y por qué estados pasa la etapa | DG-CLS-001 cadena · DG-CLS-002 seguridad · DG-STM-001 estados de la etapa | [vista-informacion.drawio](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2FMATI-MBIT%2Farqsoft-reto-2%2Fmain%2Fdocs%2Fmodelos%2Fdrawio%2Fvista-informacion.drawio) | [vista-informacion.md](vista-informacion.md) |
| **Despliegue** | Dónde corre cada componente, con qué tecnología y qué queda como instancia única | DG-DEP-001 | [vista-despliegue.drawio](https://app.diagrams.net/#Uhttps%3A%2F%2Fraw.githubusercontent.com%2FMATI-MBIT%2Farqsoft-reto-2%2Fmain%2Fdocs%2Fmodelos%2Fdrawio%2Fvista-despliegue.drawio) | [vista-despliegue.md](vista-despliegue.md) |

Cada página se sostiene sola: trae su leyenda, su propósito y los enlaces a las demás.

## Qué cambió frente a la versión 6

La v6 tenía 40 diagramas: un panorama, tres cajas negras, diez cajas blancas con su secuencia interna, dos diagramas de hilos, cinco secuencias de punta a punta, cinco de información y dos de despliegue. La v7 los reduce a diez para que cada vista tenga entre uno y tres.

| Lo que tenía la v6 | Dónde queda en la v7 |
|---|---|
| Tres cajas negras por ASR (DG-CMP-002 a 004) | Dos diagramas por camino: DG-CMP-002 junta ASR-1 y ASR-2; DG-CMP-003 junta ASR-3 y ASR-4 |
| Diez cajas blancas (DG-CST-001 a 010) | Cuatro, abiertas dentro del diagrama de su camino: Verificador y Reacción en DG-CMP-002; Coordinador y Monitor en DG-CMP-003. Las otras seis quedan como caja negra |
| Doce secuencias internas (DG-SEQ-001 a 012) | Se pliegan en las tres secuencias de la vista de concurrencia, cuyas líneas de vida son las partes y los hilos |
| Dos diagramas de hilos (DG-CON-001 y 002) | Los procesos y los hilos son las líneas de vida de DG-SEQ-001 a 003; la sincronización va en la tabla bajo cada secuencia |
| La secuencia del orden de las etapas (DG-SEQ-013) | El orden queda en DG-CMP-003 (las entregas 1, 2 y 3) y en DG-STM-001 (Pendiente pasa a EnCurso cuando la anterior completa) |
| Tres diagramas de clases | Dos: la cadena (DG-CLS-001) y la seguridad (DG-CLS-002), que junta identidad, bitácora y reacción |
| Los estados de la sesión y del actor (DG-STM-002) | Atributos en DG-CLS-002 y orden en DG-SEQ-002 |
| Dos despliegues | Uno, con el bróker y la base como barras compartidas |

Los ID se renumeran: DG-CMP-001 sigue siendo el panorama, pero el resto de los números no coinciden con los de la v6. Las líneas «Diagramas afectados» del final traen los ID nuevos para cada ADR.

## Dónde se ve cada decisión

| ADR | Tácticas (ID) | Elemento que la aloja | Componentes | Concurrencia | Información y despliegue |
|---|---|---|---|---|---|
| ADR-001 · eventos, bróker durable y base transaccional | EST-03 · MOD-04 · DIS-17 | Todo el sistema | DG-CMP-001 a 003 | DG-SEQ-001 a 003 | DG-DEP-001 |
| ADR-002 · Coordinador que orquesta con estado por etapa | INT-08 · DIS-15 | OrquestadorCadena · RepositorioCadena | DG-CMP-001 · DG-CMP-003 | DG-SEQ-003 | DG-CLS-001 · DG-STM-001 · DG-DEP-001 |
| ADR-003 · etapas consecutivas | INT-10 | OrquestadorCadena | DG-CMP-001 · DG-CMP-003 | — | DG-STM-001 |
| ADR-004 · plazo vencido, barrido y sondeo | DIS-04 · DIS-03 · DIS-01 | BarridoPlazos · SondeoSalud | DG-CMP-001 · DG-CMP-003 | DG-SEQ-003 | DG-CLS-001 · DG-STM-001 · DG-DEP-001 |
| ADR-005 · idempotencia por pedido y etapa | DIS-17 | Facturación · Inventario · Validación de despacho | DG-CMP-001 · DG-CMP-003 | DG-SEQ-003 | DG-CLS-001 · DG-DEP-001 |
| ADR-006 · un reintento y escalamiento | DIS-12 · DIS-14 | Reanudador · Bandeja | DG-CMP-001 · DG-CMP-003 | DG-SEQ-003 | DG-STM-001 · DG-DEP-001 |
| ADR-007 · huella del dispositivo verificada tras la sesión | SEG-02 · SEG-09 · SEG-15 | Gestor de sesión · ComparadorHuella · Notificador | DG-CMP-001 · DG-CMP-002 | DG-SEQ-001 | DG-CLS-002 |
| ADR-008 · detección por evento en la misma transacción | SEG-09 · SEG-18 · DIS-17 | Detector · Pedidos · Inventario | DG-CMP-001 · DG-CMP-002 | DG-SEQ-002 | DG-CLS-002 · DG-DEP-001 |
| ADR-009 · revocación en la puerta de entrada | SEG-02 · SEG-13 | Puerta de entrada · Lista de revocación | DG-CMP-001 · DG-CMP-002 | DG-SEQ-002 | DG-CLS-002 · DG-DEP-001 |
| ADR-010 · compensación dentro de una reacción ordenada | DIS-13 · SEG-13 · SEG-14 · SEG-15 | OrquestadorReaccion · Pedidos · Inventario | DG-CMP-001 · DG-CMP-002 | DG-SEQ-002 | DG-CLS-002 |

### Los componentes que quedan como caja negra

| Componente | Por qué no se abre |
|---|---|
| Gestor de sesión · Detector de escrituras indebidas | Fijan t0 y t_det, pero su trabajo interno es una sola consulta; DG-SEQ-001 y DG-SEQ-002 lo muestran |
| Puerta de entrada · Notificador a seguridad | La consulta a la Lista y la entrega del aviso se ven completas en las secuencias |
| Facturación · Inventario · Validación de despacho | Siguen la misma receta de ADR-005, que se ve en DG-CLS-001 y DG-SEQ-003 |
| Pedidos | Sigue la misma receta que Inventario: bitácora y outbox en la transacción, y anulación como compensación |
| App móvil | Calcula la huella, pero los identificadores del equipo que la forman no están definidos |
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

Las tres puertas de la skill `diagramar-uml-arquitectura` 1.2.0 se corrieron sobre las copias Mermaid, y la revisión visual sobre las imágenes exportadas del draw.io.

| Vista | Diagramas | Sintaxis (mmdc 12.0.0) | Lint | Revisión visual del draw.io |
|---|---|---|---|---|
| Componentes | 3 | 3 compilan | 2 errores y 4 avisos, todos de tamaño o de eclosión | Sin solapes. DG-CMP-001 cruza dos aristas largas; DG-CMP-002 y DG-CMP-003 cruzan una cada uno |
| Concurrencia | 3 | 3 compilan | 0 errores | Sin solapes. Algunas etiquetas pasan sobre una barra de activación, con fondo blanco |
| Información | 3 | 3 compilan | 0 errores | Sin solapes |
| Despliegue | 1 | 1 compila | 0 errores | Sin solapes. Los cruces de rutas se marcan con un arco |

**Lo que el lint no acepta y por qué se deja.** DG-CMP-002 tiene 34 elementos y DG-CMP-003 tiene 38, y el lint bloquea desde 20 (AP-09). El lint también espera la caja blanca en un diagrama aparte con `refina:` (AP-20), y aquí va abierta dentro del diagrama del camino. Las dos cosas son el precio de dejar la vista de componentes en tres diagramas. La alternativa es volver a partir cada camino en caja negra, caja blanca y secuencia interna, como en la v6.

El sitio publica las copias Mermaid con Mermaid 11.4.1 (`docs/_config.yml`), y la validación local corrió con mmdc 12.0.0. El layout `elk` depende de un complemento de Mermaid; si el sitio no lo carga, la copia puede salir con otra disposición. La imagen que manda es la exportada del draw.io.

## Matriz ASR × ADR × diagrama

| ASR | ADR | Componentes | Concurrencia | Información y despliegue | Hueco |
|---|---|---|---|---|---|
| ASR-1 · suplantación del vendedor | ADR-001, ADR-007 | DG-CMP-001 · DG-CMP-002 | DG-SEQ-001 | DG-CLS-002 · DG-DEP-001 | Identificadores de la huella; quién registra el cambio legítimo; canal del aviso; tendero sin señal (R-007a) |
| ASR-2 · escritura indebida | ADR-001, ADR-008, ADR-009, ADR-010 | DG-CMP-001 · DG-CMP-002 | DG-SEQ-002 | DG-CLS-002 · DG-DEP-001 | Lista de revocación caída (TO-009a); pedido indebido con la cadena en curso (R-010a); bitácora sin separar (SEG-18) |
| ASR-3 · cadena detenida | ADR-001 a ADR-004 | DG-CMP-001 · DG-CMP-003 | DG-SEQ-003 | DG-CLS-001 · DG-STM-001 · DG-DEP-001 | Plazo de cada etapa sin medir (TO-004a); Monitor como punto único (R-004a); dónde guarda sus señales |
| ASR-4 · reanudación sin duplicar | ADR-001 a ADR-006 | DG-CMP-001 · DG-CMP-003 | DG-SEQ-003 | DG-CLS-001 · DG-STM-001 · DG-DEP-001 | Confirmación que llega después de escalar; carga manual por transitorios (R-006a); factura en un sistema externo (NR-005a) |

## Huecos y ADR pendientes

Las preguntas abiertas no van dentro de los diagramas; están aquí.

**Decisiones que faltan (ADR pendientes).**

- **Sincronización de la fila `CadenaEtapa`.** Tres hilos la tocan: ConsumidorMensajes, Reanudador y BarridoPlazos. DG-SEQ-003 dibuja una actualización condicional por estado, marcada propuesta. Ningún ADR la decide.
- **Confirmación que llega después de escalar.** Si la etapa confirma cuando la fila ya está Escalada, la actualización condicional la ignora, y el responsable recibe un pedido cuya etapa sí terminó. Hay que decidir si la fila pasa a Completada y el pedido sale de la Bandeja (DG-SEQ-003, DG-STM-001).
- **Qué hace la Puerta si la Lista de revocación no responde** (TO-009a): rechazar todo protege ASR-2 y deja el sistema sin servicio; dejar pasar hace lo contrario. DG-SEQ-002 no dibuja ese camino.
- **Separar la bitácora.** El registro de auditoría del catálogo (SEG-18) pide una traza fuera del alcance del atacante. Hoy la bitácora vive en la base del servicio que el actor escribió (DG-CLS-002).
- **Deduplicación del aviso.** El Notificador registra cada `idAlerta` para no avisar dos veces cuando el bróker repite la alerta (DG-SEQ-001). Es propuesta.
- **Estructura interna del Coordinador.** DG-CMP-003 le da dos puertos de entrada, uno para `etapa.completada` y otro para la Cola de reintentos, que entrega directo al Reanudador. Es propuesta.

**Datos que faltan.**

- ¿Cuál es la duración p99 de cada etapa en operación normal? Sin ella no se fija el plazo de ADR-004. SUP-03 dice p99,9 y el glosario de los diagramas dice p99; hay que fijar uno de los dos en el ADR.
- ¿Cuántos sondeos seguidos sin respuesta adelantan la señal de una etapa caída (el k del SondeoSalud)?
- ¿Dónde guarda el Monitor sus señales? DG-CLS-001 dibuja una base del Monitor, pero ningún conector de los ADR le da ruta, y DG-DEP-001 no la dibuja.
- ¿Se corren dos instancias del Monitor con un candado en la base (R-004a)?
- ¿Qué identificadores expone el dispositivo suministrado, y quién registra un cambio legítimo de equipo por `IRegistroDispositivo`?
- ¿Por qué canal llega el aviso al área de seguridad?
- ¿Cómo se compensa un pedido indebido cuya cadena ya emitió factura o descargue (R-010a)?
- ¿Por qué protocolo recibe Logística el pedido listo?
- ¿Cuántos hilos consumidores necesita cada componente con la carga del Ambiente A?

**Dibujado sin ADR que lo respalde.** Las dos instancias de los servicios sin estado y la agrupación de componentes por nodo (DG-DEP-001), la Bandeja junto al Coordinador, la actualización condicional, la deduplicación del aviso y los dos puertos de entrada del Coordinador.

## Líneas «Diagramas afectados» para las Consecuencias de cada ADR

Los ADR citan los ID de su plan de diagramas (sección 6 de [adrs-ccp-reto2.md](adrs-ccp-reto2.md)), que no coinciden con los de la v7. Estas líneas los reemplazan.

- ADR-001 — `Diagramas afectados: DG-CMP-001 a 003, DG-SEQ-001 a 003, DG-DEP-001`
- ADR-002 — `Diagramas afectados: DG-CMP-001, DG-CMP-003, DG-SEQ-003, DG-CLS-001, DG-STM-001, DG-DEP-001`
- ADR-003 — `Diagramas afectados: DG-CMP-001, DG-CMP-003, DG-STM-001`
- ADR-004 — `Diagramas afectados: DG-CMP-001, DG-CMP-003, DG-SEQ-003, DG-CLS-001, DG-STM-001, DG-DEP-001`
- ADR-005 — `Diagramas afectados: DG-CMP-001, DG-CMP-003, DG-SEQ-003, DG-CLS-001, DG-DEP-001`
- ADR-006 — `Diagramas afectados: DG-CMP-001, DG-CMP-003, DG-SEQ-003, DG-STM-001, DG-DEP-001`
- ADR-007 — `Diagramas afectados: DG-CMP-001, DG-CMP-002, DG-SEQ-001, DG-CLS-002`
- ADR-008 — `Diagramas afectados: DG-CMP-001, DG-CMP-002, DG-SEQ-002, DG-CLS-002, DG-DEP-001`
- ADR-009 — `Diagramas afectados: DG-CMP-001, DG-CMP-002, DG-SEQ-002, DG-CLS-002, DG-DEP-001`
- ADR-010 — `Diagramas afectados: DG-CMP-001, DG-CMP-002, DG-SEQ-002, DG-CLS-002`

## Lucid

La copia en Lucid de la versión 5, [Reto 2 CCP v5 · Diagramas](https://lucid.app/lucidchart/2dcd45cd-d887-4194-a7a5-7648fdefc9fe/edit), quedó desactualizada desde la versión 6. Con la v7, el formato editable es draw.io, así que no se planea una copia nueva en Lucid.
