package co.mati.reto2.onboarding;

import co.mati.reto2.comun.Registro;
import java.time.Instant;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * Micro Onboarding, simulado: registra el dispositivo nuevo de un vendedor
 * antes de su primer uso, que es como el prototipo representa el cambio
 * legítimo de equipo. Responde después del commit, así que la apertura que
 * llegue luego ya ve el registro (fase S3).
 */
@RestController
class DispositivoController {

    private final JdbcTemplate jdbc;
    private final Registro registro;

    DispositivoController(JdbcTemplate jdbc, Registro registro) {
        this.jdbc = jdbc;
        this.registro = registro;
    }

    record NuevoDispositivo(String dispositivoId) {}

    @PostMapping("/vendedores/{vendedorId}/dispositivos")
    ResponseEntity<Void> registrar(@PathVariable String vendedorId, @RequestBody NuevoDispositivo r) {
        int filas = jdbc.update(
                "UPDATE operacion.vendedor SET dispositivo_registrado = ?, registrado_en = now() WHERE id = ?",
                r.dispositivoId(), vendedorId);
        if (filas == 0) {
            return ResponseEntity.notFound().build();
        }
        registro.anotar(Instant.now(), "dispositivo.registrado", null, null, null,
                Map.of("vendedorId", vendedorId, "dispositivoId", r.dispositivoId()));
        return ResponseEntity.ok().build();
    }
}
