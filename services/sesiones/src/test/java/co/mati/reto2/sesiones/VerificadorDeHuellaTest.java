package co.mati.reto2.sesiones;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class VerificadorDeHuellaTest {

    @Test
    void elDispositivoRegistradoCoincide() {
        assertTrue(VerificadorDeHuella.coincide("D-V0001-1", "D-V0001-1"));
    }

    @Test
    void otroDispositivoNoCoincide() {
        assertFalse(VerificadorDeHuella.coincide("D-V0001-1", "D-ATACANTE-7"));
    }

    @Test
    void unVendedorSinRegistroNoCoincide() {
        assertFalse(VerificadorDeHuella.coincide(null, "D-V0001-1"));
    }
}
