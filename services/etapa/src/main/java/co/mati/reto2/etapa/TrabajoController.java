package co.mati.reto2.etapa;

import co.mati.reto2.comun.Http;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.Timer;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

/**
 * Una etapa de la cadena: facturación, descargue de inventario o validación de
 * despacho, según ETAPA. Acepta el trabajo con 202, lo termina tras una duración
 * aleatoria (supuesto S-11) y avisa a ventas.
 *
 * <p>La falla de D3 vive aquí: /fallas/congelar hace que el próximo pedido se
 * acepte y no termine nunca, mientras /salud sigue respondiendo. Es la falla que
 * ASR-3 describe, sin señal de error.
 */
@RestController
class TrabajoController {

    private static final Logger log = LoggerFactory.getLogger(TrabajoController.class);

    private final String etapa;
    private final Duracion duracion;
    private final RestClient ventas;
    private final Registro registro;
    private final Timer tiempo;
    private final ScheduledExecutorService reloj = Executors.newScheduledThreadPool(2);
    private final AtomicInteger porCongelar = new AtomicInteger();
    private final Set<String> enCurso = ConcurrentHashMap.newKeySet();
    private final Set<String> congelados = ConcurrentHashMap.newKeySet();

    TrabajoController(Registro registro, MeterRegistry metricas,
                      @Value("${ETAPA}") String etapa,
                      @Value("${ETAPA_MEDIANA_MS:2000}") long medianaMs,
                      @Value("${ETAPA_SIGMA:0.5}") double sigma,
                      @Value("${VENTAS_URL:http://localhost:8090}") String ventas) {
        this.etapa = etapa;
        this.registro = registro;
        this.duracion = new Duracion(medianaMs, sigma);
        this.ventas = Http.cliente(ventas, Duration.ofSeconds(2));
        this.tiempo = Timer.builder("etapa.duracion").tag("etapa", etapa)
                .publishPercentileHistogram().maximumExpectedValue(Duration.ofSeconds(30)).register(metricas);
        metricas.gauge("etapa.trabajos.en_curso", List.of(Tag.of("etapa", etapa)),
                enCurso, Set::size);
        metricas.gauge("etapa.trabajos.congelados", List.of(Tag.of("etapa", etapa)),
                congelados, Set::size);
        log.info("etapa={} duración lognormal mediana={} ms sigma={}", etapa, medianaMs, sigma);
    }

    record Trabajo(String pedidoId) {}

    @PostMapping("/trabajos")
    ResponseEntity<Void> aceptar(@RequestBody Trabajo t) {
        if (porCongelar.getAndUpdate(n -> n > 0 ? n - 1 : 0) > 0) {
            congelados.add(t.pedidoId());
            // t0 de D3: el pedido entra a la etapa viva y se queda quieto.
            registro.anotar(Instant.now(), "falla.congelada", null, t.pedidoId(), etapa, Map.of());
            return ResponseEntity.accepted().build();
        }
        enCurso.add(t.pedidoId());
        long inicio = System.nanoTime();
        reloj.schedule(() -> Thread.ofVirtual().start(() -> terminar(t.pedidoId(), inicio)),
                duracion.siguienteMs(), TimeUnit.MILLISECONDS);
        return ResponseEntity.accepted().build();
    }

    private void terminar(String pedidoId, long inicio) {
        tiempo.record(System.nanoTime() - inicio, TimeUnit.NANOSECONDS);
        enCurso.remove(pedidoId);
        try {
            ventas.post().uri("/pedidos/{p}/etapas/{e}/completada", pedidoId, etapa).retrieve().toBodilessEntity();
        } catch (RuntimeException ex) {
            log.warn("ventas no recibió el cierre de {} en {}: {}", pedidoId, etapa, ex.getMessage());
        }
    }

    /** El punto que sondea el Monitor. Responde aunque haya pedidos congelados. */
    @GetMapping("/salud")
    String salud() {
        return "ok";
    }

    @PostMapping("/fallas/congelar")
    ResponseEntity<Map<String, Object>> congelar() {
        int pendientes = porCongelar.incrementAndGet();
        return ResponseEntity.accepted().body(Map.of("etapa", etapa, "porCongelar", pendientes));
    }
}
