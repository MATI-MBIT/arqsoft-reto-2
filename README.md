# arqsoft-reto-2

Reto 2 de Arquitectura de Software.

## Prototipo de los experimentos E01 y E02

El código de los dos experimentos vive en este repositorio: los micros en
`services/`, la topología en `deploy/`, la carga y el plan de corridas en
`load/`, y el veredicto en `analisis/`. Requiere Docker, Java 21, k6 y `make`.

```bash
make up        # levanta los 11 micros, PostgreSQL, RabbitMQ, Prometheus y Grafana
make tablero   # abre los tableros de Grafana de E01 y E02
make smoke     # humo de ~7 min, con veredicto
make help      # todos los comandos
```

El plan, los supuestos y lo que mostró el humo están en
[`notas/plan-implementacion-experimentos.md`](notas/plan-implementacion-experimentos.md).

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
