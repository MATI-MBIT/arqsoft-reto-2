package co.mati.reto2.comun;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * El registro de eventos: la fuente del veredicto de los dos experimentos.
 *
 * <p>El instante se toma cuando ocurre el hecho, no cuando se escribe. La fila va
 * a una cola en memoria y un hilo aparte la vacía a la base en lote cada 200 ms,
 * para que escribir el registro no se sume a la demora que se está midiendo.
 * Prometheus no sirve para esto: agrega los datos y pierde el identificador.
 */
@Component
public final class Registro {

    private static final Logger log = LoggerFactory.getLogger(Registro.class);
    private static final long VACIADO_MS = 200;
    private static final String INSERT = """
            INSERT INTO registro.evento (ts, componente, tipo, sesion_id, pedido_id, etapa, datos)
            VALUES (?, ?, ?, ?, ?, ?, ?::jsonb)""";

    private final JdbcTemplate jdbc;
    private final ObjectMapper json;
    private final String componente;
    private final LinkedBlockingQueue<Evento> cola = new LinkedBlockingQueue<>();
    private final ScheduledExecutorService vaciador =
            Executors.newSingleThreadScheduledExecutor(Thread.ofPlatform().name("registro").daemon().factory());

    public Registro(JdbcTemplate jdbc, ObjectMapper json, @Value("${spring.application.name}") String componente) {
        this.jdbc = jdbc;
        this.json = json;
        this.componente = componente;
        vaciador.scheduleWithFixedDelay(this::vaciar, VACIADO_MS, VACIADO_MS, TimeUnit.MILLISECONDS);
    }

    public void sesion(String tipo, String sesionId, Map<String, ?> datos) {
        anotar(Instant.now(), tipo, sesionId, null, null, datos);
    }

    public void pedido(String tipo, String pedidoId, String etapa, Map<String, ?> datos) {
        anotar(Instant.now(), tipo, null, pedidoId, etapa, datos);
    }

    public void anotar(Instant ts, String tipo, String sesionId, String pedidoId, String etapa, Map<String, ?> datos) {
        cola.add(new Evento(ts, tipo, sesionId, pedidoId, etapa, datos == null ? Map.of() : datos));
    }

    private void vaciar() {
        List<Evento> lote = new ArrayList<>();
        cola.drainTo(lote);
        if (lote.isEmpty()) {
            return;
        }
        try {
            jdbc.batchUpdate(INSERT, lote, lote.size(), (ps, e) -> {
                ps.setTimestamp(1, Timestamp.from(e.ts()));
                ps.setString(2, componente);
                ps.setString(3, e.tipo());
                ps.setString(4, e.sesionId());
                ps.setString(5, e.pedidoId());
                ps.setString(6, e.etapa());
                ps.setString(7, aJson(e.datos()));
            });
        } catch (RuntimeException ex) {
            // Se devuelven a la cola: perder un evento invalida el cruce uno a uno.
            log.warn("no se pudo vaciar el registro ({} eventos), se reintenta: {}", lote.size(), ex.getMessage());
            cola.addAll(lote);
        }
    }

    private String aJson(Map<String, ?> datos) {
        try {
            return json.writeValueAsString(datos);
        } catch (JsonProcessingException ex) {
            return "{}";
        }
    }

    @PreDestroy
    void cerrar() {
        vaciador.shutdown();
        vaciar();
    }

    private record Evento(Instant ts, String tipo, String sesionId, String pedidoId, String etapa, Map<String, ?> datos) {}
}
