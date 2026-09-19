# arqsoft-reto-2

Reto 2 de Arquitectura de Software.

## Documentación

La documentación vive en [`docs/`](docs/) y se publica como wiki en
**<https://mati-mbit.github.io/arqsoft-reto-2/>**.

Cualquier archivo `.md` que se agregue a `docs/` y llegue a `main` se publica
automáticamente mediante el workflow
[`.github/workflows/pages.yml`](.github/workflows/pages.yml).

Detalles de front matter, navegación, imágenes y vista previa local en la
[guía de publicación](docs/guia-de-publicacion.md).

### Vista previa local

```bash
cd docs
bundle install
bundle exec jekyll serve --livereload
```

Requiere Ruby 3.0 o superior.
