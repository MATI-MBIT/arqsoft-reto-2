# Modelo de datos de Helix — hallazgos

Obtenido el 2026-09-19 **sin navegador**, leyendo el bundle de la SPA. Helix es
una aplicación SvelteKit internacionalizada: los rótulos que se ven en pantalla
son claves i18n, y el esquema vive en el código del cliente.

Cómo se reprodujo:

```bash
U=https://helix.virtual.uniandes.edu.co/_app/immutable
curl -s "$U/entry/app.DPM9MPIh.js" -o app.js        # lista de nodos de ruta
curl -s "$U/nodes/19.DnU35exG.js" -o n19.js         # ruta /architecture (2,6 MB)
```

Los hashes de los archivos cambian en cada despliegue. Para volver a ubicarlos:
pedir el HTML de la página, leer el `<link>` del CSS numerado (era
`19.CSOBFgUd.css`) y buscar el `.js` del mismo número en `app.js`.

**Advertencia:** esto es ingeniería inversa del cliente, no documentación
oficial. Sirve para saber qué campos pedir; hay que confirmarlo contra la
interfaz antes de darlo por cierto.

## Secciones y sus campos

### Problem — prefijo `swProblem`

| Campo | Clave i18n |
|---|---|
| `enunciado` | `swProblem.statement` |
| `proposito` | `swProblem.purpose` |
| `alcance` | `swProblem.scope` |
| `fuera_alcance` | `swProblem.outOfScope` |
| `glosario` | `swProblem.glossary` |

### Stakeholders

Se guardan en `design_metadata.stakeholders.stakeholders[]`. Cada uno tiene
**tres campos y nada más**:

```js
{ id, name, role, description }
```

### Constraints — prefijo `docGen.constraints`

Cada restricción lleva un campo `tipo` con **solo dos valores**:

| `tipo` | Clave i18n |
|---|---|
| `negocio` | `docGen.constraintsBusiness` |
| `tecnologia` | `docGen.constraintsTech` |

No existe una categoría para restricciones del proyecto ni para supuestos.

### Requirements / User Stories — prefijo `swReq`

Jerarquía de tres niveles: **Epic → Feature → Story**.

Cada historia tiene:

- Narrativa en tres partes: `asA` · `iWant` · `soThat`
- `title`, `description`
- **Stakeholder asociado** (`selectStakeholder`) — se escoge de la lista de
  stakeholders, no se escribe libre
- Prioridad: `prioCritical` · `prioHigh` · `prioMedium` · `prioLow` · `prioNone`
- Marca `implemented`
- Vínculo a una misión (`inMission`)

Y **dos pestañas por historia**, que es el detalle que hay que revisar:

1. **`qualityScenariosTab`** — escenarios de calidad en las seis partes de Bass:
   `bassSource` · `bassStimulus` · `bassEnvWord` · `bassResponse` ·
   `bassMeasureWord`, más el artefacto. **Aquí es donde entran nuestros cuatro
   ASR.** No son una sección aparte: cuelgan de las historias.
2. **`bddScenariosTab`** — escenarios BDD con exportación a Gherkin.

Atributos de calidad disponibles: `attrAvailability`, `attrSecurity`,
`attrPerformance`, `attrLatency`, `attrScalability`, `attrReliability`,
`attrModifiability`, `attrMaintainability`, `attrTestability`,
`attrInteroperability`, `attrUsability`.

### Quality — prefijo `quality`

Árbol de utilidad (`quality.tree`): atributos raíz, atributos hijos y escenarios
colgando de ellos. El editor (`quality.editor`) pide: `source`, `stimulus`,
`artifact`, `environment`, `response`, `response_measure`, `priority`,
`description`, `attribute_path`.

### Experiments — prefijo `swExp`

Ocho campos en dos bloques: `hypothesis` · `tactics` · `design` · `resources`, y
después `results` · `analysis` · `conclusion` · `decision`. Es donde aterriza la
exigencia del enunciado de implementar y medir.

### Missions — prefijo `missions`

Pestañas `general` · `stories` · `ux` · `dod`, con responsable asignable
(`assignee`: team, factory, trifid), objetivo, definición de terminado y UX.

## Generación de documento — `docGen`

Helix exporta un documento Word con capítulos seleccionables: portada, índice,
introducción, entradas, restricciones, requisitos, atributos de calidad,
modelos, diseño, experimentos, evaluación, figuras y glosario. Las banderas del
selector son `includeConstraints`, `includeRequirements`, `includeQuality`,
`includeDesign`, `includeInputs`, `includeCover`, `includeToc`, `includeFigures`.

Esto importa para la réplica: lo que se cargue en Helix termina en ese
documento, así que la estructura de `docs/` debería poder alimentar cada
capítulo.

## Qué falta confirmar

- Los nombres exactos en inglés que se ven en pantalla. El bundle trae claves,
  no traducciones; el diccionario está en otro archivo que no se ubicó.
- Si "Problem this architecture addresses" corresponde a `swProblem.statement` o
  al título de la pestaña completa.
- Si hay API REST para cargar contenido, o si la única vía es la interfaz. No
  aparecieron rutas `/api` en el módulo de la ruta `/architecture`.
- Si las historias se cargan una por una o admiten importación en lote.

---

# Segunda tanda de hallazgos — lo que corrige a la primera

## Los ASR sí se nombran, y hay un indicador que los mide

La sigla aparece una vez en el bundle, en el módulo de **indicadores de la
arquitectura** (`getArchitectureIndicators`, `getArchitectureAnalysis`). Son
tres indicadores y el segundo es `cobertura_asr`:

| Clave | Título | Qué pregunta |
|---|---|---|
| `trazabilidad` | Trazabilidad entre vistas | ¿Tus componentes llegan a alguna parte? |
| `cobertura_asr` | **Cobertura de los ASR** | ¿Los atributos de calidad bajaron a tierra? |
| `sustento` | Sustento de las decisiones | ¿Está justificado lo que dibujaste? |

El texto de `cobertura_asr`, literal de la herramienta:

> «Disponibilidad» es una palabra; «responde en menos de 2 s el 99 % de las
> veces» es algo que se puede comprobar. Y un escenario solo cuenta cuando
> alguien se hace cargo: una decisión que lo cita o un elemento de un modelo. La
> línea de escenarios frente a historias va sin color: no hay proporción
> correcta.

**Consecuencia para nosotros.** Un ASR cargado en Helix no cuenta por estar bien
escrito. Cuenta cuando **una decisión lo cita o un elemento de un modelo lo
realiza**. Nuestros cuatro ASR están impecables como escenarios y hoy
puntuarían cero en ese indicador, porque todavía no hay decisiones ni modelos
que se hagan cargo de ellos.

El indicador también reporta `densidad: {escenarios, historias}`,
`vistas_faltantes`, `anclaje_suelto`, `distribucion_atributos` y
`salud_componentes`.

## Helix exporta el paquete en Markdown — esta es la estructura a replicar

El exportador arma un ZIP con un paquete de especificación listo para un agente.
La lista sale del propio texto de la herramienta:

```
AGENTS.md                              guía para el agente (qué hay y cómo construir)
features/                              escenarios BDD (Gherkin) ejecutables por requisito
docs/requirements.md                   requisitos funcionales (narrativa)
docs/quality-attributes.md             atributos de calidad (Bass/SEI)
docs/constraints.md                    restricciones de diseño
docs/stakeholders.md                   los interesados y qué espera cada uno
docs/glossary.md                       los términos del negocio
docs/design-rules.md                   reglas de diseño ancladas al modelo, con verificación
docs/adr/                              decisiones de arquitectura (formato MADR)
docs/architecture.md                   índice de vistas y modelos
docs/architecture/<vista>/<modelo>.md  un archivo por modelo
stories/<id>.md  ·  stories/<id>.feature
focus/components.md  ·  focus/reasoning.md
```

**Este es el hallazgo que decide el diseño de `docs/`.** Si nuestra carpeta
espeja esa estructura, la sincronización deja de ser trasiego a ciegas: se
exporta de Helix, se compara contra `docs/` y la diferencia es la lista de
trabajo.

### Cómo se arma `docs/architecture.md`

Encabezado con nombre, tipo, versión, estado, arquitectos y fecha. Después, las
secciones que salen de `swProblem`:

| Encabezado que genera | Campo |
|---|---|
| `## Problema que resuelve` | `enunciado` |
| `## Alcance` | `alcance` |
| `## Fuera de alcance` | `fuera_alcance` |
| `## Propósito del diseño` | `proposito` |

Y luego, del documento de diseño: `## Objetivo general`, `## Objetivos
específicos`, `## Alcance`, `## Público objetivo`.

**Corrección a la primera tanda:** "Problem this architecture addresses"
corresponde al campo `enunciado`, que el exportador titula «Problema que
resuelve». No es el título de la pestaña completa.

### El glosario no es opcional

El exportador le pone este encabezado fijo: «Los términos del negocio, como los
usa este proyecto. Cuando un término de aquí aparezca en un requisito o en un
modelo, significa **esto** — no lo que signifique en otro dominio.» Encaja con
la nota de vocabulario que ya abre `docs/quality-attributes.md`.

## Siguiente paso de investigación

`getArchitectureIndicators` y `getArchitectureAnalysis` son llamadas a una API.
No se logró ubicar la URL base dentro del módulo de la ruta; está en otro chunk.
Si se encuentra y acepta la sesión del navegador, se podría **leer el estado
real de Helix sin abrir la interfaz**, y comparar contra `docs/` de forma
automática.
