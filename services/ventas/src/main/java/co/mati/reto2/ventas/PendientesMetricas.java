package co.mati.reto2.ventas;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Pedidos en curso por etapa, para el tablero. Se recalcula cada segundo desde la base. */
@Component
@EnableScheduling
class PendientesMetricas {

    private final JdbcTemplate jdbc;
    private final Map<String, AtomicLong> enCurso = new ConcurrentHashMap<>();

    PendientesMetricas(JdbcTemplate jdbc, MeterRegistry metricas) {
        this.jdbc = jdbc;
        for (String etapa : Etapas.TODAS) {
            AtomicLong valor = new AtomicLong();
            enCurso.put(etapa, valor);
            Gauge.builder("ventas.pedidos.en_curso", valor, AtomicLong::get).tag("etapa", etapa).register(metricas);
        }
    }

    @Scheduled(fixedRate = 1000)
    void actualizar() {
        enCurso.values().forEach(v -> v.set(0));
        jdbc.query("SELECT etapa, count(*) FROM operacion.pedido_etapa WHERE estado = 'EN_CURSO' GROUP BY etapa",
                rs -> {
                    AtomicLong v = enCurso.get(rs.getString(1));
                    if (v != null) {
                        v.set(rs.getLong(2));
                    }
                });
    }
}
