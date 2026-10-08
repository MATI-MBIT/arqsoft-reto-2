package co.mati.reto2.sesiones;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Hash;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * El Gestor de sesión (DG-CMP-004): abre la sesión del vendedor y publica
 * sesion.abierta en el bróker. No compara la huella: eso lo hace el Verificador
 * de dispositivo al consumir el evento (ADR-007), así el inicio de sesión no
 * espera la comparación.
 *
 * <p>El inicio de sesión es simulado: valida la credencial contra la base, sin
 * desafío real, porque el experimento mide lo que pasa después de abrir la
 * sesión y no el inicio mismo.
 */
@RestController
class SesionController {

    private final JdbcTemplate jdbc;
    private final Registro registro;
    private final RabbitTemplate bus;
    private final Counter aperturas;
    private final Counter rechazos;

    SesionController(JdbcTemplate jdbc, Registro registro, RabbitTemplate bus, MeterRegistry metricas) {
        this.jdbc = jdbc;
        this.registro = registro;
        this.bus = bus;
        this.aperturas = metricas.counter("sesiones.aperturas");
        this.rechazos = metricas.counter("sesiones.credencial.rechazada");
    }

    record Apertura(String sesionId, String vendedorId, String password, String dispositivoId) {}

    @PostMapping("/sesiones")
    ResponseEntity<Map<String, String>> abrir(@RequestBody Apertura a) {
        List<String> hash = jdbc.queryForList(
                "SELECT password_hash FROM operacion.vendedor WHERE id = ?", String.class, a.vendedorId());
        if (hash.isEmpty() || !hash.getFirst().equals(Hash.sha256(a.password()))) {
            rechazos.increment();
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        Instant abierta = Instant.now();
        jdbc.update("INSERT INTO operacion.sesion (id, vendedor_id, dispositivo_id, abierta_en) VALUES (?, ?, ?, ?)",
                a.sesionId(), a.vendedorId(), a.dispositivoId(), Timestamp.from(abierta));
        // t0 de E01: la apertura queda registrada aquí, antes de publicar el evento.
        registro.anotar(Instant.now(), "sesion.abierta", a.sesionId(), null, null,
                Map.of("vendedorId", a.vendedorId(), "dispositivoId", a.dispositivoId()));
        aperturas.increment();
        bus.convertAndSend(Bus.SEGURIDAD, Bus.SESION_ABIERTA,
                new SesionAbierta(a.sesionId(), a.vendedorId(), a.dispositivoId(), abierta.toString()));
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("sesionId", a.sesionId()));
    }
}
