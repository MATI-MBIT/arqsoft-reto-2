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
| *(falta)* | `Objective → Glossary` | El vocabulario ya está fijado; falta la página |

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

Todo editor de texto enriquecido de Helix tiene un botón **`Import Markdown`**,
pero abre el selector de archivos del sistema operativo y no un diálogo de la
página. Desde el navegador automatizado no se puede alcanzar, así que la carga
del 2026-09-19 se hizo escribiendo directo en cada campo.

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
| ASR-1 | Security · Detection | `[PREGUNTA]` |
| ASR-2 | Security · Reaction | `[PREGUNTA]` |
| ASR-3 | Availability · Detection | `[PREGUNTA]` |
| ASR-4 | Availability · Recovery | `[PREGUNTA]` |

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
