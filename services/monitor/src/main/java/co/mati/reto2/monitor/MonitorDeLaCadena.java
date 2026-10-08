package co.mati.reto2.monitor;

import co.mati.reto2.comun.Http;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Monitor de la cadena (EL-17), en la forma que pone a prueba H2: el sondeo de
 * salud de las etapas es el único mecanismo de detección.
 *
 * <p>Cada T sondea las tres etapas en paralelo («ping/echo»), con un tiempo de
 * espera menor que T, para que una etapa que no contesta no atrase el sondeo de
 * las otras. Cuando una etapa suma N sondeos sin respuesta la declara detenida y,
 * en ese ciclo y en cada uno mientras siga detenida, le notifica la falla al
 * Coordinador de la cadena (el micro de ventas), que envía sus pedidos
 * pendientes a la Dead-Letter-Queue (DG-CMP-005).
 *
 * <p>T, N y el tiempo de espera vienen de variables de entorno para variarlos en
 * D4 sin tocar código: SONDEO_T_MS, SONDEO_N y SONDEO_ESPERA_MS.
 */
@Component
class MonitorDeLaCadena {

    private static final Logger log = LoggerFactory.getLogger(MonitorDeLaCadena.class);

    private final long tMs;
    private final int n;
    private final Map<String, RestClient> etapas = new LinkedHashMap<>();
    private final Map<String, CuentaDeSondeos> cuentas = new ConcurrentHashMap<>();
    private final RestClient ventas;
    private final Registro registro;
    private final MeterRegistry metricas;
    private final ScheduledExecutorService ciclo = Executors.newSingleThreadScheduledExecutor();
    private final ExecutorService trabajo = Executors.newVirtualThreadPerTaskExecutor();

    MonitorDeLaCadena(Registro registro, MeterRegistry metricas,
                      @Value("${VENTAS_URL:http://localhost:8090}") String ventas,
                      @Value("${SONDEO_T_MS:2000}") long tMs,
                      @Value("${SONDEO_N:3}") int n,
                      @Value("${SONDEO_ESPERA_MS:500}") long esperaMs,
                      @Value("${FACTURACION_URL:http://localhost:8091}") String facturacion,
                      @Value("${INVENTARIO_URL:http://localhost:8092}") String inventario,
                      @Value("${DESPACHO_URL:http://localhost:8093}") String despacho) {
        if (esperaMs >= tMs) {
            throw new IllegalArgumentException("SONDEO_ESPERA_MS debe ser menor que SONDEO_T_MS");
        }
        this.tMs = tMs;
        this.n = n;
        this.ventas = Http.cliente(ventas, Duration.ofSeconds(2));
        this.registro = registro;
        this.metricas = metricas;
        Duration espera = Duration.ofMillis(esperaMs);
        etapas.put("facturacion", Http.cliente(facturacion, espera));
        etapas.put("inventario", Http.cliente(inventario, espera));
        etapas.put("despacho", Http.cliente(despacho, espera));
        etapas.keySet().forEach(e -> {
            CuentaDeSondeos cuenta = new CuentaDeSondeos(n);
            cuentas.put(e, cuenta);
            Gauge.builder("monitor.etapa.detenida", cuenta, c -> c.detenida() ? 1 : 0).tag("etapa", e).register(metricas);
            Gauge.builder("monitor.sondeos.fallidos_seguidos", cuenta, CuentaDeSondeos::fallidosSeguidos)
                    .tag("etapa", e).register(metricas);
        });
        Gauge.builder("monitor.config.t_ms", () -> tMs).register(metricas);
        Gauge.builder("monitor.config.n", () -> n).register(metricas);
        log.info("monitor: sondeo cada T={} ms, detenida tras N={} sondeos sin respuesta, espera={} ms (N×T={} ms)",
                tMs, n, esperaMs, n * tMs);
    }

    @PostConstruct
    void arrancar() {
        registro.anotar(Instant.now(), "monitor.arranque", null, null, null, Map.of("tMs", tMs, "n", n));
        ciclo.scheduleAtFixedRate(this::sondear, tMs, tMs, TimeUnit.MILLISECONDS);
    }

    @PreDestroy
    void detener() {
        ciclo.shutdownNow();
    }

    private void sondear() {
        Map<String, Future<String>> respuestas = new LinkedHashMap<>();
        etapas.forEach((etapa, cliente) -> respuestas.put(etapa, trabajo.submit(() -> sondeo(cliente))));
        respuestas.forEach((etapa, futuro) -> {
            String causa;
            try {
                causa = futuro.get();
            } catch (Exception ex) {
                causa = ex.getClass().getSimpleName();
            }
            aplicar(etapa, causa);
        });
    }

    /** null si la etapa respondió; si no, la causa, que queda en el registro. */
    private static String sondeo(RestClient cliente) {
        try {
            cliente.get().uri("/salud").retrieve().toBodilessEntity();
            return null;
        } catch (RuntimeException ex) {
            Throwable raiz = ex;
            while (raiz.getCause() != null) {
                raiz = raiz.getCause();
            }
            return raiz.getClass().getSimpleName() + ": " + raiz.getMessage();
        }
    }

    private void aplicar(String etapa, String causa) {
        boolean respondio = causa == null;
        CuentaDeSondeos cuenta = cuentas.get(etapa);
        metricas.counter("monitor.sondeos", "etapa", etapa, "resultado", respondio ? "ok" : "sin_respuesta").increment();
        CuentaDeSondeos.Cambio cambio = cuenta.registrar(respondio);
        if (!respondio) {
            registro.pedido("sondeo.fallido", null, etapa, Map.of("seguidos", cuenta.fallidosSeguidos(), "causa", causa));
        }
        switch (cambio) {
            case DECLARADA_DETENIDA -> {
                registro.pedido("etapa.declarada.detenida", null, etapa, Map.of("tMs", tMs, "n", n));
                log.warn("etapa {} declarada detenida tras {} sondeos sin respuesta", etapa, n);
            }
            case RECUPERADA -> {
                registro.pedido("etapa.recuperada", null, etapa, Map.of());
                log.info("etapa {} recuperada", etapa);
            }
            case NINGUNO -> { }
        }
        // Mientras siga detenida, cada ciclo le notifica la falla al Coordinador.
        // El aviso no espera la respuesta: el envío a la Dead-Letter-Queue no
        // debe atrasar el sondeo siguiente.
        if (cuenta.detenida()) {
            trabajo.submit(() -> notificar(etapa));
        }
    }

    private void notificar(String etapa) {
        try {
            ventas.post().uri("/fallas/etapa").body(Map.of("etapa", etapa)).retrieve().toBodilessEntity();
            metricas.counter("monitor.fallas.notificadas", "etapa", etapa).increment();
        } catch (RuntimeException ex) {
            log.warn("ventas no recibió el aviso de {}: {}", etapa, ex.getMessage());
        }
    }
}
