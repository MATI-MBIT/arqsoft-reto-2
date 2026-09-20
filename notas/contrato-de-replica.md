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

Todo editor de texto enriquecido de Helix tiene un botón **`Import Markdown`**.
Ese es el camino: se pega el Markdown de `docs/` y Helix lo convierte, en vez de
rehacer el formato a mano.

`[PREGUNTA]` Si `Import Markdown` pide un archivo o acepta texto pegado. De eso
depende si hace falta partir `docs/` en un archivo por campo.

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

**ASR-4 no cabe en el formulario**: su medida de 5 minutos excede el techo de
60 000 ms del campo de tiempo. Las tres salidas posibles están en
`helix-recorrido-funcional.md`; falta escoger una.

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
