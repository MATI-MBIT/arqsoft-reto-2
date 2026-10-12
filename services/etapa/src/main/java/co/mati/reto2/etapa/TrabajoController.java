package co.mati.reto2.etapa;

import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import co.mati.reto2.comun.Bus;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.Timer;

/**
 * Una etapa de la cadena (facturación, descargue de inventario o validación de
 * despacho). Toma su trabajo de la cola etapa.&lt;etapa&gt; del bróker, lo hace
 * en una duración lognormal (S-11) y publica etapa.completada.
 *
 * <p>Es idempotente (ReciboDeEtapa): guarda el recibo antes de que el mensaje
 * se confirme al bróker, y aplica su efecto una sola vez aunque el pedido le
 * llegue dos veces. El mensaje se confirma al bróker cuando el listener vuelve:
 * si el proceso muere a mitad, el bróker lo devuelve y la etapa lo retoma.
 *
 * <p>La falla de D3 vive aquí: /fallas/congelar hace que el próximo pedido se
 * acepte, con su recibo, y no termine nunca. Es la falla que ASR-3 describe, sin
 * señal de error: la etapa sigue viva y respondiendo.
 */
@RestController
class TrabajoController {

    private static final Logger log = LoggerFactory.getLogger(TrabajoController.class);

    private final String etapa;
    private final Duracion duracion;
    private final RabbitTemplate bus;
    private final Registro registro;
    private final ReciboDeEtapa recibo;
    private final MeterRegistry metricas;
    private final Timer tiempo;
    private final AtomicInteger porCongelar = new AtomicInteger();
    private final Set<String> enCurso = ConcurrentHashMap.newKeySet();

    TrabajoController(Registro registro, RabbitTemplate bus, ReciboDeEtapa recibo, MeterRegistry metricas,
                      @Value("${ETAPA}") String etapa,
                      @Value("${ETAPA_MEDIANA_MS:2000}") long medianaMs,
                      @Value("${ETAPA_SIGMA:0.5}") double sigma) {
        this.etapa = etapa;
        this.registro = registro;
        this.bus = bus;
        this.recibo = recibo;
        this.metricas = metricas;
        this.duracion = new Duracion(medianaMs, sigma);
        this.tiempo = Timer.builder("etapa.duracion").tag("etapa", etapa)
                .publishPercentileHistogram().maximumExpectedValue(Duration.ofSeconds(30)).register(metricas);
        metricas.gauge("etapa.trabajos.en_curso", List.of(Tag.of("etapa", etapa)), enCurso, Set::size);
        log.info("etapa={} duración lognormal mediana={} ms sigma={}", etapa, medianaMs, sigma);
    }

    record Trabajo(String pedidoId, String etapa) {}

    /**
     * Un hilo por trabajo en curso (concurrency) y un mensaje por hilo (prefetch 1
     * en application.yml): el bróker no entrega más de lo que la etapa trabaja.
     */
    @RabbitListener(queues = "etapa.${ETAPA}", concurrency = "40")
    void ejecutar(Trabajo t) throws InterruptedException {
        ReciboDeEtapa.Llegada llegada = recibo.recibir(t.pedidoId(), etapa);
        metricas.counter("etapa.entregas", "etapa", etapa, "llegada", llegada.name().toLowerCase()).increment();
        if (llegada == ReciboDeEtapa.Llegada.REPETIDO) {
            // Ya terminó: no se repite el efecto. Se vuelve a avisar por si el
            // aviso anterior se perdió; ventas ignora el cierre repetido.
            registro.pedido("etapa.entrega.repetida", t.pedidoId(), etapa, Map.of());
            bus.convertAndSend(Bus.CADENA, Bus.ETAPA_COMPLETADA, new Trabajo(t.pedidoId(), etapa));
            return;
        }
        if (llegada == ReciboDeEtapa.Llegada.RETOMADO) {
            registro.pedido("etapa.entrega.retomada", t.pedidoId(), etapa, Map.of());
        }
        if (porCongelar.getAndUpdate(n -> n > 0 ? n - 1 : 0) > 0) {
            // t0 de D3: el pedido entra a la etapa viva, con su recibo, y se queda
            // quieto. El mensaje se confirma: para el bróker, la etapa ya lo tiene.
            registro.anotar(Instant.now(), "falla.congelada", null, t.pedidoId(), etapa, Map.of());
            return;
        }
        enCurso.add(t.pedidoId());
        long inicio = System.nanoTime();
        try {
            Thread.sleep(duracion.siguienteMs());
            if (recibo.terminar(t.pedidoId(), etapa)) {
                registro.pedido("etapa.efecto.aplicado", t.pedidoId(), etapa, Map.of());
            }
            bus.convertAndSend(Bus.CADENA, Bus.ETAPA_COMPLETADA, new Trabajo(t.pedidoId(), etapa));
        } finally {
            enCurso.remove(t.pedidoId());
            tiempo.record(System.nanoTime() - inicio, TimeUnit.NANOSECONDS);
        }
    }

    /**
     * El punto que sondea el Monitor («ping/echo» con datos). Además de responder,
     * informa cuántos pedidos tiene en curso, la edad del más viejo y los que
     * llevan más de mayorQueMs sin terminar. La etapa informa; el umbral lo pone
     * el Monitor. Si la base no responde, esto falla y el Monitor lo cuenta como
     * sondeo sin respuesta.
     */
    @GetMapping("/salud")
    Map<String, Object> salud(@RequestParam(defaultValue = "0") long mayorQueMs) {
        List<Map<String, Object>> pedidos = recibo.enCurso(etapa);
        long masAntiguoMs = pedidos.isEmpty() ? 0 : ((Number) pedidos.get(0).get("edadMs")).longValue();
        List<Map<String, Object>> atascados = mayorQueMs <= 0 ? List.of() : pedidos.stream()
                .filter(p -> ((Number) p.get("edadMs")).longValue() > mayorQueMs)
                .toList();
        Map<String, Object> salud = new LinkedHashMap<>();
        salud.put("etapa", etapa);
        salud.put("enCurso", pedidos.size());
        salud.put("masAntiguoMs", masAntiguoMs);
        salud.put("atascados", atascados);
        return salud;
    }

    @PostMapping("/fallas/congelar")
    ResponseEntity<Map<String, Object>> congelar() {
        int pendientes = porCongelar.incrementAndGet();
        return ResponseEntity.accepted().body(Map.of("etapa", etapa, "porCongelar", pendientes));
    }
}
