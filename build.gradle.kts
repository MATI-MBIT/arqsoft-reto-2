// Convenciones comunes del prototipo de los experimentos E01 y E02 (reto 2).
// Cada micro es una aplicación Spring Boot; services:comun es una librería.
plugins {
    java
    alias(libs.plugins.spring.boot) apply false
    alias(libs.plugins.dependency.management) apply false
}

configure(subprojects.filter { it.parent?.name == "services" }) {
    apply(plugin = "java")
    apply(plugin = "io.spring.dependency-management")

    group = "co.mati.reto2"
    version = "0.1.0"

    repositories {
        mavenCentral()
    }

    extensions.configure<JavaPluginExtension> {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(21))
        }
    }

    extensions.configure<io.spring.gradle.dependencymanagement.dsl.DependencyManagementExtension> {
        imports {
            mavenBom(org.springframework.boot.gradle.plugin.SpringBootPlugin.BOM_COORDINATES)
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        options.encoding = "UTF-8"
        options.compilerArgs.add("-parameters")
    }

    tasks.withType<Test>().configureEach {
        useJUnitPlatform()
    }

    dependencies {
        "testImplementation"("org.springframework.boot:spring-boot-starter-test")
        "testRuntimeOnly"("org.junit.platform:junit-platform-launcher")
    }

    // Todo micro es una aplicación de Spring Boot salvo la librería común.
    if (name != "comun") {
        apply(plugin = "org.springframework.boot")
        dependencies {
            "implementation"(project(":services:comun"))
            "implementation"("org.springframework.boot:spring-boot-starter-web")
            "implementation"("org.springframework.boot:spring-boot-starter-jdbc")
            "implementation"("org.springframework.boot:spring-boot-starter-actuator")
            "runtimeOnly"("io.micrometer:micrometer-registry-prometheus")
            "runtimeOnly"("org.postgresql:postgresql")
        }
        tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
            archiveFileName.set("app.jar")
        }
    }
}

// El jar "plain" no lo usa nadie: la imagen copia app.jar.
configure(subprojects.filter { it.parent?.name == "services" && it.name != "comun" }) {
    tasks.named<Jar>("jar") { enabled = false }
}
