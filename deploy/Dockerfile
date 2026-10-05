# Imagen de cualquiera de los micros. El jar se compila en el host con
# `make build`, así la imagen se arma en segundos y sin red.
# Uso: docker build -f deploy/Dockerfile --build-arg SERVICE=ventas .
FROM eclipse-temurin:21-jre
ARG SERVICE
COPY services/${SERVICE}/build/libs/app.jar /app/app.jar
ENV JAVA_OPTS="-Xms128m -Xmx256m"
ENTRYPOINT ["/bin/sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
