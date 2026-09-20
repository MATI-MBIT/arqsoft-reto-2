---
title: Inicio
layout: home
nav_order: 1
---

# Wiki — Arqsoft Reto 2

Documentación del reto 2 de Arquitectura de Software. Todo lo que esté en la
carpeta `docs/` del repositorio se publica automáticamente en este sitio.

## Cómo agregar una página

Crea un archivo `.md` dentro de `docs/` y haz push a `main`. El sitio se
reconstruye solo. Si quieres controlar el título y la posición en el menú,
agrega front matter al inicio del archivo:

```markdown
---
title: Vista de contenedores
nav_order: 3
---

# Vista de contenedores

Contenido…
```

Sin front matter la página también se publica: el título se toma del primer
encabezado `#` del documento.

## Contenido

Las páginas aparecen en el menú lateral. Usa el buscador (`Ctrl` + `K` o
`⌘` + `K`) para encontrar cualquier término del sitio.
