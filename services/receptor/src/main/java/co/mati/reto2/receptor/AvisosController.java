package co.mati.reto2.receptor;

import co.mati.reto2.comun.Registro;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Instant;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * ROL=sms. El receptor simulado del SMS de seguridad: anota la hora de llegada
 * de cada aviso, que es el t1 de E01. Un proveedor real sumaría su propia
 * demora, que ningún componente del diseño controla.
 */
@RestController
@ConditionalOnProperty(name = "ROL", havingValue = "sms")
class AvisosController {

    private final Registro registro;
    private final Counter recibidos;
    private final Counter incompletos;

    AvisosController(Registro registro, MeterRegistry metricas) {
        this.registro = registro;
        this.recibidos = metricas.counter("receptor.avisos.recibidos");
        this.incompletos = metricas.counter("receptor.avisos.incompletos");
    }

    record Aviso(String sesionId, String vendedorId, String dispositivoId, String hora) {}

    @PostMapping("/avisos")
    ResponseEntity<Void> recibir(@RequestBody Aviso a) {
        Instant llegada = Instant.now();
        boolean completo = presente(a.vendedorId()) && presente(a.dispositivoId()) && presente(a.hora());
        registro.anotar(llegada, "aviso.recibido", a.sesionId(), null, null, Map.of(
                "completo", completo,
                "vendedorId", String.valueOf(a.vendedorId()),
                "dispositivoId", String.valueOf(a.dispositivoId()),
                "hora", String.valueOf(a.hora())));
        recibidos.increment();
        if (!completo) {
            incompletos.increment();
        }
        return ResponseEntity.accepted().build();
    }

    private static boolean presente(String v) {
        return v != null && !v.isBlank();
    }
}
