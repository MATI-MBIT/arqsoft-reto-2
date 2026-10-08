package co.mati.reto2.usuarionovalido;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class VerificadorDeDispositivoTest {

    @Test
    void elDispositivoRegistradoCoincide() {
        assertTrue(VerificadorDeDispositivo.coincide("D-V0001-1", "D-V0001-1"));
    }

    @Test
    void otroDispositivoNoCoincide() {
        assertFalse(VerificadorDeDispositivo.coincide("D-V0001-1", "D-ATACANTE-7"));
    }

    @Test
    void unVendedorSinRegistroNoCoincide() {
        assertFalse(VerificadorDeDispositivo.coincide(null, "D-V0001-1"));
    }
}
