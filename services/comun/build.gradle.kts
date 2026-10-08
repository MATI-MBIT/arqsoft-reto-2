plugins {
    `java-library`
}

dependencies {
    api("org.springframework.boot:spring-boot-starter-jdbc")
    api("org.springframework.boot:spring-boot-starter-web")
    api("org.springframework.boot:spring-boot-starter-amqp")
    api("com.fasterxml.jackson.core:jackson-databind")
}
