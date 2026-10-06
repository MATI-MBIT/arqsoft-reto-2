# Contrato de réplica hacia Helix

`docs/` es la fuente de verdad. Helix es una réplica que se pide a demanda, con
la orden *«sincroniza helix reto 2»*. La réplica va en un solo sentido: lo que
alguien edite directo en Helix se pierde en la siguiente sincronización.

Arquitectura destino: `ARQ-005`, «Reto 2: Seguridad y Disponiblidad», dentro del
proyecto `PRO-001` del grupo G1.
<https://helix.virtual.uniandes.edu.co/architecture/79c75db1-be7c-4801-86b9-3e10d493df61>

La comparten seis personas con rol de edición. Lo que se cargue lo ven todas.

---

## Qué página alimenta qué sección

Cada página de `docs/` declara en su front matter la clave `helix_section`. Esa
clave es el contrato: si una sección de Helix no tiene página, no tiene fuente.

| Página | Sección en Helix | Campos |
|---|---|---|
| `architecture.md` | `Objective` | `Statement` · `In scope` · `Out of scope` · `Purpose` |
| `stakeholders.md` | `Stakeholders` | `Name` · `Role` · `Description`, uno por fila |
| `constraints.md` | `Constraints` | Un bloque por restricción, en `Business` o `Technology` |
| `requirements.md` | `Requirements & Quality` | Árbol Epic → Feature → Story |
| `quality-attributes.md` | Escenarios de calidad colgados de las historias | Ver abajo |
| `glossary.md` | `Objective → Glossary` | Un solo editor; los títulos `##` entran como `###` |
| `experiments.md` | `Experiments`, un experimento por hipótesis (E01 y E02) | Título · `Planning` (hipótesis, escenarios enlazados, tácticas, diseño, recursos, elementos, esfuerzo) |

Los nombres de sección salieron del recorrido del 2026-09-19 y están
verificados contra la interfaz. El detalle completo de cada formulario está en
`helix-recorrido-funcional.md`.

## El orden de carga no es negociable

El campo `As a` de cada historia es un **desplegable de stakeholders**, no texto
libre. De ahí se sigue una secuencia obligatoria:

1. `Stakeholders` — primero, porque las historias dependen de esta lista
2. `Objective` y `Constraints` — independientes entre sí
3. `Requirements & Quality` — el árbol de historias
4. Los escenarios de calidad, colgados de la historia que corresponda

## Cómo se carga cada campo

Todo editor de texto enriquecido de Helix tiene un botón **`Import Markdown`**.
**Corrección del 2026-10-04:** en el formulario de `Experiments` el botón abre
un panel de la página con un cuadro «Paste your Markdown text here…» y un botón
`Insert`. Ahí se pega el Markdown y entra con formato: títulos, negritas,
viñetas y enlaces. Conviene pegar los párrafos sin saltos de línea internos y
pasar las tablas a viñetas, porque no está probado que el editor dibuje tablas.
La carga del 2026-09-19 se hizo escribiendo directo en cada campo; falta
probar si los demás editores también tienen el panel.

**Lo que eso cuesta:** el texto entra con saltos de línea, no con párrafos. Se
lee bien, pero cada campo queda como un solo párrafo con saltos adentro. Si
alguien carga a mano, `Import Markdown` sigue siendo la vía mejor.

Fuera de eso no hay carga en lote. Cada historia es un recorrido de formulario.

## Lo que no se puede hacer

**No hay exportación.** El paquete Markdown de Helix —`AGENTS.md`, `docs/`,
`features/`, `stories/`— sale del *Agent channel*, y esa función está
deshabilitada para Uniandes. Helix responde «this feature is not enabled for
your organization».

Eso descarta el procedimiento que se había pensado: exportar de Helix, comparar
contra `docs/` y tomar la diferencia como lista de trabajo. **La verificación de
que la réplica quedó bien es visual, sección por sección.**

La estructura del paquete sigue siendo el destino correcto de `docs/`, porque es
la forma que Helix consume. Solo que no se puede pedir de vuelta.

## Los cuatro ASR

No son una sección aparte. Cuelgan de las historias, en la pestaña
`Quality Scenarios`, y el árbol de utilidad los agrupa solo.

Helix deriva `Source`, `Stimulus` y `Response` de la narrativa de la historia.
Lo que se carga a mano es el atributo, la prioridad, el artefacto, el ambiente,
el TPS y la medida.

| ASR | Atributo en Helix | De qué historia cuelga |
|---|---|---|
| ASR-1 | Security · Detection | HU-01 |
| ASR-2 | Security · Reaction | HU-13 |
| ASR-3 | Availability · Detection | HU-03 |
| ASR-4 | Availability · Recovery | HU-14 |

Los cuatro caben en el formulario desde que Nicolás replanteó ASR-4 de 5 min a
5 s, el 2026-09-19. Lo que no cabe son las medidas que no son de tiempo: «cero
duplicados» y «≤ 1 falsa alarma por hora» viven solo en
`docs/quality-attributes.md`.

## Lo que Helix cuenta y hoy vale cero

El indicador `Cobertura de los ASR` reporta «escenarios citados por una decisión
o un modelo». Cargar los cuatro ASR bien escritos no mueve esa cifra. Se mueve
cuando exista una decisión que los cite o un elemento de modelo que los realice,
y hoy los cinco modelos están sin dibujar.

## Convenciones

**`[PREGUNTA]`** marca un dato que no tenemos y que nadie debe inventar. Sale
cuando alguien lo responda, no antes.

**Espacio del problema.** Las páginas de `docs/` describen qué debe lograr el
sistema, no cómo. Los mecanismos —colas, réplicas, latidos de vigilancia— viven
en las decisiones de arquitectura. La excepción es lo que el enunciado ya fijó
como hecho del negocio, por ejemplo que CCP le entrega un dispositivo a cada
vendedor.

Ojo con las casillas `Security Requirements` del formulario de escenarios: son
ocho tácticas —cifrado, doble factor, control por rol, bóveda de secretos— y
pertenecen al espacio de la solución. Marcarlas al cargar un ASR mete diseño
dentro de un escenario que se escribió a propósito sin él.

---

## Estado de la réplica al 2026-09-19

Primera sincronización completa. Lo que quedó cargado:

| Sección | Estado |
|---|---|
| `Stakeholders` | 8 de 8 |
| `Objective` | Los cinco campos: enunciado, dentro, fuera, propósito y glosario |
| `Constraints` | 9 de negocio (R-1 a R-9) y 2 de tecnología (R-10, R-11) |
| `Requirements & Quality` | 4 épicas, 10 capacidades y 15 historias, con narrativa y stakeholder |
| Escenarios de calidad | 4 de 4 |

### Lo que Helix hace con la narrativa

Confirmado en pantalla: el escenario de calidad toma `Source` del stakeholder
de la historia, `Stimulus` del campo `I want` y `Response` del campo `so that`.
Solo se cargan a mano el atributo, la prioridad, el artefacto, el ambiente, el
TPS y la medida.

**Consecuencia de fidelidad.** La fuente de ASR-1 es un tercero con credenciales
robadas, pero Helix la muestra como «Vendedor», porque es el stakeholder de
HU-01 y el desplegable no admite otra cosa. Las seis partes reales viven en
`docs/quality-attributes.md`; Helix guarda una aproximación.

### Lo que quedó cargado en cada escenario

| ASR | Historia | Atributo | Prioridad | Medida cargada |
|---|---|---|---|---|
| ASR-1 | HU-01 | Security · Detection | High | 2 000 ms |
| ASR-2 | HU-13 | Security · Reaction | High | 5 000 ms |
| ASR-3 | HU-03 | Availability · Detection | High | 30 000 ms |
| ASR-4 | HU-14 | Availability · Recovery | High | 5 000 ms |

**ASR-4 entró tras replantear su medida.** Nicolás la bajó de 5 min a 5 s el
2026-09-19, y con eso cabe en el campo sin forzar nada. La consecuencia de
diseño queda anotada en la ficha: a 5 s no hay espacio para una cola de
reintentos con espera creciente, así que lo que no reanude al primer intento va
a una persona. El presupuesto conjunto de ASR-3 y ASR-4 pasa de 5,5 min a 35 s.

### Lo que se dejó deliberadamente sin marcar

Las ocho casillas `Security Requirements` —cifrado en tránsito, cifrado en
reposo, registros de auditoría, límite de tasa, validación de entrada, control
por rol, doble factor y bóveda de secretos— y el selector `Security Level`
quedaron vacíos. Son tácticas, no escenario, y marcarlas metería diseño dentro
de un ASR escrito a propósito sin él.

`[PREGUNTA]` El campo `Availability` de los escenarios de disponibilidad quedó
en su valor por omisión, 99 %. Ese número no sale de ninguna parte: el enunciado
pide 7x24x365, que es una exigencia de operación, no un porcentaje medido.

`[PREGUNTA]` El campo `TPS` quedó en 0 en los tres escenarios, porque la carga
en operación normal sigue sin definirse.

### Lo que el indicador dice hoy

- Atributos de calidad que llegaron a un escenario medible: **6 de 17**
- Escenarios citados por una decisión o un modelo: **0 de 4**
- Modelos sin dibujar: **5**
- Contradicciones: **0**

La segunda cifra es la que importa y es la que no se mueve cargando escenarios.
Se mueve cuando exista una decisión que los cite o un elemento de modelo que los
realice.

---

## Estado de la réplica al 2026-10-04

Se cargó el experimento **E01** desde `docs/experiments.md`.

| Campo | Estado |
|---|---|
| Título | Cargado |
| `Design Hypothesis` | H1 y H2 completas, con `Import Markdown` |
| `Linked Quality Scenarios` | `security_detection — HU-01` (ASR-1) y `availability_detection — HU-03` (ASR-3) |
| `Tactics and Patterns` | Cargado; la tabla de alternativas entró como viñetas |
| `Experiment Design` | Cargado sin la imagen ni el Mermaid, con enlace a la página del wiki; las tablas de fases y de relojes entraron como viñetas |
| `Required resources` · `Architecture elements involved` · `Estimated effort` | Cargados como texto plano |
| `Results & analysis` | Solo `External report`, con el enlace a la página del wiki. Resultados, análisis, conclusión y decisión quedan vacíos hasta las corridas |

`[PREGUNTA]` `Code repository` quedó vacío: falta decidir dónde vive el código
del prototipo.

### Actualización del mismo día: dos experimentos

El experimento se partió en dos, uno por hipótesis. En Helix:

| Experimento | Escenario enlazado | Contenido |
|---|---|---|
| E01 — Validar la detección del dispositivo no registrado con el micro de sesiones | `security_detection — HU-01` (ASR-1) | Solo H1, sus tácticas, fases S1–S4, recursos, elementos y 31 horas-persona |
| E02 — Validar la detección y el encolado del pedido detenido con el Monitor de la cadena | `availability_detection — HU-03` (ASR-3) | Solo H2, sus tácticas, fases D1–D4, recursos, elementos y 41 horas-persona |

Cada uno repite el montaje común (carga, cruce de entradas y salidas,
limitaciones comunes) para leerse solo. Los dos tienen `External report` con el
enlace al wiki. Para reemplazar el contenido de un editor enriquecido sirvió
hacer clic en el editor, `Cmd+A`, `Backspace` y luego `Import Markdown`.

---

## Estado de la réplica al 2026-10-06

Se sincronizó solo la parte documental. No se cargan en Helix las vistas, los
modelos, los ADR ni `results.md`: viven en `docs/modelos/` y en el wiki.

| Sección | Qué cambió |
|---|---|
| `Stakeholders` | 10: entran «Cliente institucional» y «Actor de solo consulta», y se alinean «Facturación», «Logística» y «Despacho» |
| `Objective` | `Statement`, `In scope`, `Out of scope`, `Purpose` y `Glossary` reemplazados por el texto del 2026-09-29 |
| `Constraints` | Sin cambios: R-1 a R-11 coinciden con la página |
| Escenarios de calidad | Los cuatro con `TPS` = 11 y el ambiente con la carga de A (60 pedidos/min y 600 consultas/min); ASR-2 alinea la redacción de su artefacto |
| `Experiments` | Sin cambios. `Results & analysis` sigue vacío, salvo `Code repository` y `External report` |

El `[PREGUNTA]` del `TPS` del 2026-09-19 queda resuelto: el campo pide pasos de
10, pero acepta y guarda 11.

R-12 a R-14 siguen sin cargar. Son restricciones del proyecto y Helix solo
admite `Business` y `Technology`.

El Utility Tree marca «Undefined parts: Artifact» en los cuatro escenarios
aunque el campo `Artifact` tiene texto y persiste. Es una falla de Helix, no de
la carga.

### Cómo se cargó

Todos los editores de `Objective` y de `Experiments` tienen el panel de
`Import Markdown`. El panel solo abre con un clic real sobre el botón: un
`click()` desde un script no lo abre. Para reemplazar un campo sirvió hacer
clic en el editor, `Cmd+A`, `Backspace`, clic en `Import Markdown`, pegar en el
cuadro y `Insert`. Los cambios se guardan solos; se verificaron recargando la
página.

### Actualización del 2026-10-06: diagramas de los experimentos

E01 y E02 se actualizaron en Helix con los diagramas DG-CMP-004 y DG-CMP-005.
El campo `Experiment Design` de cada uno empieza con la imagen exportada de
draw.io, enlazada a su URL en GitHub Pages (`modelos/png-v7/11-DG-CMP-004.png`
y `12-DG-CMP-005.png`); se ve cuando el wiki publica el PNG. Títulos nuevos:
E01 «… con el Verificador de dispositivo» y E02 «Validar la detección del
pedido detenido con el Monitor de la cadena y su envío a la Dead-Letter-Queue».

