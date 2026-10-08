package co.mati.reto2.etapa;

import co.mati.reto2.comun.Bus;
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
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Una etapa de la cadena: facturación, descargue de inventario o validación de
 * despacho, según ETAPA. Consume etapa.ejecutar de su cola en el bróker (T8),
 * trabaja una duración aleatoria (supuesto S-11) y publica etapa.completada.
 *
 * <p>El mensaje se confirma al bróker cuando el trabajo termina, no cuando
 * llega. Si el proceso muere a mitad, el bróker lo devuelve a la cola y la etapa
 * lo retoma al reiniciar: el pedido se demora, pero no se pierde.
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
    private final RabbitTemplate bus;
    private final Registro registro;
    private final Timer tiempo;
    private final AtomicInteger porCongelar = new AtomicInteger();
    private final Set<String> enCurso = ConcurrentHashMap.newKeySet();
    private final Set<String> congelados = ConcurrentHashMap.newKeySet();

    TrabajoController(Registro registro, RabbitTemplate bus, MeterRegistry metricas,
                      @Value("${ETAPA}") String etapa,
                      @Value("${ETAPA_MEDIANA_MS:2000}") long medianaMs,
                      @Value("${ETAPA_SIGMA:0.5}") double sigma) {
        this.etapa = etapa;
        this.registro = registro;
        this.bus = bus;
        this.duracion = new Duracion(medianaMs, sigma);
        this.tiempo = Timer.builder("etapa.duracion").tag("etapa", etapa)
                .publishPercentileHistogram().maximumExpectedValue(Duration.ofSeconds(30)).register(metricas);
        metricas.gauge("etapa.trabajos.en_curso", List.of(Tag.of("etapa", etapa)), enCurso, Set::size);
        metricas.gauge("etapa.trabajos.congelados", List.of(Tag.of("etapa", etapa)), congelados, Set::size);
        log.info("etapa={} duración lognormal mediana={} ms sigma={}", etapa, medianaMs, sigma);
    }

    record Trabajo(String pedidoId, String etapa) {}

    /**
     * Un hilo por trabajo en curso (concurrency) y un mensaje por hilo (prefetch 1
     * en application.yml): el bróker no entrega más de lo que la etapa trabaja.
     */
    @RabbitListener(queues = "etapa.${ETAPA}", concurrency = "40")
    void ejecutar(Trabajo t) throws InterruptedException {
        if (porCongelar.getAndUpdate(n -> n > 0 ? n - 1 : 0) > 0) {
            congelados.add(t.pedidoId());
            // t0 de D3: el pedido entra a la etapa viva y se queda quieto. El
            // mensaje se confirma: para el bróker, la etapa ya lo tiene.
            registro.anotar(Instant.now(), "falla.congelada", null, t.pedidoId(), etapa, Map.of());
            return;
        }
        enCurso.add(t.pedidoId());
        long inicio = System.nanoTime();
        try {
            Thread.sleep(duracion.siguienteMs());
            bus.convertAndSend(Bus.CADENA, Bus.ETAPA_COMPLETADA, new Trabajo(t.pedidoId(), etapa));
        } finally {
            enCurso.remove(t.pedidoId());
            tiempo.record(System.nanoTime() - inicio, TimeUnit.NANOSECONDS);
        }
    }

    /** El punto que sondea el Monitor («ping/echo»). Responde aunque haya pedidos congelados. */
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
