package co.mati.reto2.ventas;

import co.mati.reto2.comun.Http;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Envía el trabajo a las tres etapas en paralelo (D-10). La etapa responde 202 y
 * avisa al terminar, así que una etapa detenida no le devuelve a ventas ningún
 * error sobre el pedido: el pedido simplemente no vuelve, que es la falla que
 * describe ASR-3. Si el envío mismo falla, la fila queda en curso y ventas no
 * reintenta; detectar eso es trabajo del Monitor.
 */
@Component
class Despachador {

    private static final Logger log = LoggerFactory.getLogger(Despachador.class);
    private static final Duration ESPERA = Duration.ofSeconds(1);

    private final Map<String, RestClient> etapas;
    private final RestClient logistica;
    private final Registro registro;
    private final MeterRegistry metricas;
    private final ExecutorService ejecutor = Executors.newVirtualThreadPerTaskExecutor();

    Despachador(Registro registro, MeterRegistry metricas,
                @Value("${FACTURACION_URL:http://localhost:8091}") String facturacion,
                @Value("${INVENTARIO_URL:http://localhost:8092}") String inventario,
                @Value("${DESPACHO_URL:http://localhost:8093}") String despacho,
                @Value("${LOGISTICA_URL:http://localhost:8094}") String logistica) {
        this.registro = registro;
        this.metricas = metricas;
        this.etapas = Map.of(
                "facturacion", Http.cliente(facturacion, ESPERA),
                "inventario", Http.cliente(inventario, ESPERA),
                "despacho", Http.cliente(despacho, ESPERA));
        this.logistica = Http.cliente(logistica, Duration.ofSeconds(2));
    }

    void enviar(String pedidoId) {
        etapas.forEach((etapa, cliente) -> ejecutor.submit(() -> {
            try {
                cliente.post().uri("/trabajos").body(Map.of("pedidoId", pedidoId)).retrieve().toBodilessEntity();
            } catch (RuntimeException ex) {
                metricas.counter("ventas.envio.fallido", "etapa", etapa).increment();
                registro.pedido("etapa.envio.fallido", pedidoId, etapa, Map.of("error", String.valueOf(ex.getMessage())));
            }
        }));
    }

    void aLogistica(String pedidoId) {
        ejecutor.submit(() -> {
            try {
                logistica.post().uri("/pedidos").body(Map.of("pedidoId", pedidoId)).retrieve().toBodilessEntity();
            } catch (RuntimeException ex) {
                log.warn("logística no recibió {}: {}", pedidoId, ex.getMessage());
            }
        });
    }
}
