# arqsoft-reto-2

Reto 2 de Arquitectura de Software.

## Prototipo de los experimentos E01 y E02

El código de los dos experimentos vive en este repositorio: los micros en
`services/`, la topología en `deploy/`, la carga y el plan de corridas en
`load/`, y el veredicto en `analisis/`. Requiere Docker, Java 21, k6 y `make`.

```bash
make up        # levanta los 12 micros, PostgreSQL, RabbitMQ, Prometheus y Grafana
make tablero   # abre los tableros de Grafana de E01 y E02
make smoke     # humo de ~7 min, con veredicto
make help      # todos los comandos
```

### En Windows

`make.bat` y `make.ps1` son el equivalente del Makefile, con los mismos
objetivos y la misma sintaxis. En `cmd`, `make smoke` encuentra `make.bat` en la
carpeta; en PowerShell se escribe `.\make smoke`. El orquestador y el e2e tienen
su versión en PowerShell (`load\experimento.ps1` y `load\e2e.ps1`), y lo que
corre dentro de los contenedores es el mismo.

Requiere Docker Desktop con contenedores Linux (WSL 2), JDK 21, k6
(`winget install k6`) y Python 3, este último solo para `make e2e` y
`make tableros`. Funciona con el Windows PowerShell 5.1 que trae Windows y con
PowerShell 7. El repositorio fija con `.gitattributes` el fin de línea LF de los
`.sh`: el inyector copia `inyectar.sh` a una imagen Linux y con CRLF no corre.

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
