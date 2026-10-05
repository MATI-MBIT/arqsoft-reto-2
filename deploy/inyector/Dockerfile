# El inyector corre dentro de Docker para leer el mismo reloj que los micros
# (D-11): el t0 de cada falla lo anota aquí, no un script del host.
FROM alpine:3.22
RUN apk add --no-cache bash curl docker-cli postgresql17-client
COPY inyectar.sh /usr/local/bin/inyectar
RUN chmod +x /usr/local/bin/inyectar
ENTRYPOINT ["sleep", "infinity"]
