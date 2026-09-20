# Recorrido funcional de Helix — reto 2

Hecho el 2026-09-19 **con navegador**, sobre la arquitectura real
(`ARQ-005`, «Reto 2: Seguridad y Disponiblidad»), con sesión iniciada. Esto
corrige y completa `helix-modelo-de-datos.md`, que salió de leer el bundle.

Donde el bundle decía una cosa y la pantalla otra, manda la pantalla.

---

## Las secciones reales, en su orden

La barra lateral de la arquitectura tiene diez botones, en este orden:

`Settings` · `Objective` · `Stakeholders` · `Constraints` ·
`Requirements & Quality` · `Utility Tree` · `Experiments` · `Presentation` ·
`Document` · `Analysis`

Encima va una lista aparte, **VIEWS**, con cuatro vistas ya creadas:
`Functional View` · `Information View` · `Concurrency View` · `Deployment View`.

**Ni «Problem this architecture addresses» ni «User Stories» son secciones.**
El primero es el título que muestra la sección `Objective`; el segundo, el
título que muestra `Requirements & Quality`. Las páginas de `docs/` declaraban
esos dos rótulos como si fueran secciones, y no lo son.

| Lo que declaraba `docs/` | Lo que es en Helix |
|---|---|
| Problem this architecture addresses | `Objective` (ese es su título interno) |
| Stakeholders | `Stakeholders` ✓ |
| Constraints | `Constraints` ✓ |
| User Stories | `Requirements & Quality` (ese es su título interno) |

## Qué hay cargado hoy

Nada de contenido. `Objective`, `Stakeholders`, `Constraints` y
`Requirements & Quality` están vacías. Las cuatro vistas existen con cinco
modelos, y los cinco están **sin dibujar**.

Los cinco modelos, por vista:

| Vista | Modelos |
|---|---|
| Functional View | Component Model |
| Information View | Persistence Model · Canonical Data |
| Concurrency View | Concurrency Model |
| Deployment View | Logical Deployment Model |

La arquitectura la comparten seis personas del grupo G1 (proyecto `PRO-001`):
Nicolás Rozo (owner), Carlos Chaparro, Dario Correal, Luis Guillermo Rubio,
Néstor Rodríguez y Rafael Reyes, todos con rol `Editor`. **Lo que se cargue lo
ven los cinco.** El proyecto también tiene la arquitectura del reto 1
(`ARQ-003`, «Reto 1: Desempeño»).

---

## Objective — cuatro campos de texto enriquecido

Sub-pestañas: `Statement` · `Scope` · `Purpose` · `Glossary`. La pestaña
`Scope` trae **dos** campos, `In scope` y `Out of scope`; las otras tres traen
uno cada una. Son cinco campos en total.

Todos son editores de texto enriquecido con negrita, cursiva, subrayado, tres
niveles de título, listas con viñetas y numeradas, y alineación.

El campo `Glossary` lleva debajo esta nota de la herramienta: «Travels in the
context pack as docs/glossary.md, and the agent is told to read it before the
requirements.»

## Stakeholders — tres campos y un atajo

Confirmado lo que decía el bundle: `Name`, `Role`, `Description`. El rol es un
campo de texto con selector opcional («Type or pick a role»); no obliga a
escoger de una lista cerrada.

Hay un botón **`Import from project`** que traería los stakeholders definidos a
nivel de proyecto. Hoy no sirve: el proyecto no tiene ninguno.

## Constraints — dos cubetas y nada más

`Business Constraints` y `Technology Constraints`. Cada restricción es **un solo
bloque de texto enriquecido**, con una etiqueta `NEG` o `TEC` que se conmuta
haciendo clic. **No hay campo de título ni de identificador.** La numeración
`R-1`, `R-2` tiene que ir dentro del propio texto.

Se confirma el desajuste: no hay dónde poner «Restricciones del reto» ni
«Supuestos del equipo».

## Requirements & Quality — el detalle que faltaba revisar

Jerarquía de tres niveles, como decía el bundle: **Epic → Feature → Story**. Se
arma con un botón `Add child` en cada nodo.

- **Epic** pide `Title` y `Description`.
- **Feature** pide `Title` y `Description`.
- **Story** pide `Title` y la narrativa en tres partes.

### La narrativa de la historia

| Parte | Cómo se captura |
|---|---|
| `As a` | **Desplegable de stakeholders.** No se escribe |
| `I want` | Texto enriquecido |
| `so that` | Texto enriquecido |

**Consecuencia de orden:** los stakeholders tienen que estar cargados en Helix
antes de escribir la primera historia, porque `As a` no acepta texto libre.

Cada historia tiene dos pestañas: `Quality Scenarios (n)` y
`BDD Scenarios (Gherkin)`.

### El editor de escenarios de calidad no es un formulario de seis partes

Este es el hallazgo que más cambia el trabajo. Al añadir un escenario, Helix
muestra `Source`, `Stimulus` y `Response` en gris, con un guion, y esta nota:

> «Taken from the user story; complete the environment and the measure.»

Es decir: **las tres primeras partes del escenario las deriva Helix de la
narrativa de la historia.** No se escriben. Lo único editable es:

| Campo | Cómo se captura |
|---|---|
| `Scenario name` | Texto libre |
| Atributo | Lista cerrada con jerarquía de dos niveles |
| Prioridad | `No priority` · `Low` · `Medium` · `High` · `Critical` |
| `Artifact` | Texto libre: «Component or system that receives the stimulus…» |
| `Environment` | Texto libre: «E.g.: Normal operation, load peak…» |
| `TPS` | Número, de 0 a 100 000, paso 10 |
| Medida | **Deslizadores fijos, distintos por atributo** |

El escenario recibe un identificador automático con prefijo por atributo, por
ejemplo `-L01` para latencia.

### La lista de atributos

Diecisiete en total, con sub-atributos anidados. Los dos que nos tocan:

- **Availability** → `Detection` · `Recovery` · `Prevention`
- **Security** → `Detection` · `Resistance` · `Reaction`

Los demás: Performance (con Latency y Scalability), Reliability, Usability,
Maintainability, Modifiability, Testability, Interoperability.

### Las medidas son deslizadores, no texto

**Disponibilidad.** Tres controles: `Availability` (0 % · 90 % · 95 % · 99 % ·
99,9 % · 100 %), `Detection Time` (0 · 5 s · 15 s · 30 s · 45 s · 60 s) y un
lector derivado, `Allowed downtime`, que traduce el porcentaje a días al año,
horas al mes y horas a la semana.

**Seguridad.** Tres controles: `Security Level` (mTLS · HMAC-SHA256 ·
OAuth2 + JWT · API Key + HTTPS · Basic Auth · Sin auth), `Response Time` con la
misma escala de la disponibilidad, y `Security Requirements`, ocho casillas:
cifrado en tránsito, cifrado en reposo, registros de auditoría, límite de tasa,
validación de entrada, control de acceso por rol, doble factor y bóveda de
secretos.

**El control de tiempo es un número con techo de 60 000 milisegundos.** Los
rótulos 0, 5 s, 15 s, 30 s, 45 s y 60 s son solo marcas de la escala; el campo
acepta cualquier valor de 0 a 60 000, en pasos de 100.

Atributos verificados en el formulario de `Availability · Recovery`:

| Campo | Mínimo | Máximo | Paso |
|---|---|---|---|
| `TPS` | 0 | 100 000 | 10 |
| `Availability` | 0 | 100 | 0,001 |
| `Detection Time` | 0 | 60 000 ms | 100 |

Dos cosas que se ven ahí. El porcentaje admite tres decimales, así que 99,9 % y
99,99 % entran sin problema. Y **la pestaña de `Recovery` rotula su campo de
tiempo como `Detection Time`**: no existe un campo de tiempo de recuperación
separado del de detección.

### Dónde caben nuestros cuatro ASR, y dónde no

| ASR | Atributo | Medida nuestra | ¿Cabe? |
|---|---|---|---|
| ASR-1 | Security · Detection | ≤ 2 s = 2 000 ms | Sí |
| ASR-2 | Security · Reaction | ≤ 5 s = 5 000 ms | Sí |
| ASR-3 | Availability · Detection | ≤ 30 s = 30 000 ms | Sí |
| ASR-4 | Availability · Recovery | ≤ 5 min = 300 000 ms | **No: excede el techo cinco veces** |

**ASR-4 no cabe en el formulario.** El techo de 60 000 ms lo deja por fuera, y
además no existe un campo de tiempo de recuperación separado del de detección:
la pestaña de `Recovery` muestra los mismos tres controles que la de
`Detection`. Tampoco hay dónde registrar la segunda mitad de su medida, «cero
facturas o descargues duplicados».

Lo mismo pasa con «≤ 1 falsa alarma por hora» de ASR-3: no hay campo.

Hay tres salidas, y hay que escoger una:

1. Partir ASR-4 en dos escenarios, uno de detección dentro del techo y otro de
   recuperación, y aceptar que el segundo se registra con la medida topada.
2. Registrar el escenario con 60 000 ms y poner la medida real en el nombre del
   escenario y en `Environment`.
3. Dejar la medida completa solo en `docs/quality-attributes.md` y en el
   experimento, y usar Helix como índice.

`[PREGUNTA]` Cuál de las tres. Es decisión de Nicolás, no de formato.

### El ambiente cuantificado deja de ser opcional

El campo `TPS` es un número que Helix pide de forma explícita. Es exactamente la
pregunta abierta que arrastran las cuatro fichas: cuántos pedidos y consultas
por minuto en operación normal. Sin ese dato, los cuatro escenarios entran con
`TPS = 0`.

---

## Utility Tree — es una vista, no un formulario

Agrupa los escenarios ya cargados por atributo, con un conmutador
`By attribute` / `By priority`; el segundo dibuja un radar de anillos. No se
escribe nada aquí: los escenarios se crean desde la historia.

## Analysis — cuatro indicadores, no tres

El bundle mostraba tres. En pantalla hay cuatro, y el cuarto no estaba en las
notas:

| Indicador | Qué pregunta |
|---|---|
| Trazabilidad entre vistas | ¿Tus componentes llegan a alguna parte? |
| Cobertura de los ASR | ¿Los atributos de calidad bajaron a tierra? |
| Sustento de las decisiones | ¿Está justificado lo que dibujaste? |
| **Consistencia** | ¿Se contradice el diseño consigo mismo? |

La sección está **en español**, a diferencia del resto de la herramienta.

`Cobertura de los ASR` reporta dos cifras, y la segunda es la que importa:

- Atributos de calidad que llegaron a un escenario medible
- **Escenarios citados por una decisión o un modelo**

Se confirma la nota de `CLAUDE.md`: un escenario bien escrito puntúa cero en la
segunda cifra hasta que una decisión lo cite o un elemento de un modelo lo
realice. Con cinco modelos sin dibujar y cero nodos de razonamiento, los cuatro
ASR entrarían en cero.

Helix también mide **dedicación por persona** y **quién aportó qué**, con
ventanas de cinco minutos de actividad, en hora de Bogotá. El propio texto de la
herramienta advierte que «últimas ediciones» no se lea como reparto de esfuerzo.

## Document — genera Word, no el paquete Markdown

El botón `Generate document` abre un selector de capítulos: portada, índice,
tabla de figuras, entradas de la arquitectura (restricciones, requisitos
funcionales con o sin sus escenarios), árbol de utilidad, escenarios BDD, y los
cinco modelos. Produce un documento, no un ZIP.

## El exportador del paquete Markdown está deshabilitado

El paquete de `AGENTS.md`, `docs/`, `features/` y `stories/` que describe
`helix-modelo-de-datos.md` sale del **Agent channel**, que vive a nivel de
proyecto, no de arquitectura. Al abrirlo, Helix responde:

> «this feature is not enabled for your organization»

**Esto tumba el procedimiento de réplica que se había pensado.** No se puede
exportar de Helix para comparar contra `docs/` y sacar la lista de trabajo. La
sincronización es manual y en un solo sentido, campo por campo.

Lo que sí sobrevive es la forma del paquete como destino de `docs/`: sigue
siendo la estructura correcta porque es la que Helix consume, aunque no podamos
pedírsela de vuelta.

## Import Markdown — lo que abarata la sincronización

Cada editor de texto enriquecido —los cinco de `Objective`, la descripción de
cada restricción, la de cada épica, feature e historia, y los campos `I want` y
`so that`— tiene un botón **`Import Markdown`**.

Eso significa que el contenido de `docs/` se pega como Markdown y Helix lo
convierte, en vez de rehacerlo a mano con los botones de formato. No se alcanzó
a probar el mecanismo: el botón no abre un diálogo en el DOM, así que
probablemente lanza el selector de archivos del sistema.

`[PREGUNTA]` Si `Import Markdown` pide un archivo o acepta texto pegado. De eso
depende si `docs/` se parte en un archivo por campo o basta con copiar bloques.

## No hay carga en lote

Fuera de `Import from project` para stakeholders y de `Import Markdown` por
campo, todo se crea uno por uno con un formulario. Catorce historias son
catorce recorridos de formulario.

---

## Sin llamadas a la API visibles

No se capturaron llamadas a `getArchitectureIndicators` ni
`getArchitectureAnalysis` durante el recorrido. La pista sigue abierta, pero
con el Agent channel deshabilitado pierde parte de su valor: aunque se pudiera
leer el estado, no habría de dónde exportar el paquete.

## Lo que quedó sucio en Helix

El recorrido dejó rastro que hay que limpiar a mano, porque el borrado necesita
una autorización que no se dio:

- Una restricción de negocio vacía
- Una épica «Untitled», con una feature «Untitled» y una historia «Untitled»
- Un escenario de calidad de seguridad, sin nombre, que el árbol de utilidad ya
  cuenta como uno
