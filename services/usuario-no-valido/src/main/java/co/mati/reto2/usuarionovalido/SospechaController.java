package co.mati.reto2.usuarionovalido;

import co.mati.reto2.comun.Http;
import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Duration;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

/**
 * Recibe la sesión cuya huella no coincide y avisa al área de seguridad con lo
 * que necesita para actuar: el vendedor, el dispositivo y la hora (táctica
 * informar a los actores). Matar la sesión, revocar al usuario y escribir los
 * logs quedan fuera del experimento.
 */
@RestController
class SospechaController {

    private final Registro registro;
    private final RestClient sms;
    private final Counter avisos;

    SospechaController(Registro registro, MeterRegistry metricas,
                       @Value("${RECEPTOR_SMS_URL:http://localhost:8083}") String url) {
        this.registro = registro;
        this.sms = Http.cliente(url, Duration.ofSeconds(2));
        this.avisos = metricas.counter("usuario_no_valido.avisos");
    }

    record Sospecha(String sesionId, String vendedorId, String dispositivoId, String abiertaEn) {}

    @PostMapping("/sospechas")
    ResponseEntity<Void> recibir(@RequestBody Sospecha s) {
        registro.sesion("aviso.emitido", s.sesionId(), Map.of("vendedorId", s.vendedorId()));
        sms.post().uri("/avisos")
                .body(Map.of("sesionId", s.sesionId(), "vendedorId", s.vendedorId(),
                        "dispositivoId", s.dispositivoId(), "hora", s.abiertaEn()))
                .retrieve().toBodilessEntity();
        avisos.increment();
        return ResponseEntity.accepted().build();
    }
}
