package co.mati.reto2.monitor;

import static co.mati.reto2.monitor.CuentaDeSondeos.Cambio.DECLARADA_DETENIDA;
import static co.mati.reto2.monitor.CuentaDeSondeos.Cambio.NINGUNO;
import static co.mati.reto2.monitor.CuentaDeSondeos.Cambio.RECUPERADA;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class CuentaDeSondeosTest {

    @Test
    void declaraDetenidaAlEnesimoSondeoSinRespuesta() {
        CuentaDeSondeos c = new CuentaDeSondeos(3);
        assertEquals(NINGUNO, c.registrar(false));
        assertEquals(NINGUNO, c.registrar(false));
        assertEquals(DECLARADA_DETENIDA, c.registrar(false));
        assertTrue(c.detenida());
    }

    @Test
    void unSondeoBuenoEnMedioReiniciaLaCuenta() {
        CuentaDeSondeos c = new CuentaDeSondeos(3);
        c.registrar(false);
        c.registrar(false);
        c.registrar(true);
        assertEquals(NINGUNO, c.registrar(false));
        assertEquals(NINGUNO, c.registrar(false));
        assertFalse(c.detenida());
    }

    @Test
    void declaraUnaSolaVezMientrasSigueDetenida() {
        CuentaDeSondeos c = new CuentaDeSondeos(2);
        c.registrar(false);
        assertEquals(DECLARADA_DETENIDA, c.registrar(false));
        assertEquals(NINGUNO, c.registrar(false));
        assertEquals(NINGUNO, c.registrar(false));
        assertTrue(c.detenida());
    }

    @Test
    void elPrimerSondeoBuenoLaRecupera() {
        CuentaDeSondeos c = new CuentaDeSondeos(1);
        assertEquals(DECLARADA_DETENIDA, c.registrar(false));
        assertEquals(RECUPERADA, c.registrar(true));
        assertFalse(c.detenida());
        assertEquals(0, c.fallidosSeguidos());
    }

    @Test
    void nDebeSerPositivo() {
        assertThrows(IllegalArgumentException.class, () -> new CuentaDeSondeos(0));
    }
}
