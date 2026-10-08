# ==============================================================================
# arqsoft-reto-2 — prototipo de los experimentos E01 (H1, ASR-1) y E02 (H2, ASR-3)
#
# QUÉ se corre vive en load/plan.tsv, una fila por corrida con la hipótesis a la
# que sirve; CÓMO se corre, en load/experimento.sh. Aquí solo hay atajos.
# El veredicto sale del registro de eventos (analisis/*.sql); Grafana sirve para
# ver la corrida mientras pasa y para mostrar la evidencia después.
# ==============================================================================

COMPOSE := docker compose -f deploy/docker-compose.yml
PSQL    := $(COMPOSE) exec -T postgres psql -U reto2 -d reto2
MICROS  := 8081 8082 8083 8084 8090 8091 8092 8093 8094 8095 8096 8097

.DEFAULT_GOAL := help

##@ Experimentos — lo que valida las hipótesis

.PHONY: plan
plan: ## Lista las corridas del plan y a qué pregunta responde cada una
	@printf "\n  \033[1m%-7s %-10s %-4s %-6s %-8s %s\033[0m\n" grupo id exp fase criterio pregunta
	@awk -F'\t' '!/^#/ && NF>3 {printf "  %-7s %-10s %-4s %-6s %-8s %s\n", $$1,$$2,$$3,$$4,$$5,$$7}' load/plan.tsv
	@printf "\n  todo: make experimento  ·  un grupo: make grupo G=e02  ·  humo: make smoke\n\n"

.PHONY: smoke
smoke: up ## Humo de ~7 min: E01 y E02 de punta a punta, con veredicto
	./load/experimento.sh humo

.PHONY: e2e
e2e: ## Prueba de punta a punta del montaje (~9 min): compila, levanta, verifica observabilidad, humo y cruce
	./load/e2e.sh

.PHONY: experimentos
experimentos: up ## E01 y E02 de corrido, con criterio (~5 h). D4 va aparte: make d4
	./load/experimento.sh e01 e02

.PHONY: e01
e01: up ## E01 completo (~2 h): S1, S2, S3 y S4
	./load/experimento.sh e01

.PHONY: e02
e02: up ## E02 con criterio (~3 h): D1, D2 y D3 con T=2 s y N=3
	./load/experimento.sh e02

.PHONY: d4
d4: up ## D4 exploratoria (~9 h, para la noche): las 12 combinaciones de T y N
	./load/experimento.sh e02-d4

.PHONY: experimento
experimento: up ## El plan completo (~14 h): E01, E02 y D4
	./load/experimento.sh

.PHONY: grupo
grupo: up ## Un grupo del plan: make grupo G=e01
	@test -n "$(G)" || { echo "falta G. Grupos:"; awk -F'\t' '!/^#/ && NF>3 {print "  "$$1}' load/plan.tsv | sort -u; exit 1; }
	./load/experimento.sh $(G)

.PHONY: veredicto
veredicto: ## Recalcula el veredicto de una corrida: make veredicto CORRIDA=e01-s1-20261004-120000
	@test -n "$(CORRIDA)" || { echo "falta CORRIDA. Corridas:"; $(PSQL) -qtA -c "SELECT id FROM registro.corrida ORDER BY arranque DESC LIMIT 20"; exit 1; }
	@exp=$$($(PSQL) -qtA -c "SELECT lower(experimento) FROM registro.corrida WHERE id = '$(CORRIDA)'"); \
	  test -n "$$exp" || { echo "no existe la corrida $(CORRIDA)"; exit 1; }; \
	  $(PSQL) -v corrida=$(CORRIDA) -f /analisis/$$exp.sql

.PHONY: corridas
corridas: ## Lista las corridas registradas, con su ventana de medición
	@$(PSQL) -c "SELECT id, experimento, fase, inicio, fin, fin - inicio AS duracion FROM registro.corrida ORDER BY arranque DESC"

##@ Observabilidad — la evidencia en vivo

.PHONY: tablero
tablero: ## Abre los tableros de Grafana de E01 y E02
	@echo "E01 http://localhost:3000/d/e01  ·  E02 http://localhost:3000/d/e02"
	@open http://localhost:3000/d/e01 2>/dev/null; open http://localhost:3000/d/e02 2>/dev/null || true

.PHONY: tableros
tableros: ## Regenera los JSON de los tableros desde deploy/observabilidad/generar-tableros.py
	python3 deploy/observabilidad/generar-tableros.py
	$(COMPOSE) restart grafana

.PHONY: estado
estado: ## Salud de cada micro y de la infraestructura
	@for p in $(MICROS); do printf "  :%s  " $$p; curl -s -m 2 localhost:$$p/actuator/health || printf "sin respuesta"; echo; done
	@$(COMPOSE) ps --format '  {{.Name}}\t{{.State}}' | grep -vE 'reto2-(sesiones|usuario|receptor|onboarding|ventas|logistica|monitor|auditor|notificador)' || true

##@ Fallas a mano — para probar el montaje, no para medir

.PHONY: matar
matar: ## Mata una etapa y la levanta: make matar ETAPA=despacho CAIDA=20
	docker exec inyector inyectar matar $(or $(ETAPA),facturacion) $(or $(CAIDA),20)

.PHONY: congelar
congelar: ## Congela el próximo pedido de una etapa: make congelar ETAPA=inventario
	docker exec inyector inyectar congelar $(or $(ETAPA),inventario)

.PHONY: carga
carga: ## Solo la carga de fondo del Ambiente A, hasta Ctrl-C (para mirar el tablero)
	cd load/k6 && k6 run -o experimental-prometheus-rw -e CORRIDA=manual-$$(date +%H%M%S) cadena.js

##@ Topología

.PHONY: up
up: imagenes ## Levanta todo y espera a que los 12 micros respondan
	$(COMPOSE) up -d
	@printf "esperando a los micros"; for p in $(MICROS); do \
	  for i in $$(seq 1 90); do curl -fs -m 1 localhost:$$p/actuator/health >/dev/null && break; printf "."; sleep 1; done; \
	done; echo " listos"
	@# Grafana arranca su plugin de PostgreSQL con la primera consulta; esa ráfaga de
	@# CPU llegó a vencer los sondeos del Monitor. Se dispara aquí, fuera de toda corrida.
	@for i in $$(seq 1 30); do curl -fs -m 2 localhost:3000/api/health >/dev/null && break; sleep 1; done
	@curl -fs -m 20 -X POST -H 'Content-Type: application/json' localhost:3000/api/ds/query \
	  -d '{"from":"now-5m","to":"now","queries":[{"refId":"A","datasource":{"uid":"registro"},"rawSql":"SELECT 1","format":"table"},{"refId":"B","datasource":{"uid":"prometheus"},"expr":"up"}]}' >/dev/null \
	  && echo "Grafana precalentado" || echo "Grafana no respondió la consulta de precalentamiento"
	@echo "Grafana http://localhost:3000 · Prometheus http://localhost:9090 · RabbitMQ http://localhost:15672 (reto2/reto2)"

.PHONY: down
down: ## Detiene la topología; conserva la base y el histórico de Prometheus
	$(COMPOSE) down --remove-orphans

.PHONY: ps
ps: ## Estado de los contenedores
	$(COMPOSE) ps

.PHONY: logs
logs: ## Sigue los logs: make logs S=monitor
	$(COMPOSE) logs -f $(S)

.PHONY: psql
psql: ## Abre psql sobre la base del prototipo
	$(COMPOSE) exec postgres psql -U reto2 -d reto2

.PHONY: vistas
vistas: ## Recarga las vistas SQL del cruce sin perder datos
	$(PSQL) -v ON_ERROR_STOP=1 < deploy/postgres/03-vistas.sql

##@ Compilación

.PHONY: build
build: ## Compila los micros y corre sus pruebas unitarias
	./gradlew build --console=plain

.PHONY: imagenes
imagenes: ## Compila los jar y arma las imágenes (sin pruebas)
	./gradlew bootJar --console=plain -q
	$(COMPOSE) build --quiet

.PHONY: test
test: ## Pruebas unitarias
	./gradlew test --console=plain

.PHONY: clean
clean: ## Borra la compilación, los contenedores y los volúmenes (la base y Prometheus)
	./gradlew clean -q
	$(COMPOSE) down -v --remove-orphans

.PHONY: help
help: ## Muestra esta ayuda
	@awk 'BEGIN {FS = ":.*##"} \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next } \
	  /^[a-zA-Z0-9_-]+:.*##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
