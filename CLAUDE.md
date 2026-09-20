# arqsoft-reto-2 — contexto del proyecto

Reto 2 de **ARTI4109 Arquitectura de Software** (MATI, Universidad de los
Andes). Tema: disponibilidad y seguridad. Autor: Nicolás Rozo.

Este archivo es el traspaso entre sesiones. Léelo completo antes de actuar.

---

## La meta

**`docs/` es la fuente de verdad. Helix es una réplica que se pide a demanda.**

Nicolás pedirá, cada cierto tiempo, *"sincroniza helix reto 2"*. Eso significa:
tomar lo que está en `docs/` y llevarlo a Helix. Nunca al revés.

El procedimiento, los nombres de sección verificados y el orden de carga están
en `notas/contrato-de-replica.md`. El detalle de cada formulario de Helix, en
`notas/helix-recorrido-funcional.md`.

Helix, reto 2 (`ARQ-005`, proyecto `PRO-001`, grupo G1):
<https://helix.virtual.uniandes.edu.co/architecture/79c75db1-be7c-4801-86b9-3e10d493df61>

**La arquitectura la comparten seis personas con rol de edición.** Lo que se
cargue lo ven todas: Nicolás Rozo (owner), Carlos Chaparro, Dario Correal, Luis
Guillermo Rubio, Néstor Rodríguez y Rafael Reyes.

---

## Estado actual

### El wiki

`docs/` es un sitio Jekyll con tema Just the Docs, publicado en
<https://mati-mbit.github.io/arqsoft-reto-2/> por `.github/workflows/pages.yml`.
Cualquier `.md` que llegue a `main` dentro de `docs/` se publica solo, aunque no
tenga front matter — eso lo hacen los plugins `jekyll-optional-front-matter`,
`jekyll-titles-from-headings` y `jekyll-relative-links`. El Source de GitHub
Pages está en *GitHub Actions*, no en *Deploy from a branch*; cambiarlo rompe el
despliegue.

**La raíz de `docs/` es el espejo de Helix.** No hay subcarpeta. Nicolás lo
zanjó el 2026-09-19: la estructura de `docs/` espeja el paquete que Helix
consume, y por eso los nombres de archivo son los del paquete.

| Archivo | `helix_section` | Papel en el flujo |
|---|---|---|
| `docs/index.md` | (portada del wiki) | — |
| `docs/architecture.md` | `Objective` | Insumo |
| `docs/stakeholders.md` | `Stakeholders` | Insumo |
| `docs/constraints.md` | `Constraints` | Insumo |
| `docs/requirements.md` | `Requirements & Quality` | Insumo |
| `docs/glossary.md` | `Objective → Glossary` | Insumo |
| `docs/quality-attributes.md` | escenarios colgados de las historias | **Producto de los insumos** |

---

## La regla de flujo — lo más fácil de romper

Nicolás la fijó el 2026-09-19, después de encontrar las páginas citando ASR
hacia adelante:

> **Las cuatro páginas de insumo no pueden nombrar los ASR.** El problema, los
> stakeholders, las restricciones y las historias son la materia con la que se
> construyen los ASR. De los ASR en adelante se habla de decisiones técnicas, y
> en los insumos eso no tiene sentido en la narrativa.

En la práctica:

| Etapa | Qué puede nombrar |
|---|---|
| Problema · Stakeholders · Restricciones · Glosario · Historias | Riesgos y situaciones del negocio, sin medidas ni identificadores `ASR-n` |
| Escenarios de calidad (`quality-attributes.md`) | Los ASR, y a qué historia se ata cada uno |
| Decisiones y modelos | Los ASR que cita cada decisión |

Consecuencia concreta que ya se aplicó: los criterios de aceptación de las
historias dicen **qué** tiene que ocurrir, nunca **en cuánto tiempo**. El umbral
aparece por primera vez en el escenario de calidad.

Para verificar antes de entregar: `grep -c ASR docs/*.md` debe dar cero en todo
salvo `quality-attributes.md`.

### Los ASR

`docs/quality-attributes.md` tiene los cuatro escenarios de calidad en seis partes, con
matriz STRIDE, ambientes y fichas. Lo escribió Nicolás. **Es la pieza de mayor
calidad del repositorio y la muestra de su voz.**

Se renombró desde `asr-reto-2.md` el 2026-09-19, por decisión de Nicolás, para
alinear `docs/` con los nombres del paquete de Helix. **Eso rompió la URL
publicada** `.../asr-reto-2.html`, que puede estar compartida con el grupo; la
nueva es `.../quality-attributes.html`.

### Helix está vacío

Al 2026-09-19, ninguna sección tiene contenido. Las cuatro vistas existen con
cinco modelos y los cinco están sin dibujar.

---

## Lo que el recorrido de Helix dejó decidido y lo que dejó abierto

Recorrido hecho el 2026-09-19 con navegador y sesión iniciada. Todo está en
`notas/helix-recorrido-funcional.md`; aquí va lo que cambia el trabajo.

**Los nombres de sección eran otros.** No existe «Problem this architecture
addresses» ni «User Stories» como secciones: son los títulos internos de
`Objective` y `Requirements & Quality`. Ya está corregido en el front matter.

**No hay exportación.** El paquete Markdown sale del *Agent channel*, y esa
función está deshabilitada para Uniandes. No se puede exportar de Helix para
comparar contra `docs/`. La verificación de la réplica es visual.

**Hay `Import Markdown` en cada editor.** Eso abarata la carga: se pega el
Markdown en vez de rehacer el formato. Falta probar si pide archivo o acepta
texto pegado.

**Los stakeholders van primero.** El campo `As a` de cada historia es un
desplegable de stakeholders, no texto libre.

**El escenario de calidad no es un formulario de seis partes.** Helix deriva
`Source`, `Stimulus` y `Response` de la narrativa de la historia. Solo se
cargan atributo, prioridad, artefacto, ambiente, TPS y medida, y la medida son
deslizadores fijos.

**ASR-4 no cabe.** Su medida de 5 minutos excede el techo de 60 000 ms del campo
de tiempo. Tampoco hay dónde poner «cero duplicados» ni «≤ 1 falsa alarma por
hora» de ASR-3. `[PREGUNTA]` Cuál de las tres salidas del recorrido se toma.

**El TPS deja de ser opcional.** Helix pide un número de transacciones por
segundo. Es la pregunta abierta que arrastran las cuatro fichas.

**Un ASR bien escrito sigue puntuando cero.** El indicador *Cobertura de los
ASR* cuenta un escenario solo cuando una decisión lo cita o un elemento de un
modelo lo realiza. Con cinco modelos sin dibujar, los cuatro entrarían en cero.

### Desajustes que siguen sin corregir en el contenido

- **Stakeholders.** Helix guarda `{name, role, description}`. La tabla de
  `docs/stakeholders.md` tiene cuatro columnas que hay que plegar a tres.
- **Constraints.** Helix solo admite `Business` y `Technology`, y cada
  restricción es un bloque de texto sin campo de identificador. La página tiene
  además «Restricciones del reto» y «Supuestos del equipo», que no tienen dónde
  caer, y la numeración `R-1` tendrá que ir dentro del texto.
- **Requirements.** `docs/requirements.md` es una lista plana de catorce
  historias. Helix pide Epic → Feature → Story. Falta inventar esa jerarquía.
- **Glossary.** Helix lo pide y el vocabulario ya está fijado, pero la página no
  existe.

### Rastro que dejó el recorrido en Helix

Hay que borrarlo a mano: una restricción de negocio vacía, una épica «Untitled»
con su feature y su historia, y un escenario de calidad de seguridad sin nombre.

---

## Cómo trabaja Nicolás

**Escritura.** Usa la skill `escribir-y-pulir-textos` para todo lo que se
redacta. Está instalada como skill sincronizada desde Claude Desktop y se
invoca como `anthropic-skills:escribir-y-pulir-textos`. La pidió de forma
explícita para este trabajo.

Lo que la skill exige y que conviene recordar: temperamento técnico significa
**cero aforismos**, títulos descriptivos, frases de 20 a 30 palabras, y correr
el gate de siete pasos con listas y conteo antes de entregar. El wiki es de
**entrada múltiple**, así que cada página debe sostenerse sola.

**Marcado de huecos.** `[PREGUNTA]` señala un dato que no se tiene. **No se
inventa nunca.** Es una convención suya, visible en `quality-attributes.md`.

**Disciplina de espacio del problema.** Los ASR separan lo que el sistema debe
lograr de cómo lo lograría. El diagrama BPMN del proceso de ventas mezcla las
dos cosas: el `heartbeat`, la cola de dos reintentos, las réplicas de lectura y
el JDBC son **hipótesis de solución**, no restricciones. No tratarlas como
dadas. Las ocho casillas `Security Requirements` del formulario de Helix son del
mismo tipo: tácticas, no escenario.

**Idioma.** Español de Bogotá. Los nombres de sección de Helix van en inglés
porque así los muestra la herramienta.

---

## Entorno

**No hay `gh` CLI.** Para GitHub se usa la API pública con `curl` (el repo
`MATI-MBIT/arqsoft-reto-2` es público) y `git` por SSH, que sí tiene llaves.

**Ruby local es 2.6**, insuficiente para Jekyll 4.4. El sitio no se puede
construir en local sin instalar Ruby 3.x; la verificación real es el workflow de
Actions.

**MCP de Chrome.** Registrado en `~/.claude.json` como `chrome-devtools`
(`npx chrome-devtools-mcp@latest --autoConnect`), scope user. **Funcionó el
2026-09-19** con Helix abierto y sesión iniciada. Si no aparece en la lista de
herramientas, hay que activar el debug remoto en
`chrome://inspect/#remote-debugging` y **reiniciar Claude Code**: los MCP no
cargan en una sesión ya abierta.

Dos cosas que el modo automático bloquea y hay que autorizar aparte: **borrar**
elementos en Helix, y **crear** nodos con `evaluate_script`. Para lo segundo
sirve el clic por identificador de `take_snapshot`, que sí pasa.

---

## Archivos que importan

| Ruta | Qué es |
|---|---|
| `docs/quality-attributes.md` | Los cuatro ASR. Muestra de voz del autor |
| `docs/architecture.md`, `stakeholders.md`, `constraints.md`, `requirements.md` | Las páginas espejo de Helix |
| `notas/contrato-de-replica.md` | El procedimiento de sincronización |
| `notas/helix-recorrido-funcional.md` | Cómo es Helix por dentro, verificado |
| `notas/helix-modelo-de-datos.md` | El esquema leído del bundle. **Superado en parte** por el recorrido |
| `.github/workflows/pages.yml` | Publica el wiki |
| `docs/_config.yml` | Tema, plugins, Mermaid, callouts |

---

## Convenciones de esta documentación

Notación fijada y que hay que respetar: **7x24x365** · **5,5 min** · el símbolo
**≤** para los umbrales · **ASR-1** a **ASR-4** · **R-1** en adelante para
restricciones · **HU-01** en adelante para historias.

Vocabulario fijado: se dice **pedido**, no compra ni orden. Las tres etapas que
siguen al pedido son **facturación**, **descargue de inventario** y **validación
de despacho**; su cierre habilita a **logística**, que es distinta de despacho.
