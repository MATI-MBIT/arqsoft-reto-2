---
contrato: adr-log/v1
sistema: CCP — Reto 2
fecha: 2026-09-26
alcance_atributos: [disponibilidad, seguridad]
---
# ADRs — CCP, Reto 2

Diez decisiones de arquitectura para los cuatro escenarios de calidad del reto 2: dos de seguridad (ASR-1, ASR-2) y dos de disponibilidad (ASR-3, ASR-4). Todas están en estado **Propuesta**: solo el equipo las pasa a Aceptada. Los productos concretos (Java, Spring, PostgreSQL, RabbitMQ, Redis) y los números de configuración no vienen del enunciado; van marcados `[SUPUESTO]` y tienen su fila en §1.3.

## 0. Índice

| ADR | Título | Estado | Confianza | Iteración | ASRs | Diagramas |
|---|---|---|---|---|---|---|
| ADR-001 | Servicios que se comunican por eventos a través de un bróker durable, con el estado en una base transaccional | Propuesta | Media | 1 | ASR-1, ASR-2, ASR-3, ASR-4 | DG-CMP-001, DG-CMP-002, DG-DEP-001 |
| ADR-002 | Coordinador de la cadena que orquesta las etapas y guarda el estado de cada pedido por etapa | Propuesta | Alta | 2 | ASR-3, ASR-4 | DG-CMP-002, DG-STM-001, DG-CLS-001 |
| ADR-003 | Etapas consecutivas en el orden facturación, descargue de inventario y validación de despacho | Propuesta | Media | 2 | ASR-3, ASR-4 | DG-SEQ-013 |
| ADR-004 | Plazo vencido por pedido y etapa, encontrado por un barrido periódico, con sondeo de salud como apoyo | Propuesta | Baja | 2 | ASR-3 | DG-CMP-002, DG-SEQ-014, DG-STM-001, DG-DEP-001 |
| ADR-005 | Idempotencia por pedido y etapa con clave única en la misma transacción del efecto | Propuesta | Alta | 2 | ASR-4 | DG-SEQ-015, DG-CLS-001 |
| ADR-006 | Un solo intento de reanudación de la etapa pendiente y escalamiento a una persona | Propuesta | Media | 2 | ASR-4 | DG-CMP-002, DG-SEQ-015, DG-STM-001 |
| ADR-007 | Huella del dispositivo como parte de la identidad del vendedor, verificada después de abrir la sesión | Propuesta | Media | 3 | ASR-1 | DG-CMP-001, DG-SEQ-016 |
| ADR-008 | Detección de la escritura indebida por un evento que sale en la misma transacción de la escritura | Propuesta | Media | 3 | ASR-2 | DG-CMP-001, DG-SEQ-017 |
| ADR-009 | Revocación de la sesión en la puerta de entrada, con una lista de revocación consultada en cada petición | Propuesta | Media | 3 | ASR-2 | DG-CMP-001, DG-SEQ-017, DG-STM-002, DG-DEP-001 |
| ADR-010 | Reversión de la escritura indebida por compensación, dentro de una reacción ordenada de menor a mayor costo | Propuesta | Media | 3 | ASR-2 | DG-SEQ-017, DG-CLS-002 |

## 1. Insumos
### 1.1 Contexto
CCP es una comercializadora de productos de consumo masivo que opera en cinco países, con unas treinta bodegas grandes. El sistema nuevo es greenfield y opera 7x24x365.
Funcionales primarios: el vendedor consulta inventario exacto y toma pedidos en la tienda; el tendero pide por su cuenta; cada pedido confirmado recorre facturación, descargue de inventario y validación de despacho antes de pasar a logística.
Actores: vendedor (con dispositivo suministrado por CCP), tendero (con dispositivo propio), área de seguridad, responsable del pedido escalado. Sistema externo: logística.
Restricciones clave: sin ventana de mantenimiento (R-1), dispositivo suministrado al vendedor (R-2), inventario exacto en tiempo real (R-4), implementar y medir, no solo diseñar (R-12).
Las dos exigencias comparten un rasgo: la falla no se anuncia. El atacante entra con credenciales correctas, y la etapa detenida no señala error.

### 1.2 ASRs

| ASR | Atributo | Fuente | Estímulo | Artefacto | Ambiente | Respuesta | Medida | Prioridad | Impacto |
|---|---|---|---|---|---|---|---|---|---|
| ASR-1 | Seguridad | Tercero con las credenciales correctas de un vendedor y un dispositivo distinto al suministrado | Abre sesión con éxito y empieza a operar; arribo esporádico | La sesión del vendedor y el dispositivo suministrado como parte de su identidad | A: operación normal, carga `[PREGUNTA]`, sin fallas | Marca la sesión como abierta desde un dispositivo no reconocido y avisa al área de seguridad con vendedor, dispositivo y hora | Aviso en ≤ 2 s desde la apertura de la sesión, con ≤ 1 falsa alarma por cada 100 cambios legítimos de dispositivo (supuesto de la ficha), en Ambiente A | Alta | Medio |
| ASR-2 | Seguridad | El mecanismo de detección de accesos indebidos, a partir de una escritura ya ejecutada | Un actor autenticado con permiso solo de consulta registró o modificó un pedido, o descargó inventario, con la sesión aún abierta | El registro del pedido, el descargue de inventario y la sesión del actor | A | Bloquea al actor, cierra su sesión, revierte la escritura y avisa a seguridad | Bloqueo, cierre y reversión en ≤ 5 s desde la detección; escrituras posteriores del actor = 0; efecto residual 60 s después = 0, en Ambiente A | Alta | Medio |
| ASR-3 | Disponibilidad | La cadena de tres etapas que sigue al pedido | Una etapa no responde ni señala error y el pedido espera sin pasar a logística | Facturación, descargue de inventario y validación de despacho | A | Identifica el pedido detenido, la etapa y el tiempo transcurrido, y lo señala como fallo de la cadena | Señal en ≤ 30 s desde que la etapa dejó de avanzar, con ≤ 1 falsa alarma por hora, en Ambiente A | Alta | Alto |
| ASR-4 | Disponibilidad | La recuperación, a partir de la señal de ASR-3 | Pedido señalado como detenido, con una o dos etapas completadas y una pendiente | La cadena del pedido y sus efectos ya producidos | A | Reanuda desde la etapa que falló sin repetir las completadas; si ese intento no completa, entrega el pedido a una persona con el estado exacto | Reanudada o entregada a una persona en ≤ 5 s desde la señal; duplicados de factura, descargue u orden de despacho = 0; pedidos sin destino = 0, en Ambiente A | Alta | Alto |

Presupuesto conjunto: ASR-3 + ASR-4 suman 35 s entre que la cadena se detiene y queda reanudada o en manos de una persona.

### 1.3 Restricciones, concerns y supuestos

| ID | Tipo | Descripción | Origen |
|---|---|---|---|
| R-1 | restricción | Operación 7x24x365; no hay ventana de mantenimiento ni noche común a los cinco países | enunciado |
| R-2 | restricción | CCP le suministra el dispositivo móvil a cada vendedor | enunciado |
| R-4 | restricción | La consulta de inventario entrega la cifra exacta del momento | enunciado |
| R-5 | restricción | Al formalizar un pedido, las cantidades quedan reservadas | enunciado |
| R-7 | restricción | La información de cada tendero solo la conoce quien está autorizado | enunciado |
| R-9 | restricción | La suplantación de vendedores y tenderos no puede permitirse | enunciado |
| R-11 | restricción | El vendedor opera un dispositivo suministrado; el tendero, el suyo | enunciado |
| R-12 | restricción | Hay que implementar las decisiones y medir que los ASR se cumplen | enunciado |
| S-1 | supuesto | El proceso espera a que las tres etapas terminen antes de continuar | usuario |
| S-2 | supuesto | El cierre de las tres etapas habilita a logística | usuario |
| S-3 | supuesto | El alcance cubre solo fallas de software; las de infraestructura quedan fuera | usuario |
| C-01 | concern | El diagrama BPMN del proceso de ventas mezcla hipótesis de solución (heartbeat, cola de dos reintentos, réplica de lectura, JDBC, gestor de sesión, logs) con hechos del negocio; ninguna de esas hipótesis es restricción | usuario (constraints.md) |
| C-02 | concern | Cada condición que el diseño se imponga necesita un experimento que la produzca (consecuencia de R-12) | usuario (constraints.md) |
| C-03 | concern | El tiempo que el tendero espera antes de ver su pedido en preparación acota todo lo que la cadena tarda; hoy es `[PREGUNTA]` | usuario (architecture.md) |
| SUP-01 | supuesto | Pila: Java 21 y Spring Boot 3, PostgreSQL por JDBC, RabbitMQ como bróker y Redis para la lista de revocación. El único indicio en los insumos es el acceso por JDBC del BPMN | [SUPUESTO] (propuesta de DG-CMP v3) |
| SUP-02 | supuesto | El barrido de plazos corre cada 5 s | [SUPUESTO] |
| SUP-03 | supuesto | El plazo de cada etapa es ≤ 25 s y mayor que la duración p99,9 de esa etapa en operación normal (el valor que solo el 0,1 % de las ejecuciones supera) | [SUPUESTO] |
| SUP-04 | supuesto | El intento de reanudación se da por fallido si la etapa no confirma en 3 s | [SUPUESTO] |
| SUP-05 | supuesto | El token de sesión vive 15 min | [SUPUESTO] |
| SUP-06 | supuesto | La validación de despacho necesita la factura emitida y el inventario descargado, en el orden que usan el glosario y la página de stakeholders | [SUPUESTO] |

## 2. Catálogo de elementos

| EL | Nombre | Tipo UML | Estereotipo | Responsabilidad | Estado que posee | Eclosión | Introducido por |
|---|---|---|---|---|---|---|---|
| EL-01 | Vendedor | actor | «external» | Abre sesión desde el dispositivo suministrado, consulta y crea pedidos | ninguno | exento («external») | contexto |
| EL-02 | Tendero | actor | «external» | Crea pedidos por su cuenta desde su dispositivo | ninguno | exento («external») | contexto |
| EL-03 | App móvil | component | «component» | Cara visible para vendedor y tendero; calcula la huella del dispositivo | token de sesión en el dispositivo | obligatoria (diferida en DG-CMP v3) | contexto, ADR-007 |
| EL-04 | Puerta de entrada de la API | component | «component» «tactic:autorizar-en-borde» | Recibe toda petición, verifica el token y consulta la lista de revocación | ninguno (stateless) | obligatoria | ADR-009 |
| EL-05 | Gestor de sesión | component | «component» | Autentica, emite tokens, bloquea actores y responde los permisos vigentes | usuarios, permisos, sesiones, actores bloqueados | obligatoria | ADR-001, ADR-007, ADR-009 |
| EL-06 | Verificador de dispositivo | component | «component» «tactic:detectar-intrusiones» | Compara la huella de cada sesión de vendedor con la registrada y avisa si no coincide | dispositivos registrados por vendedor | obligatoria | ADR-007 |
| EL-07 | Pedidos | component | «component» | Registra pedidos y los compensa si la escritura fue indebida | pedidos, bitácora y outbox propios | obligatoria | ADR-001, ADR-008, ADR-010 |
| EL-08 | Inventario | component | «component» | Existencias exactas, reservas, descargue idempotente y su compensación | existencias, reservas, etapas procesadas | obligatoria | ADR-001, ADR-005, ADR-008, ADR-010 |
| EL-09 | Bitácora de escrituras | datastore | «database» «tactic:bitacora-escrituras» | Guarda cada escritura con actor, permiso usado y estado anterior, en la misma transacción | escrituras con su estado anterior | exento (tabla dentro de EL-07 y EL-08) | ADR-008 |
| EL-10 | Detector de escrituras indebidas | component | «component» «tactic:detectar-escritura» | Contrasta cada escritura publicada con los permisos vigentes del actor | ninguno (stateless) | obligatoria | ADR-008 |
| EL-11 | Reacción ante acceso indebido | component | «component» «tactic:compensacion» | Revoca, bloquea, compensa y avisa, en ese orden, dentro de 5 s | reacciones con sus marcas de tiempo | obligatoria | ADR-009, ADR-010 |
| EL-12 | Lista de revocación | datastore | «COTS» | Guarda sesiones y actores revocados mientras viva su token | claves de revocación con vencimiento | exento («COTS») | ADR-009 |
| EL-13 | Notificador a seguridad | component | «component» «tactic:informar» | Entrega al área de seguridad los avisos de ASR-1 y ASR-2 | avisos entregados | obligatoria | ADR-007 |
| EL-14 | Área de seguridad | actor | «external» | Recibe los avisos y decide qué hacer con ellos | ninguno | exento («external») | contexto |
| EL-15 | Bróker de mensajes | queue | «queue» «COTS» | Transporta eventos y comandos de forma durable entre componentes | mensajes pendientes de consumo | exento («COTS») | ADR-001 |
| EL-16 | Coordinador de la cadena | component | «component» «tactic:orquestacion» | Lleva cada pedido por sus tres etapas en orden y reanuda la pendiente una vez | estado por pedido y etapa | obligatoria | ADR-002, ADR-003, ADR-006 |
| EL-17 | Monitor de la cadena | component | «component» «tactic:monitor» | Barre los plazos vencidos, sondea la salud de las etapas y señala cada pedido detenido una sola vez | señales emitidas | obligatoria | ADR-004 |
| EL-18 | Facturación | component | «component» «tactic:idempotencia» | Emite la factura o el documento de cobro diferido, una sola vez por pedido | facturas, etapas procesadas | obligatoria | ADR-005 |
| EL-19 | Validación de despacho | component | «component» «tactic:idempotencia» | Valida el pedido y emite la orden de despacho, una sola vez por pedido | órdenes de despacho, etapas procesadas | obligatoria | ADR-005 |
| EL-20 | Bandeja de pedidos escalados | component | «component» | Guarda el pedido escalado con su etapa pendiente y su motivo, y se lo muestra a una persona | pedidos escalados | obligatoria (diferida en DG-CMP v3) | ADR-006 |
| EL-21 | Responsable del pedido escalado | actor | «external» | Termina o cancela a mano el pedido escalado | ninguno | exento («external») | contexto |
| EL-22 | Logística | component | «external» | Recibe el pedido con las tres etapas cerradas | fuera del alcance | exento («external») | contexto |
| EL-23 | Base transaccional | datastore | «database» «COTS» | Persiste pedidos, inventario, bitácora y estado de la cadena con transacciones locales | todo el estado durable | exento («COTS») | ADR-001 |
| EL-24 | Cola de reintentos | queue | «queue» «COTS» | Lleva al Coordinador el pedido señalado; su destino de mensajes fallidos es la Bandeja | pedidos señalados pendientes | exento («COTS») | ADR-006 |

## 3. Catálogo de conectores

| CN | Desde | Hacia | Tipo | Protocolo o estereotipo | Introducido por |
|---|---|---|---|---|---|
| CN-01 | EL-01 | EL-03 | síncrono | interacción de usuario | contexto |
| CN-02 | EL-02 | EL-03 | síncrono | interacción de usuario | contexto |
| CN-03 | EL-03 | EL-04 | síncrono | «HTTPS» con token y huella | ADR-009 |
| CN-04 | EL-04 | EL-05 | síncrono | «HTTPS» abrir sesión | ADR-009 |
| CN-05 | EL-04 | EL-12 | síncrono | «consulta» ¿sesión o actor revocado? en cada petición | ADR-009 |
| CN-06 | EL-04 | EL-07 | síncrono | «HTTPS» crear pedido | ADR-009 |
| CN-07 | EL-04 | EL-08 | síncrono | «HTTPS» consultar y descargar | ADR-009 |
| CN-08 | EL-05 | EL-15 | asíncrono | «pub/sub» sesion.abierta | ADR-007 |
| CN-09 | EL-15 | EL-06 | asíncrono | «pub/sub» sesion.abierta | ADR-007 |
| CN-10 | EL-06 | EL-15 | asíncrono | «pub/sub» alerta.seguridad | ADR-007 |
| CN-11 | EL-15 | EL-13 | asíncrono | «pub/sub» alerta.seguridad | ADR-007 |
| CN-12 | EL-13 | EL-14 | asíncrono | canal del aviso `[PREGUNTA]` | ADR-007 |
| CN-13 | EL-07 | EL-09 | síncrono | «JDBC» misma transacción que la escritura | ADR-008 |
| CN-14 | EL-08 | EL-09 | síncrono | «JDBC» misma transacción que la escritura | ADR-008 |
| CN-15 | EL-07 | EL-15 | asíncrono | «outbox» escritura.realizada tras el commit | ADR-008 |
| CN-16 | EL-08 | EL-15 | asíncrono | «outbox» escritura.realizada tras el commit | ADR-008 |
| CN-17 | EL-15 | EL-10 | asíncrono | «pub/sub» escritura.realizada | ADR-008 |
| CN-18 | EL-10 | EL-05 | síncrono | «HTTPS» permisosVigentes(actor) | ADR-008 |
| CN-19 | EL-10 | EL-11 | síncrono | «HTTPS» reaccionar(escritura) | ADR-008 |
| CN-20 | EL-11 | EL-12 | síncrono | «escritura» revocar sesión y actor | ADR-009 |
| CN-21 | EL-11 | EL-05 | síncrono | «HTTPS» bloquear(actor) | ADR-010 |
| CN-22 | EL-11 | EL-07 | síncrono | «HTTPS» compensar(idEscritura) | ADR-010 |
| CN-23 | EL-11 | EL-08 | síncrono | «HTTPS» compensar(idEscritura) | ADR-010 |
| CN-24 | EL-11 | EL-15 | asíncrono | «pub/sub» alerta.seguridad | ADR-010 |
| CN-25 | EL-07 | EL-16 | síncrono | «HTTPS» iniciar(idPedido) | ADR-002 |
| CN-26 | EL-16 | EL-15 | asíncrono | «comando» etapa.ejecutar, una etapa a la vez | ADR-002, ADR-003 |
| CN-27 | EL-15 | EL-18 | asíncrono | «comando» etapa.ejecutar | ADR-002 |
| CN-28 | EL-15 | EL-08 | asíncrono | «comando» etapa.ejecutar | ADR-002 |
| CN-29 | EL-15 | EL-19 | asíncrono | «comando» etapa.ejecutar | ADR-002 |
| CN-30 | EL-18 | EL-15 | asíncrono | «pub/sub» etapa.completada | ADR-002 |
| CN-31 | EL-19 | EL-15 | asíncrono | «pub/sub» etapa.completada | ADR-002 |
| CN-32 | EL-15 | EL-16 | asíncrono | «pub/sub» etapa.completada | ADR-002 |
| CN-33 | EL-17 | EL-16 | síncrono | «HTTPS» vencidas(ahora), cada 5 s [SUPUESTO] | ADR-004 |
| CN-34 | EL-17 | EL-18 | síncrono | «heartbeat» sondeo de salud cada 5 s [SUPUESTO] | ADR-004 |
| CN-35 | EL-17 | EL-19 | síncrono | «heartbeat» sondeo de salud cada 5 s [SUPUESTO] | ADR-004 |
| CN-36 | EL-17 | EL-24 | asíncrono | «encolar» pedido señalado | ADR-006 |
| CN-37 | EL-24 | EL-16 | asíncrono | «desencolar» reanudar(idPedido, etapa) | ADR-006 |
| CN-38 | EL-16 | EL-20 | asíncrono | «pub/sub» cadena.escalada | ADR-006 |
| CN-39 | EL-20 | EL-21 | síncrono | consulta de la bandeja | ADR-006 |
| CN-40 | EL-16 | EL-22 | asíncrono | «pub/sub» pedido.listo | ADR-002 |
| CN-41 | EL-16 | EL-23 | síncrono | «JDBC» estado por pedido y etapa | ADR-002 |
| CN-42 | EL-08 | EL-23 | síncrono | «JDBC» existencias y etapa procesada en la misma transacción | ADR-001, ADR-005 |
| CN-43 | EL-18 | EL-23 | síncrono | «JDBC» factura y etapa procesada en la misma transacción | ADR-005 |

## 4. ADRs

### ADR-001: Servicios que se comunican por eventos a través de un bróker durable, con el estado en una base transaccional

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 1 · **Confianza:** Media — el estilo es conocido, pero la pila concreta es un supuesto (SUP-01) y la carga está sin cifrar

#### Contexto
Los cuatro ASR piden reaccionar a algo que ocurrió en otro componente, sin frenar la operación que lo produjo. ASR-1 exige avisar en ≤ 2 s desde la apertura de una sesión, y ASR-2 exige reaccionar en ≤ 5 s a una escritura ya ejecutada. ASR-3 exige notar en ≤ 30 s una etapa que dejó de avanzar sin error, y ASR-4 exige reanudarla en ≤ 5 s sin duplicar efectos.

El BPMN dibuja un proceso síncrono de punta a punta (C-01), y S-1 dice que el proceso espera a las tres etapas. R-1 descarta cualquier revisión por lotes. R-4 exige inventario exacto, así que el dato no puede vivir en copias atrasadas. R-12 obliga a construir y medir lo que se decida.

¿Qué estructura global deja que cada control observe lo que pasó en otro componente sin ponerse en su camino?

#### Decisión
Construiremos el sistema como servicios que se comunican por eventos a través de un bróker de mensajes durable. El bróker es un intermediario que guarda cada mensaje hasta que su consumidor lo procesa. Cada servicio guardará su estado en una base transaccional con transacciones locales. Adoptamos este estilo porque es el único de los evaluados que cumple tres cosas a la vez. Verifica la sesión fuera del inicio de sesión (ASR-1), captura cada escritura sin frenarla (ASR-2) y conserva el trabajo pendiente de una etapa caída (ASR-3, ASR-4).

#### Consecuencias
- (+) ASR-1 y ASR-2: el Verificador y el Detector consumen eventos; el inicio de sesión y la escritura no esperan su veredicto.
- (+) ASR-3 y ASR-4: si una etapa cae, su comando espera en el bróker y el estado del pedido queda en la base.
- (+) R-4: el inventario se lee y se escribe en la misma base transaccional, sin réplica atrasada.
- (−) Latencia: cada evento suma un salto por el bróker, y ese salto consume parte de los 2 s de ASR-1 y de los 5 s de ASR-2.
- (−) Operación: el bróker es una pieza más que vigilar, y si cae detiene los cuatro caminos a la vez (R-001a).
- (−) Desarrollo: un evento publicado sin su escritura, o al revés, rompe ASR-2; la decisión obliga a un patrón de publicación transaccional (ADR-008).
- (±) La pila concreta (SUP-01) queda como supuesto hasta que el equipo la confirme.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de un sistema greenfield que opera 7x24x365, frente a ASR-1, ASR-2, ASR-3 y ASR-4, decidimos servicios comunicados por eventos a través de un bróker durable y descartamos el monolito síncrono y los servicios con llamadas síncronas para lograr que cada control observe sin frenar la operación, aceptando un salto más por evento y el bróker como pieza común.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-1 | Seguridad | Aviso ≤ 2 s | contribuye | primario |
| ASR-2 | Seguridad | Reacción ≤ 5 s desde la detección | contribuye | primario |
| ASR-3 | Disponibilidad | Señal ≤ 30 s | contribuye | primario |
| ASR-4 | Disponibilidad | Reanudación ≤ 5 s, 0 duplicados | contribuye | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Usar intermediarios (bróker de mensajes) | Modificabilidad · reducir acoplamiento, al servicio de disponibilidad | EL-15 | «tactic:intermediario-mensajes» |
| Transacciones (locales por servicio) | Disponibilidad · prevenir | EL-23 | «tactic:transaccion-local» |

**A3. Alternativas**
Drivers: ASR-1 (Alta), ASR-2 (Alta), ASR-3 (Alta), ASR-4 (Alta), R-1, R-4, R-12 — fijados antes de evaluar.

| Criterio | Opción A: Servicios con eventos y bróker durable (elegida) | Opción B: Monolito modular síncrono, como el BPMN | Opción C: Servicios con llamadas síncronas REST |
|---|---|---|---|
| ASR-1 aviso ≤ 2 s | + verificación fuera del login | − la verificación va dentro del login o en un hilo que muere con él | − la verificación bloquea el login |
| ASR-2 reacción ≤ 5 s | + toda escritura publica un evento | + la escritura se ve en proceso, pero el control frena cada escritura | − cada escritura llama al detector antes de responder |
| ASR-3 señal ≤ 30 s | + estado del pedido en la base, observable desde afuera | − el pedido detenido es un hilo bloqueado, invisible desde afuera | − la llamada colgada solo se ve en el llamador |
| ASR-4 reanudación ≤ 5 s | + el comando pendiente sobrevive en el bróker | − la reanudación exige reconstruir el hilo perdido | − sin memoria de la llamada perdida |
| R-4 inventario exacto | + base transaccional sin réplicas | ++ una sola transacción local | + base transaccional |
| R-12 implementar y medir | − más piezas que montar | ++ un solo desplegable | + piezas conocidas |
Descartes: B — gana en simplicidad, pero una etapa detenida queda como un hilo bloqueado que nada observa, y eso deja sin punto de medida a ASR-3. C — acopla en el tiempo cada control al camino que vigila, y la falla de un servicio se propaga al que lo llama.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| TO-001a | Trade-off | El bróker entre componentes: disponibilidad ▲ (ASR-3, ASR-4 conservan el pendiente), latencia de los controles ▼ (ASR-1, ASR-2) | El salto por el bróker es de milisegundos frente a los presupuestos de 2 s y 5 s |
| R-001a | Riesgo | El bróker es un punto común: si cae, se detienen los cuatro caminos | S-3 deja fuera la falla de infraestructura; la caída del bróker por software queda abierta |
| NR-001a | No-riesgo | La lectura de inventario es exacta porque no hay réplica | R-4 se mide contra la base primaria |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Prueba de carga | Latencia del salto por el bróker, de la publicación al consumo, con carga de Ambiente A | ≤ 2 s de extremo a extremo en ASR-1 y ≤ 5 s en ASR-2 |
| Inyección de fallas | Detener el consumidor de una etapa con pedidos en curso y reiniciarlo | 0 pedidos sin destino (ASR-4) |

**A6. Relaciones:** reemplaza: — · refina: — · depende-de: — · conflicto-con: —

**A7. Evidencia visual:** DG-CMP-001, DG-CMP-002, DG-DEP-001 (detalle en §6)

### ADR-002: Coordinador de la cadena que orquesta las etapas y guarda el estado de cada pedido por etapa

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 2 · **Confianza:** Alta — orquestación con estado persistido es un patrón conocido para flujos de pocas etapas con dueño único

#### Contexto
ASR-3 exige señalar en ≤ 30 s el pedido cuya etapa dejó de avanzar, con la etapa y el tiempo transcurrido. ASR-4 exige reanudar desde la etapa que falló, sin repetir las completadas, y entregar a una persona el estado exacto si el intento no completa. Las dos medidas dependen de una respuesta que hoy nadie guarda: en qué etapa está cada pedido y desde cuándo.

ADR-001 dejó la comunicación en eventos. El BPMN dibuja la cadena sin dueño, con un heartbeat que vigila las etapas desde afuera (C-01). S-2 dice que el cierre de las tres etapas habilita a logística.

¿Dónde vive el estado de cada pedido en su cadena, y quién decide cuál es la siguiente etapa?

#### Decisión
Usaremos un Coordinador de la cadena que orquesta las tres etapas: les envía el comando, recibe su confirmación y habilita a logística cuando las tres cierran. Guardará una fila por pedido y etapa con su estado, su intento y su marca de tiempo. Elegimos orquestar porque ASR-3 necesita un solo lugar donde leer qué pedido lleva cuánto tiempo en qué etapa, y ASR-4 necesita ese mismo lugar para saber desde dónde reanudar.

#### Consecuencias
- (+) ASR-3: el Monitor lee de una sola tabla qué etapas pasaron su plazo.
- (+) ASR-4: el Coordinador sabe qué etapas están completadas y reanuda solo la pendiente; el escalamiento lleva el estado exacto (HU-14).
- (+) Logística recibe el pedido una sola vez, cuando las tres filas están completadas (S-2).
- (−) El Coordinador es un punto central: si cae, ninguna cadena avanza hasta que vuelva (R-002a).
- (−) Rendimiento: cada etapa de cada pedido suma una fila y dos actualizaciones en la base.
- (±) La orquestación se elige para esta cadena. Los caminos de seguridad siguen por eventos sin coordinador (ADR-007, ADR-008).

#### Anexo de trazabilidad

**Y-statement:** En el contexto de la cadena de tres etapas que sigue al pedido, frente a ASR-3 y ASR-4, decidimos un Coordinador que orquesta y guarda el estado por pedido y etapa, y descartamos la coreografía y la llamada síncrona encadenada, para lograr un único lugar desde donde detectar y reanudar, aceptando un punto central y dos escrituras más por etapa.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-3 | Disponibilidad | Señal ≤ 30 s con etapa y tiempo | contribuye | primario |
| ASR-4 | Disponibilidad | Reanudación ≤ 5 s desde la etapa que falló | contribuye | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Orquestación | Integración · gestionar la interacción | EL-16 | «tactic:orquestacion» |
| Log de transacciones (estado por pedido y etapa) | Disponibilidad · recuperar | EL-16, EL-23 | «tactic:estado-por-etapa» |

**A3. Alternativas**
Drivers: ASR-3 (Alta), ASR-4 (Alta), S-2 — fijados antes de evaluar.

| Criterio | Opción A: Coordinador que orquesta con estado persistido (elegida) | Opción B: Coreografía, cada etapa reacciona al evento de la anterior | Opción C: Llamada síncrona encadenada con timeout, como el BPMN |
|---|---|---|---|
| ASR-3 señal ≤ 30 s con etapa | ++ una tabla con etapa y marca de tiempo | − el estado queda repartido entre tres servicios; detectar exige reconstruirlo | − el timeout solo lo ve el hilo que llama |
| ASR-4 reanudar desde la etapa | + se sabe qué está completo | − nadie es dueño de reenviar el evento perdido | −− el hilo que caducó no guarda qué hizo |
| S-2 cierre habilita a logística | + unión explícita de las tres filas | − alguien tiene que unir las tres confirmaciones | + el llamador une |
| ASR-4 pedidos sin destino si cae una pieza | − si cae el Coordinador, ninguna cadena avanza hasta que vuelva | + no hay pieza central cuya caída detenga todas las cadenas | − si cae el llamador, se pierde la cadena |
Descartes: B — evita el punto central, pero sin dueño del flujo el pedido detenido no tiene quién lo note ni quién lo reanude. C — pierde el estado cuando el hilo caduca, que es justo el caso de ASR-4.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| R-002a | Riesgo | Si el Coordinador cae, ninguna cadena avanza y la reanudación programada se pierde | Una sola instancia; el Monitor recoge en su siguiente barrido la etapa vencida (ADR-004) |
| NR-002a | No-riesgo | El estado sobrevive a la caída del Coordinador | El estado vive en la base, no en memoria (ADR-001) |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Inyección de fallas | Detener el Coordinador con diez pedidos en curso y reiniciarlo | 0 pedidos sin destino; cada pedido retoma desde su etapa pendiente |

**A6. Relaciones:** reemplaza: — · refina: ADR-001 · depende-de: ADR-001 · conflicto-con: —

**A7. Evidencia visual:** DG-CMP-002, DG-STM-001, DG-CLS-001 (detalle en §6)

### ADR-003: Etapas consecutivas en el orden facturación, descargue de inventario y validación de despacho

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 2 · **Confianza:** Media — depende de SUP-06 y del tiempo que espera el tendero, que está sin cifrar

#### Contexto
El BPMN dibuja las tres etapas en paralelo tras el pago, con una unión antes de la distribución, y la versión 3 de los diagramas de componentes lo copió. La página de restricciones advierte que el paralelismo es una hipótesis de diseño, no un hecho del negocio (C-01). El glosario y la página de stakeholders las nombran en orden: primera, segunda y tercera.

ASR-4 describe su estímulo como un pedido con «una o dos etapas ya completadas y una pendiente», y exige entregar a una persona el estado exacto. ASR-3 exige ≤ 1 falsa alarma por hora. ADR-002 dejó un Coordinador capaz de ordenar las etapas de cualquier forma.

¿Las tres etapas corren en paralelo o una tras otra?

#### Decisión
Adoptaremos etapas consecutivas: el Coordinador envía la facturación, luego el descargue de inventario y luego la validación de despacho, cada una al confirmarse la anterior. Lo hacemos porque así hay una sola etapa pendiente por pedido, que es el caso que describe ASR-4. Además, la validación de despacho no queda autorizando un pedido sin factura ni descargue (SUP-06).

#### Consecuencias
- (+) ASR-4: a lo sumo una etapa pendiente; la reanudación y el escalamiento nombran una sola etapa.
- (+) ASR-3: un solo plazo corriendo por pedido; menos plazos simultáneos que puedan disparar una falsa alarma.
- (+) Cancelar un pedido escalado compensa como mucho dos etapas, en orden inverso.
- (−) La cadena tarda la suma de las tres etapas, no la más lenta. Contra el tiempo que espera el tendero, que es `[PREGUNTA]`, esa suma puede no caber.
- (−) Contradice el BPMN y DG-CMP-002 v3: hay que corregir el diagrama y avisar al equipo.
- (±) Si el negocio confirma que las etapas son independientes, se reabre la opción paralela en un ADR que reemplace a este.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de una cadena orquestada de tres etapas, frente a ASR-3 y ASR-4, decidimos correrlas en orden y descartamos el paralelo con unión del BPMN para lograr una sola etapa pendiente por pedido, aceptando que la cadena dure la suma de las tres.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-4 | Disponibilidad | Reanudación ≤ 5 s con estado exacto | contribuye | primario |
| ASR-3 | Disponibilidad | ≤ 1 falsa alarma por hora | contribuye | afectado |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Protocolo de comportamiento (orden de las etapas) | Integración · cerrar distancia | EL-16 | «tactic:etapas-consecutivas» |

**A3. Alternativas**
Drivers: ASR-4 (Alta), ASR-3 (Alta), S-1, SUP-06, C-03 — fijados antes de evaluar.

| Criterio | Opción A: Etapas consecutivas (elegida) | Opción B: Etapas en paralelo con unión, como el BPMN |
|---|---|---|
| ASR-4 una etapa pendiente, estado exacto | ++ nunca hay dos pendientes | − dos etapas pueden quedar pendientes a la vez |
| ASR-3 ≤ 1 falsa alarma/h | + un plazo corriendo por pedido | − tres plazos corriendo por pedido |
| S-1 esperar a las tres | + la última cierra la cadena | + la unión cierra la cadena |
| SUP-06 dependencia entre etapas | + despacho valida con factura y descargue hechos | −− despacho valida sin saber si hubo factura |
| C-03 duración total frente a la espera del tendero | − suma de las tres | ++ la más lenta |
Descartes: B — gana en duración total, pero deja estados con dos etapas pendientes que ASR-4 no contempla y valida despachos sin factura si SUP-06 es cierto.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| S-003a | Sensibilidad | La duración total de la cadena depende de la suma de las tres etapas | Duración normal de cada etapa `[PREGUNTA]` |
| R-003a | Riesgo | La suma supera el tiempo que el tendero espera antes de ver su pedido en preparación | Ese tiempo es `[PREGUNTA]` |
| NR-003a | No-riesgo | El orden no cambia el cumplimiento de ASR-3 ni de ASR-4, porque los plazos corren por etapa | SUP-03 |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Experimento | Duración de la cadena completa en serie con carga de Ambiente A, antes de aceptar | Menor que el tiempo de espera del tendero `[PREGUNTA]`; ≤ 35 s de presupuesto conjunto si ocurre una detención |
| Revisión | Confirmar con el equipo y el negocio el orden y la dependencia de SUP-06 | 1 revisión con acta |

**A6. Relaciones:** reemplaza: — · refina: ADR-002 · depende-de: ADR-002 · conflicto-con: —

**A7. Evidencia visual:** DG-SEQ-013 (detalle en §6)

### ADR-004: Plazo vencido por pedido y etapa, encontrado por un barrido periódico, con sondeo de salud como apoyo

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 2 · **Confianza:** Baja — la medida de falsas alarmas depende de la duración normal de cada etapa, que nadie ha medido

#### Contexto
ASR-3 exige señalar en ≤ 30 s el pedido cuya etapa dejó de avanzar sin señalar error, con ≤ 1 falsa alarma por hora (Ambiente A). La falla es de omisión: la etapa sigue viva y responde, pero el pedido no avanza.

El BPMN propone un heartbeat con la pregunta «¿Is alive?» sobre cada etapa. Un latido detecta que el componente no está; no detecta que un pedido se quedó quieto dentro de un componente vivo (C-01). ADR-002 dejó en la base el estado por pedido y etapa, con su marca de tiempo. R-1 descarta esperar al cierre del día.

¿Cómo se nota, dentro de 30 s, que un pedido concreto dejó de avanzar en una etapa que sigue viva?

#### Decisión
Adoptaremos un plazo vencido por pedido y etapa: al enviar cada etapa, el Coordinador anota el instante límite. Un Monitor de la cadena barrerá cada 5 s [SUPUESTO] las etapas en curso con el plazo vencido y señalará cada pedido una sola vez. Un sondeo de salud de las etapas solo adelantará la señal cuando una etapa entera caiga. Lo hacemos porque el plazo por pedido es la única de las opciones que detecta la omisión que describe ASR-3.

#### Consecuencias
- (+) ASR-3: la demora máxima es el plazo de la etapa más un barrido. Con plazo ≤ 25 s [SUPUESTO] cabe en 30 s.
- (+) ASR-3: el sondeo adelanta la señal cuando una etapa entera cae, sin ser la única fuente.
- (−) ASR-3: un plazo corto dispara falsas alarmas y uno largo incumple los 30 s. El plazo hay que calibrarlo contra datos que no existen (TO-004a).
- (−) El Monitor es un punto único de falla: si cae, nadie detecta nada (R-004a).
- (−) Operación: una consulta indexada cada 5 s y un sondeo por etapa, permanentes.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de una cadena con estado por pedido y etapa, frente a ASR-3, decidimos un plazo por pedido y etapa revisado por barrido, con sondeo de salud de apoyo, y descartamos el latido solo y el temporizador en memoria para lograr detectar la omisión en ≤ 30 s, aceptando un plazo que hay que calibrar y un Monitor como punto único.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-3 | Disponibilidad | Señal ≤ 30 s, ≤ 1 falsa alarma por hora | satisface | primario |
| ASR-4 | Disponibilidad | Presupuesto conjunto de 35 s | contribuye | afectado |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Excepción / timeout (plazo vencido) | Disponibilidad · detectar | EL-16, EL-17 | «tactic:timeout» |
| Monitor | Disponibilidad · detectar | EL-17 | «tactic:monitor» |
| Heartbeat (sondeo de salud, apoyo) | Disponibilidad · detectar | EL-17, EL-18, EL-19 | «tactic:heartbeat» |

**A3. Alternativas**
Drivers: ASR-3 (Alta), R-1 — fijados antes de evaluar.

| Criterio | Opción A: Plazo por pedido y barrido, con sondeo de apoyo (elegida) | Opción B: Heartbeat solo, como el BPMN | Opción C: Temporizador en memoria del Coordinador, uno por pedido |
|---|---|---|---|
| ASR-3 detecta la omisión ≤ 30 s | + plazo + barrido ≤ 30 s | KO la etapa viva responde al latido; el pedido quieto no se ve | + dispara al segundo exacto |
| ASR-3 ≤ 1 falsa alarma/h | − depende de calibrar el plazo | + pocas falsas alarmas: solo mira caídas | − mismo plazo que calibrar |
| R-1 corre mientras atiende | + barrido continuo | + sondeo continuo | + en línea |
| ASR-3 señal aunque caiga el Coordinador | + el plazo está en la base | 0 no aplica | −− los temporizadores mueren con el proceso |
Descartes: B — KO: no cumple ASR-3, porque detecta la etapa caída y no el pedido detenido (hallazgo H-1 de DG-CMP v3). C — detecta igual de bien mientras el Coordinador vive, pero pierde todos los plazos si cae.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| S-004a | Sensibilidad | La demora de la señal es el plazo más el periodo del barrido | SUP-02, SUP-03 |
| TO-004a | Trade-off | El plazo de cada etapa: detección ▲ si baja (≤ 30 s), falsas alarmas ▼ si baja (≤ 1 por hora) | SUP-03: la duración p99,9 de cada etapa cabe por debajo de 25 s |
| R-004a | Riesgo | El Monitor es punto único de falla de ASR-3 | Una sola instancia; dos instancias con candado en la base es `[PREGUNTA]` |
| NR-004a | No-riesgo | Un pedido no se señala dos veces por el mismo intento | Clave única de la señal por pedido, etapa e intento |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Experimento | Medir la duración de cada etapa en operación normal durante una hora, antes de aceptar, para fijar el plazo | p99,9 de cada etapa < 25 s |
| Inyección de fallas | Bloquear la validación de despacho, confirmar diez pedidos y medir el tiempo hasta cada señal | ≤ 30 s en los diez |
| Fitness function | Una hora sin bloqueo y contar las señales | ≤ 1 falsa alarma por hora |

**A6. Relaciones:** reemplaza: — · refina: ADR-002 · depende-de: ADR-002 · conflicto-con: —

**A7. Evidencia visual:** DG-CMP-002, DG-SEQ-014, DG-STM-001, DG-DEP-001 (detalle en §6)

### ADR-005: Idempotencia por pedido y etapa con clave única en la misma transacción del efecto

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 2 · **Confianza:** Alta — la clave única en la misma transacción es un mecanismo estándar y verificable con una prueba

#### Contexto
ASR-4 exige cero facturas, descargues u órdenes de despacho duplicados cuando la cadena se reanuda. HU-15 pide lo mismo desde logística. Una etapa puede producir su efecto y fallar antes de confirmarlo: el Coordinador de ADR-002 ve la etapa pendiente, pero la factura ya existe.

El BPMN reintenta desde Método/pago, al comienzo de la cadena, lo que repetiría las etapas ya hechas (hallazgo H-2 de DG-CMP v3). ADR-001 dejó a cada servicio con su propia base transaccional.

¿Cómo garantiza cada etapa que un comando repetido no produzca su efecto dos veces?

#### Decisión
Haremos idempotente cada etapa, es decir, que repetir la misma orden no produzca un segundo efecto. Cada etapa guardará una fila con clave única por pedido y etapa, en la misma transacción local que produce la factura, el descargue o la orden de despacho. Si la fila ya existe, la etapa no repite el efecto y vuelve a confirmar. Lo hacemos porque es la única opción evaluada que cubre el caso del efecto hecho pero no confirmado.

#### Consecuencias
- (+) ASR-4: el reintento de ADR-006 y la terminación a mano de HU-14 no duplican efectos.
- (+) HU-15: logística recibe una sola factura, un solo descargue y una sola orden.
- (−) Desarrollo: las tres etapas cargan la misma disciplina; una etapa nueva que la olvide rompe ASR-4 sin que nada lo avise (R-005a).
- (−) Almacenamiento: una fila más por pedido y etapa, que crece con cada pedido.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de etapas que pueden producir su efecto y caer antes de confirmarlo, frente a ASR-4, decidimos una clave única por pedido y etapa en la transacción del efecto y descartamos la consulta previa al Coordinador y la transacción distribuida para lograr cero duplicados, aceptando una disciplina que cada etapa debe cumplir.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-4 | Disponibilidad | Duplicados = 0 | satisface | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Transacciones (idempotencia por clave única) | Disponibilidad · prevenir | EL-18, EL-08, EL-19 | «tactic:idempotencia» |

**A3. Alternativas**
Drivers: ASR-4 (Alta), R-12 — fijados antes de evaluar.

| Criterio | Opción A: Clave única en la transacción del efecto (elegida) | Opción B: Consultar al Coordinador antes de reenviar | Opción C: Transacción distribuida entre Coordinador y etapa |
|---|---|---|---|
| ASR-4 duplicados = 0 | ++ la base rechaza el segundo efecto | KO el Coordinador no sabe del efecto hecho sin confirmar | + atómico entre los dos |
| ASR-4 reanudación ≤ 5 s | + una consulta indexada | + una consulta | − el protocolo de dos fases bloquea si una parte no responde |
| R-12 implementar y medir | + se prueba con un reenvío | + sencillo | −− exige un coordinador de transacciones |
Descartes: B — KO: no cumple duplicados = 0 en el caso del efecto producido y no confirmado. C — cumple la atomicidad, pero bloquea la cadena cuando una parte no responde, que es el escenario de ASR-3.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| R-005a | Riesgo | Una etapa que no guarde la fila en la misma transacción duplica sin aviso | Revisión de cada etapa nueva |
| NR-005a | No-riesgo | La facturación y su fila son atómicas | La factura se emite en la base propia, no en un sistema externo `[PREGUNTA]` |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Inyección de fallas | Matar cada etapa justo después del commit y antes de confirmar; reenviar el comando | 0 facturas, descargues u órdenes duplicados |
| Fitness function | Auditoría diaria de pedidos con más de un efecto por etapa | 0 duplicados |

**A6. Relaciones:** reemplaza: — · refina: ADR-002 · depende-de: ADR-001 · conflicto-con: —

**A7. Evidencia visual:** DG-SEQ-015, DG-CLS-001 (detalle en §6)

### ADR-006: Un solo intento de reanudación de la etapa pendiente y escalamiento a una persona

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 2 · **Confianza:** Media — el plazo de 3 s del intento es un supuesto y cabe justo en los 5 s

#### Contexto
ASR-4 exige que, en ≤ 5 s desde la señal de ASR-3, la cadena esté reanudada o en manos de una persona con el estado exacto. Ningún pedido señalado puede quedarse sin llegar a logística ni a una persona.

El BPMN dibuja una cola con dos reintentos que vuelve a Método/pago (C-01). Dos reintentos con espera creciente no caben en 5 s, y el BPMN no tiene camino hacia una persona (hallazgos H-3 y H-4 de DG-CMP v3). ADR-005 dejó las etapas idempotentes, así que reenviar la etapa pendiente no duplica.

¿Cuántas veces se reintenta la etapa pendiente, y qué pasa cuando el intento no alcanza?

#### Decisión
Haremos un solo intento de reanudación: el Coordinador reenvía solo la etapa pendiente y espera 3 s [SUPUESTO] su confirmación. Si no llega, publica el pedido escalado con la etapa pendiente y el motivo, y la Bandeja de pedidos escalados se lo muestra a una persona. Lo hacemos porque un intento más el escalamiento es lo que cabe en 5 s. Además, el escalamiento cierra el caso del pedido sin destino.

#### Consecuencias
- (+) ASR-4: intento de 3 s más publicación caben en 5 s; cero pedidos sin destino.
- (+) HU-14: el responsable recibe la etapa pendiente y el motivo, sin reconstruir qué pasó.
- (−) Las detenciones transitorias que se resolverían con un segundo intento llegan a una persona. Esa carga manual no tiene cifra (R-006a).
- (−) Contradice el BPMN, que dibuja dos reintentos: hay que confirmarlo con el equipo.
- (±) El área a la que pertenece el responsable del pedido escalado sigue abierta.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de una cadena con etapas idempotentes, frente a ASR-4, decidimos un solo intento de la etapa pendiente seguido de escalamiento, y descartamos los dos reintentos con espera creciente del BPMN y el escalamiento inmediato, para lograr reanudar o entregar en ≤ 5 s, aceptando más pedidos en manos de personas.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-4 | Disponibilidad | ≤ 5 s desde la señal; 0 pedidos sin destino | satisface | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Reintento (un intento, sin espera creciente) | Disponibilidad · recuperar | EL-16, EL-24 | «tactic:reintento-unico» |
| Degradación con gracia (entrega a una persona) | Disponibilidad · recuperar | EL-16, EL-20 | «tactic:escalamiento» |

**A3. Alternativas**
Drivers: ASR-4 (Alta), ASR-3 (Alta, por el presupuesto conjunto de 35 s) — fijados antes de evaluar.

| Criterio | Opción A: Un intento y escalamiento (elegida) | Opción B: Dos reintentos con espera creciente, como el BPMN | Opción C: Escalamiento inmediato, sin intento |
|---|---|---|---|
| ASR-4 ≤ 5 s | + 3 s de intento más la publicación | KO dos intentos con espera no caben en 5 s | ++ inmediato |
| ASR-4 reanuda antes de escalar | + un intento | + dos intentos | −− ninguno: contradice la respuesta del ASR |
| ASR-4 pedidos sin destino = 0 | + escalamiento explícito | − el BPMN no tiene camino a una persona | + escalamiento explícito |
| ASR-3 presupuesto de 35 s | + 30 + 5 | − excede | ++ 30 + casi 0 |
Descartes: B — KO: no cumple los 5 s de ASR-4, y vuelve a Método/pago. C — cumple el tiempo con holgura, pero no intenta reanudar, que es la primera mitad de la respuesta de ASR-4.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| S-006a | Sensibilidad | El cumplimiento de 5 s depende del plazo del intento | SUP-04 |
| R-006a | Riesgo | Muchas detenciones transitorias saturan a quien atiende la bandeja | Frecuencia de detenciones `[PREGUNTA]` |
| NR-006a | No-riesgo | Un intento que el Coordinador no alcanza a procesar llega igual a la bandeja | La cola de reintentos envía sus mensajes fallidos a la bandeja |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Inyección de fallas | Liberar el bloqueo tras la señal y medir el tiempo hasta que la cadena avanza | ≤ 5 s desde la señal |
| Inyección de fallas | Mantener el bloqueo y medir el tiempo hasta la bandeja | ≤ 5 s desde la señal; 0 pedidos sin destino |

**A6. Relaciones:** reemplaza: — · refina: ADR-002 · depende-de: ADR-004, ADR-005 · conflicto-con: —

**A7. Evidencia visual:** DG-CMP-002, DG-SEQ-015, DG-STM-001 (detalle en §6)

### ADR-007: Huella del dispositivo como parte de la identidad del vendedor, verificada después de abrir la sesión

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 3 · **Confianza:** Media — no se sabe qué identificadores expone el equipo ni cuántos cambios legítimos ocurren por mes

#### Contexto
ASR-1 exige avisar al área de seguridad en ≤ 2 s cuando una sesión de vendedor, abierta con credenciales correctas, la opera un dispositivo que no es el suministrado. Admite ≤ 1 falsa alarma por cada 100 cambios legítimos de dispositivo. R-2 da algo contra qué comparar: CCP entrega el dispositivo. R-11 deja al tendero sin ese punto de comparación.

El atacante no falla el inicio de sesión: el sistema ve una sesión válida. La reacción queda en manos del área de seguridad; el sistema llega hasta el aviso. ADR-001 dejó la apertura de sesión como un evento.

¿Dónde se compara el dispositivo con el registrado, sin bloquear al vendedor legítimo?

#### Decisión
Incluiremos la huella del dispositivo en la identidad del vendedor: un resumen de identificadores del equipo, que la app calcula al abrir sesión. Un Verificador de dispositivo consumirá cada apertura de sesión y comparará la huella con la registrada. Si no coinciden, avisará al área de seguridad con vendedor, dispositivo y hora. Un camino de registro previo evitará que el cambio legítimo de equipo dispare el aviso. Verificamos después de abrir la sesión, porque ASR-1 pide detectar y avisar, no impedir, y así el inicio de sesión no espera la comparación.

#### Consecuencias
- (+) ASR-1: comparación indexada por vendedor, fuera del inicio de sesión; cabe en 2 s.
- (+) El área de seguridad recibe identidad, dispositivo y hora, que es lo que espera.
- (−) El tercero opera durante los segundos que tarda el aviso, y hasta que seguridad actúe.
- (−) Operación: cada cambio legítimo de equipo tiene que registrarse antes de usarse, o dispara el aviso. Quién lo registra está abierto.
- (−) R-9: el tendero queda sin protección equivalente (R-007a).

#### Anexo de trazabilidad

**Y-statement:** En el contexto de vendedores que operan un dispositivo suministrado, frente a ASR-1, decidimos una huella del dispositivo verificada por evento después de abrir la sesión y descartamos la verificación dentro del inicio de sesión y la revisión por lotes para lograr el aviso en ≤ 2 s sin bloquear al vendedor legítimo, aceptando que el tercero opere hasta que seguridad actúe.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-1 | Seguridad | Aviso ≤ 2 s; ≤ 1 falsa alarma por 100 cambios legítimos | satisface | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Identificar y autenticar actores (dispositivo incluido) | Seguridad · resistir | EL-03, EL-05 | «tactic:autenticar-dispositivo» |
| Detectar intrusiones | Seguridad · detectar | EL-06 | «tactic:detectar-intrusiones» |
| Informar | Seguridad · reaccionar | EL-13 | «tactic:informar» |

**A3. Alternativas**
Drivers: ASR-1 (Alta), R-1, R-2 — fijados antes de evaluar. STRIDE: S.

| Criterio | Opción A: Verificación por evento tras abrir la sesión (elegida) | Opción B: Verificación dentro del inicio de sesión | Opción C: Revisión por lotes de las sesiones del día |
|---|---|---|---|
| ASR-1 aviso ≤ 2 s | + evento más consulta indexada | ++ el aviso sale antes de abrir | KO horas, no segundos |
| ASR-1 falsas alarmas | + el vendedor legítimo sigue operando mientras se aclara | − la falsa alarma bloquea a un vendedor legítimo | + mismo registro |
| R-1 sin ventana por lotes | + continuo | + continuo | KO exige ventana |
| R-2 dispositivo suministrado | + lo usa | + lo usa | + lo usa |
Descartes: B — cumple con holgura, pero convierte cada falsa alarma en un vendedor bloqueado en la tienda y pone la comparación en el camino crítico del inicio de sesión. C — KO: no cumple los 2 s de ASR-1 y choca con R-1.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| S-007a | Sensibilidad | Las falsas alarmas dependen de qué tan estable sea la huella ante una actualización del sistema operativo | Identificadores del equipo `[PREGUNTA]` |
| R-007a | Riesgo | La suplantación del tendero no tiene señal equivalente | R-11; fuera del alcance |
| R-007b | Riesgo | Un atacante que copie la huella pasa la comparación | La huella se calcula en el dispositivo; sin gestión de dispositivos `[PREGUNTA]` |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Experimento | Abrir sesión con la credencial de un vendedor desde un dispositivo de prueba no registrado | Aviso ≤ 2 s desde la apertura |
| Experimento | Registrar y usar 100 cambios legítimos de dispositivo | ≤ 1 falsa alarma |

**A6. Relaciones:** reemplaza: — · refina: ADR-001 · depende-de: ADR-001 · conflicto-con: —

**A7. Evidencia visual:** DG-CMP-001, DG-SEQ-016 (detalle en §6)

### ADR-008: Detección de la escritura indebida por un evento que sale en la misma transacción de la escritura

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 3 · **Confianza:** Media — no se sabe qué rol del negocio es el actor de solo consulta ni cuántas escrituras por segundo hay que evaluar

#### Contexto
ASR-2 parte de una escritura ya ejecutada por un actor cuyo permiso solo cubría consultar, y exige reaccionar en ≤ 5 s desde su detección. La reacción depende de que la detección exista y de que ninguna escritura se le escape. R-7 exige que la información del tendero solo la conozca quien está autorizado.

ADR-001 dejó la comunicación por eventos, con el riesgo de que un evento salga sin su escritura o una escritura sin su evento. El token que trae el actor puede decir un permiso que ya no tiene. Revisar un registro al cierre del día choca con R-1.

¿Cómo se entera el sistema, pocos segundos después, de que una escritura la hizo alguien sin permiso para escribir?

#### Decisión
Cada escritura en Pedidos e Inventario guardará, en su misma transacción, una fila en la bitácora de escrituras y otra en un outbox. El outbox es una tabla de eventos pendientes de publicar. La fila de bitácora lleva el actor, el permiso usado y el estado anterior. Un relevo publicará el evento después del commit. Un Detector de escrituras indebidas consumirá cada evento y lo comparará con los permisos vigentes del actor, no con los del token. Lo hacemos porque garantiza que ninguna escritura quede sin evento y que la decisión use el permiso actual.

#### Consecuencias
- (+) ASR-2: cada escritura produce su evento; ninguna se escapa del Detector.
- (+) ASR-2: la bitácora conserva el estado anterior que la compensación de ADR-010 necesita.
- (−) Rendimiento: cada escritura suma dos filas en su transacción.
- (−) El Detector consulta los permisos vigentes una vez por escritura; si el Gestor de sesión no responde, la detección se retrasa (R-008a).
- (±) La detección no impide la escritura: el control preventivo de permisos sigue existiendo, y ASR-2 cubre el caso en que ese control falló.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de escrituras que pueden ejecutarse sin permiso, frente a ASR-2, decidimos una bitácora y un outbox en la misma transacción, con detección contra los permisos vigentes, y descartamos el sondeo periódico de la bitácora y la evaluación síncrona antes de responder para lograr que ninguna escritura se escape, aceptando dos filas más por escritura.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-2 | Seguridad | Reacción ≤ 5 s desde la detección; efecto residual = 0 | contribuye | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Detectar intrusiones (escritura contra permiso vigente) | Seguridad · detectar | EL-10 | «tactic:detectar-escritura» |
| Registro de auditoría | Seguridad · recuperar | EL-09, EL-07, EL-08 | «tactic:bitacora-escrituras» |

**A3. Alternativas**
Drivers: ASR-2 (Alta), R-1, R-7 — fijados antes de evaluar. STRIDE: E.

| Criterio | Opción A: Bitácora y outbox en la transacción, detector por evento (elegida) | Opción B: Sondeo periódico de la bitácora | Opción C: Evaluación síncrona antes de responder la escritura |
|---|---|---|---|
| ASR-2 ninguna escritura se escapa | ++ evento atómico con la escritura | + la bitácora es completa | + evalúa todas |
| ASR-2 reacción ≤ 5 s | + evento en milisegundos | − demora = periodo del sondeo | ++ inmediata |
| R-1 sin ventana | + continuo | + continuo con sondeo corto | + en línea |
| ASR-2 sin control síncrono en cada escritura (ficha) | − dos filas más en la transacción | + una fila | −− una consulta de permisos en el camino de cada escritura |
Descartes: B — cumple si el sondeo es corto, pero cada segundo del periodo sale de los 5 s y la carga sube con la frecuencia. C — detecta antes, pero convierte la detección en un control preventivo en el camino de cada escritura. La ficha de ASR-2 lo descarta: con ese umbral, el bloqueo iría síncrono en cada escritura.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| S-008a | Sensibilidad | El instante de detección depende del retraso del relevo del outbox | El relevo publica en milisegundos tras el commit |
| R-008a | Riesgo | Si el Gestor de sesión no responde, las escrituras esperan en la cola sin evaluar | Una caché de permisos de pocos segundos es `[PREGUNTA]` |
| NR-008a | No-riesgo | Un permiso recién quitado se ve en la escritura siguiente | El Detector no guarda caché de permisos |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Experimento | Ejecutar una escritura con credencial de solo consulta y medir hasta la detección y la reacción | Reacción ≤ 5 s desde la detección |
| Inyección de fallas | Matar el servicio entre el commit y la publicación | 0 escrituras sin evento tras reiniciar |

**A6. Relaciones:** reemplaza: — · refina: ADR-001 · depende-de: ADR-001 · conflicto-con: —

**A7. Evidencia visual:** DG-CMP-001, DG-SEQ-017 (detalle en §6)

### ADR-009: Revocación de la sesión en la puerta de entrada, con una lista de revocación consultada en cada petición

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 3 · **Confianza:** Media — el equipo no ha decidido qué hacer si la lista de revocación no responde

#### Contexto
ASR-2 exige cerrar la sesión viva del actor en ≤ 5 s desde la detección, con cero escrituras posteriores. Un token firmado se verifica sin consultar a nadie, así que sigue sirviendo hasta que vence, 15 min [SUPUESTO]. Bloquear al actor en el Gestor de sesión impide un inicio de sesión nuevo, pero no corta la sesión que ya tiene.

R-1 exige operar 7x24x365, así que lo que se ponga en el camino de cada petición también tiene que estar siempre disponible. ADR-008 dejó la detección; falta dónde se hace efectivo el corte.

¿En qué punto se corta una sesión que ya tiene un token válido, para que su siguiente petición no pase?

#### Decisión
Pondremos una Puerta de entrada de la API delante de todos los servicios. Verificará el token de cada petición y consultará una lista de revocación compartida, en memoria, con la sesión y el actor revocados. La Reacción ante acceso indebido anotará ahí la sesión y el actor. La petición siguiente recibirá un rechazo aunque el token siga vigente. Lo hacemos porque es la única opción evaluada que corta la sesión viva en milisegundos sin acortar la vida del token para todos.

#### Consecuencias
- (+) ASR-2: la escritura siguiente del actor revocado no llega al servicio; cero escrituras posteriores.
- (+) Un solo punto de corte para todos los servicios; no depende de que cada uno recuerde revisar.
- (−) Latencia: una consulta a memoria compartida por cada petición.
- (−) R-1: si la lista no responde, rechazar todo protege ASR-2 y deja el sistema sin servicio; dejar pasar protege R-1 y abre la puerta a ASR-2 (TO-009a).
- (−) Operación: la Puerta de entrada y la lista quedan en el camino de toda petición.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de sesiones con tokens que se verifican sin consultar a nadie, frente a ASR-2, decidimos una Puerta de entrada que consulta una lista de revocación en cada petición y descartamos los tokens de vida corta y la consulta de la sesión al Gestor en cada petición para lograr cortar la sesión viva en milisegundos, aceptando una consulta por petición y una pieza más en el camino crítico.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-2 | Seguridad | Cierre ≤ 5 s; escrituras posteriores = 0 | satisface | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Revocar acceso | Seguridad · reaccionar | EL-04, EL-12, EL-11 | «tactic:revocar-acceso» |
| Autenticar y autorizar en el borde | Seguridad · resistir | EL-04 | «tactic:autorizar-en-borde» |

**A3. Alternativas**
Drivers: ASR-2 (Alta), R-1 — fijados antes de evaluar. STRIDE: E.

| Criterio | Opción A: Puerta de entrada con lista de revocación (elegida) | Opción B: Tokens de vida corta, sin lista | Opción C: El Gestor de sesión valida cada petición |
|---|---|---|---|
| ASR-2 cierre ≤ 5 s | ++ la petición siguiente se rechaza | KO el token sirve hasta que vence, salvo que viva ≤ 5 s | ++ la sesión se consulta en cada petición |
| ASR-2 escrituras posteriores = 0 | + | − posibles durante la vida del token | + |
| R-1 disponibilidad | − la lista queda en el camino de cada petición | ++ nada nuevo en el camino | −− el Gestor queda en el camino de cada petición, con más carga que una consulta a memoria |
Descartes: B — KO: no cumple ASR-2 salvo con tokens de ≤ 5 s, que obligan a renovarlos sin parar. C — cumple ASR-2, pero pone un servicio con lógica y base en el camino de cada petición, con más riesgo para R-1 que una consulta a memoria.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| TO-009a | Trade-off | Comportamiento si la lista no responde: rechazar protege ASR-2 y degrada R-1; dejar pasar hace lo contrario | La preferencia del equipo es `[PREGUNTA]` |
| S-009a | Sensibilidad | Las claves de revocación deben vivir al menos lo que vive el token | SUP-05 |
| NR-009a | No-riesgo | La revocación alcanza a todos los servicios | Toda petición de la app pasa por la Puerta de entrada |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Experimento | Revocar una sesión activa y medir el tiempo hasta el primer rechazo | ≤ 5 s desde la detección; 0 escrituras posteriores |
| Inyección de fallas | Detener la lista de revocación con tráfico de Ambiente A | Comportamiento según la opción que fije el equipo en TO-009a |

**A6. Relaciones:** reemplaza: — · refina: — · depende-de: ADR-008 · conflicto-con: —

**A7. Evidencia visual:** DG-CMP-001, DG-SEQ-017, DG-STM-002, DG-DEP-001 (detalle en §6)

### ADR-010: Reversión de la escritura indebida por compensación, dentro de una reacción ordenada de menor a mayor costo

**Estado:** Propuesta · **Fecha:** 2026-09-26 · **Iteración ADD:** 3 · **Confianza:** Media — la compensación de un pedido cuya cadena ya arrancó no está resuelta

#### Contexto
ASR-2 exige revertir la escritura indebida en ≤ 5 s desde la detección y que, 60 s después de la reacción, su efecto sea cero. Entre la escritura indebida y la reversión, otros vendedores pueden haber descargado el mismo inventario: restaurar el valor anterior borraría sus cambios. R-4 exige que la cifra de inventario siga exacta.

ADR-008 dejó en la bitácora el estado anterior de cada escritura, y ADR-009 dejó el corte de la sesión. ADR-002 hace que un pedido indebido arranque su cadena de tres etapas.

¿Cómo se deshace la escritura indebida sin borrar lo que otros escribieron después?

#### Decisión
Revertiremos por compensación: una operación inversa que deshace el efecto de la escritura indebida sin tocar lo que vino después. Si fue un descargue, devolvemos la cantidad; si fue un pedido, lo anulamos. La Reacción ejecutará cuatro pasos en orden de menor a mayor costo: revocar la sesión, bloquear al actor, compensar la escritura y avisar a seguridad. Si la compensación falla, el aviso saldrá con la reversión pendiente. Lo hacemos porque es la única opción evaluada que deshace sin borrar escrituras legítimas (R-4).

#### Consecuencias
- (+) ASR-2: revocar primero corta las escrituras siguientes en milisegundos, antes del paso más lento.
- (+) ASR-2 y R-4: la compensación suma o resta, así que conserva los cambios legítimos posteriores.
- (−) Desarrollo: cada escritura necesita su operación inversa, y un pedido cuya cadena ya arrancó exige compensar también sus etapas (R-010a).
- (−) Si Pedidos o Inventario no responden, la reversión queda pendiente y el efecto residual puede pasar de 60 s.

#### Anexo de trazabilidad

**Y-statement:** En el contexto de escrituras indebidas que conviven con escrituras legítimas posteriores, frente a ASR-2, decidimos una compensación dentro de una reacción ordenada y descartamos restaurar la imagen anterior y retener las escrituras hasta aprobarlas para lograr revertir sin borrar lo ajeno, aceptando una operación inversa por cada escritura.

**A1. ASRs atendidos**

| ASR | Atributo | Medida | Efecto esperado | Rol |
|---|---|---|---|---|
| ASR-2 | Seguridad | Reversión ≤ 5 s; efecto residual a los 60 s = 0 | satisface | primario |

**A2. Tácticas**

| Táctica (curso) | Familia | Elemento(s) | Estereotipo en diagrama |
|---|---|---|---|
| Rollback por compensación | Disponibilidad · recuperar, al servicio de seguridad | EL-11, EL-07, EL-08 | «tactic:compensacion» |
| Revocar, bloquear e informar (reacción ordenada) | Seguridad · reaccionar | EL-11, EL-05 | «tactic:bloquear-actor» |

**A3. Alternativas**
Drivers: ASR-2 (Alta), R-4 — fijados antes de evaluar. STRIDE: E.

| Criterio | Opción A: Compensación semántica (elegida) | Opción B: Restaurar la imagen anterior de la fila | Opción C: Retener la escritura hasta que el Detector la apruebe |
|---|---|---|---|
| ASR-2 reversión ≤ 5 s | + una operación inversa | ++ una escritura | ++ no hay nada que revertir |
| ASR-2 efecto residual = 0 | + | −− borra los cambios legítimos posteriores | ++ |
| R-4 inventario exacto | + la cifra suma y resta | KO pisa descargues ajenos | −− el inventario no refleja escrituras en espera |
Descartes: B — KO: viola R-4, porque restaurar el valor anterior borra los descargues legítimos que llegaron después. C — gana en reversión, pero cambia el negocio: ninguna escritura queda firme hasta aprobarse, y la cifra deja de ser la del momento.

**A4. Sensibilidad, trade-offs y riesgos**

| ID | Tipo | Descripción | Supuesto del que depende |
|---|---|---|---|
| R-010a | Riesgo | Un pedido indebido cuya cadena ya emitió factura o descargue exige compensar también esas etapas | ADR-002 y ADR-003: a lo sumo dos etapas por compensar |
| S-010a | Sensibilidad | El tiempo de reversión depende de que Pedidos e Inventario respondan | S-3 deja fuera la caída por infraestructura |
| NR-010a | No-riesgo | La misma escritura no se compensa dos veces | La Reacción registra cada reacción con clave de escritura |

**A5. Confirmación**

| Tipo | Qué se prueba | Umbral |
|---|---|---|
| Experimento | Escritura con credencial de solo consulta seguida de un descargue legítimo del mismo producto | Reversión ≤ 5 s; el descargue legítimo se conserva |
| Fitness function | Revisar el estado 60 s después de cada reacción | Efecto residual = 0 |

**A6. Relaciones:** reemplaza: — · refina: — · depende-de: ADR-008, ADR-009, ADR-002 · conflicto-con: —

**A7. Evidencia visual:** DG-SEQ-017, DG-CLS-002 (detalle en §6)

## 5. Matriz ASR × ADR

| ASR | Prioridad | ADR-001 | ADR-002 | ADR-003 | ADR-004 | ADR-005 | ADR-006 | ADR-007 | ADR-008 | ADR-009 | ADR-010 | Hueco |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ASR-1 | Alta | C | — | — | — | — | — | S | — | — | — | — |
| ASR-2 | Alta | C | — | — | — | — | — | — | C | S | S | — |
| ASR-3 | Alta | C | C | C | S | — | — | — | — | — | — | — |
| ASR-4 | Alta | C | C | C | C | S | S | — | — | — | — | — |

## 6. Plan de diagramas

| DG | Tipo | Pregunta que responde | ASR | ADR | Elementos | Conectores | Táctica visible | Precio a anotar | Medida visible | Camino de fallo | Vista R&W |
|---|---|---|---|---|---|---|---|---|---|---|---|
| DG-CMP-001 | componentes | ¿Qué componentes detectan la suplantación y la escritura indebida, y por dónde se hablan? | ASR-1, ASR-2 | ADR-001, ADR-007, ADR-008, ADR-009, ADR-010 | EL-03, EL-04, EL-05, EL-06, EL-07, EL-08, EL-09, EL-10, EL-11, EL-12, EL-13, EL-15 | CN-03, CN-05, CN-08, CN-09, CN-10, CN-13, CN-15, CN-17, CN-18, CN-19, CN-20, CN-22 | «tactic:intermediario-mensajes», «tactic:autenticar-dispositivo», «tactic:detectar-intrusiones», «tactic:informar», «tactic:detectar-escritura», «tactic:bitacora-escrituras», «tactic:revocar-acceso», «tactic:autorizar-en-borde», «tactic:compensacion» | Consulta a la lista en cada petición; dos filas más por escritura; salto por el bróker | ≤ 2 s (ASR-1); ≤ 5 s (ASR-2) | no aplica | funcional |
| DG-CMP-002 | componentes | ¿Qué componentes llevan, vigilan y reanudan la cadena del pedido? | ASR-3, ASR-4 | ADR-001, ADR-002, ADR-004, ADR-006 | EL-07, EL-15, EL-16, EL-17, EL-18, EL-08, EL-19, EL-20, EL-22, EL-24, EL-23 | CN-25, CN-26, CN-32, CN-33, CN-34, CN-36, CN-37, CN-38, CN-40, CN-41 | «tactic:intermediario-mensajes», «tactic:transaccion-local», «tactic:orquestacion», «tactic:estado-por-etapa», «tactic:timeout», «tactic:monitor», «tactic:heartbeat», «tactic:reintento-unico», «tactic:escalamiento» | Coordinador y Monitor como puntos centrales; bróker común | ≤ 30 s (ASR-3); ≤ 5 s (ASR-4) | no aplica | funcional |
| DG-DEP-001 | despliegue | ¿Dónde corre cada servicio y qué piezas quedan como instancia única? | ASR-2, ASR-3 | ADR-001, ADR-004, ADR-009 | EL-04, EL-12, EL-15, EL-16, EL-17, EL-23 | CN-05, CN-33, CN-41 | «tactic:intermediario-mensajes», «tactic:monitor», «tactic:revocar-acceso» | Monitor, bróker y lista de revocación como instancia única (R-001a, R-004a, TO-009a) | 1 instancia por pieza marcada | no aplica | despliegue |
| DG-STM-001 | estados | ¿Por qué estados pasa cada etapa de un pedido y qué dispara cada transición? | ASR-3, ASR-4 | ADR-002, ADR-004, ADR-006 | EL-16, EL-17 | CN-33, CN-37 | «tactic:estado-por-etapa», «tactic:timeout», «tactic:reintento-unico», «tactic:escalamiento» | Dos escrituras por etapa; plazo por calibrar (TO-004a) | plazo ≤ 25 s [SUPUESTO]; intento 3 s [SUPUESTO] | sí — EN_CURSO con plazo vencido → reintento → ESCALADA | información |
| DG-CLS-001 | clases | ¿Qué datos guardan el estado de la cadena, las señales y las etapas procesadas? | ASR-3, ASR-4 | ADR-002, ADR-005 | EL-16, EL-17, EL-18, EL-23 | CN-41, CN-43 | «tactic:estado-por-etapa», «tactic:idempotencia» | Una fila por pedido y etapa en cada tabla | clave única (idPedido, etapa) | no aplica | información |
| DG-SEQ-013 | secuencia | ¿Cómo recorre un pedido del tendero las tres etapas en orden hasta logística, y qué pasa si una se detiene? | ASR-3, ASR-4 | ADR-003 | EL-02, EL-03, EL-07, EL-16, EL-15, EL-18, EL-08, EL-19, EL-22 | CN-02, CN-25, CN-26, CN-27, CN-28, CN-29, CN-32, CN-40 | «tactic:etapas-consecutivas» | La cadena dura la suma de las tres etapas (S-003a) | duración total vs. espera del tendero `[PREGUNTA]` | sí — validación de despacho no responde; el pedido queda EN_CURSO | concurrencia |
| DG-SEQ-014 | secuencia | ¿Cómo se nota en ≤ 30 s un pedido detenido en una etapa que sigue viva? | ASR-3 | ADR-004 | EL-16, EL-17, EL-19, EL-24 | CN-33, CN-35, CN-36 | «tactic:timeout», «tactic:monitor», «tactic:heartbeat» | El latido responde aunque el pedido esté quieto; el plazo hay que calibrarlo | señal ≤ 30 s = plazo ≤ 25 s + barrido 5 s [SUPUESTO] | sí — validación de despacho viva pero sin avanzar | concurrencia |
| DG-SEQ-015 | secuencia | ¿Cómo se reanuda la etapa pendiente en ≤ 5 s sin duplicar, y cuándo va a una persona? | ASR-4 | ADR-005, ADR-006 | EL-24, EL-16, EL-15, EL-18, EL-23, EL-20, EL-21 | CN-37, CN-26, CN-27, CN-43, CN-30, CN-38, CN-39 | «tactic:idempotencia», «tactic:reintento-unico», «tactic:escalamiento» | Transitorios que llegan a una persona (R-006a) | ≤ 5 s desde la señal; 0 duplicados | sí — efecto hecho sin confirmar; intento sin respuesta en 3 s → bandeja | concurrencia |
| DG-SEQ-016 | secuencia | ¿Cómo llega en ≤ 2 s el aviso de una sesión abierta desde un dispositivo no suministrado? | ASR-1 | ADR-007 | EL-01, EL-03, EL-04, EL-05, EL-15, EL-06, EL-13, EL-14 | CN-01, CN-03, CN-04, CN-08, CN-09, CN-10, CN-11, CN-12 | «tactic:autenticar-dispositivo», «tactic:detectar-intrusiones», «tactic:informar» | El tercero opera hasta que seguridad actúa; cambio legítimo exige registro previo | aviso ≤ 2 s desde la apertura | sí — huella no coincide; también el cambio legítimo ya registrado que no avisa | concurrencia |
| DG-SEQ-017 | secuencia | ¿Cómo se detecta la escritura indebida y se bloquea, cierra y revierte en ≤ 5 s? | ASR-2 | ADR-008, ADR-009, ADR-010 | EL-04, EL-08, EL-09, EL-15, EL-10, EL-05, EL-11, EL-12, EL-13 | CN-07, CN-14, CN-16, CN-17, CN-18, CN-19, CN-20, CN-21, CN-23, CN-24, CN-05 | «tactic:detectar-escritura», «tactic:bitacora-escrituras», «tactic:revocar-acceso», «tactic:autorizar-en-borde», «tactic:compensacion», «tactic:bloquear-actor» | Consulta a la lista en cada petición; reversión pendiente si Inventario no responde | ≤ 5 s desde la detección; 0 escrituras posteriores; efecto a los 60 s = 0 | sí — escritura indebida; segunda escritura rechazada; compensación que falla | concurrencia |
| DG-STM-002 | estados | ¿Por qué estados pasan la sesión y el actor desde la detección hasta el bloqueo? | ASR-2 | ADR-009 | EL-04, EL-05, EL-12 | CN-05, CN-20 | «tactic:revocar-acceso», «tactic:autorizar-en-borde» | La lista caída obliga a elegir entre rechazar o dejar pasar (TO-009a) | revocación ≤ 5 s desde la detección | sí — lista de revocación sin respuesta | información |
| DG-CLS-002 | clases | ¿Qué guarda la bitácora para poder compensar, y cómo se registra cada reacción? | ASR-2 | ADR-010 | EL-07, EL-08, EL-09, EL-11 | CN-13, CN-14 | «tactic:compensacion», «tactic:bloquear-actor» | Una operación inversa por tipo de escritura | marcas de tiempo de detección, revocación, bloqueo y reversión | no aplica | información |

## 7. Abierto
**Preguntas:**
- ¿Cuántos pedidos y consultas por minuto hay en operación normal, sumando los cinco países? Sin la cifra, las pruebas de A5 no replican el Ambiente A.
- ¿Cuánto espera el tendero antes de ver su pedido en preparación? Acota la duración total de la cadena en serie (ADR-003) y el presupuesto de 35 s.
- ¿Cuál es la duración p99,9 de cada etapa en operación normal? Sin ella no se fija el plazo de ADR-004. Es el experimento previo a aceptar ese ADR.
- ¿La validación de despacho necesita la factura y el descargue hechos (SUP-06)? Si no, ADR-003 se reabre.
- ¿Qué hace la Puerta de entrada si la lista de revocación no responde: rechazar o dejar pasar (TO-009a)?
- ¿Qué rol del negocio es el actor de solo consulta? ¿A qué área pertenece el responsable del pedido escalado?
- ¿Qué identificadores expone el dispositivo suministrado, y CCP lo administra con alguna herramienta de gestión? ¿Quién registra un cambio legítimo de equipo?
- ¿Se corren dos instancias del Monitor con un candado en la base (R-004a)?
- ¿La factura se emite en la base propia o en un sistema externo (NR-005a)?
- ¿Por qué canal llega el aviso al área de seguridad (CN-12)?

**Supuestos:** SUP-01 pila Java 21, Spring Boot 3, PostgreSQL, RabbitMQ y Redis. SUP-02 barrido cada 5 s. SUP-03 plazo por etapa ≤ 25 s y mayor que su p99,9. SUP-04 intento de reanudación de 3 s. SUP-05 token de 15 min. SUP-06 orden de dependencia entre etapas.

**Riesgos abiertos:** R-001a bróker como punto común de los cuatro caminos. R-002a Coordinador como punto central. R-003a duración en serie frente a la espera del tendero. R-004a Monitor como punto único de falla de ASR-3. R-006a carga manual por detenciones transitorias. R-007a tendero sin señal equivalente. R-007b huella copiable. R-008a detección retrasada si el Gestor de sesión no responde. R-010a pedido indebido con la cadena ya en curso.

**Fuera de alcance:** Seguridad — la suplantación del tendero (R-11), la divulgación entre vendedores (R-6) y la manipulación y el repudio de STRIDE. Disponibilidad — las fallas de infraestructura (S-3); la redundancia del bróker, de la base y de la lista de revocación es decisión de infraestructura. Desempeño — fue el atributo del reto 1.

**Cambios que estas decisiones piden a los diagramas v3:** ADR-003 contradice DG-CMP-002 y DG-CST-009 de `DG-CMP-componentes-reto2.md`, que dibujan las etapas en paralelo; si el equipo acepta ADR-003, esos dos diagramas cambian. Las líneas «Diagramas afectados» de las cajas blancas v3 son: ADR-001 → DG-CMP-001, DG-CMP-002 · ADR-002 → DG-CST-009 · ADR-004 → DG-CST-010, DG-SEQ-010, DG-SEQ-012 · ADR-005 y ADR-006 → DG-SEQ-009, DG-CST-011, DG-SEQ-011, DG-CST-012, DG-CST-005 · ADR-007 → DG-CST-002, DG-SEQ-002, DG-CST-003, DG-SEQ-003, DG-CST-008, DG-SEQ-008 · ADR-008 → DG-CST-004, DG-SEQ-004, DG-CST-006, DG-SEQ-006 · ADR-009 → DG-CST-001, DG-SEQ-001 · ADR-010 → DG-CST-005, DG-SEQ-005, DG-CST-007, DG-SEQ-007.

**Lint:** 0 errores, 12 avisos, todos justificados. W12 (10 avisos): el lint solo reconoce restricciones con dos dígitos (`R-01`), y este proyecto numera `R-1`, `S-1` y `SUP-06`; los diez criterios sí nombran su driver. W08 (2 avisos): DG-CMP-001 y DG-CMP-002 tienen 12 y 11 elementos porque cada uno cubre dos ASR que comparten componentes; partirlos duplicaría Pedidos, Inventario y el bróker, y la versión 3 ya los dibujó así.
