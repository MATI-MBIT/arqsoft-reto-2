package co.mati.reto2.sesiones;

import java.time.Instant;

record SesionAbierta(String sesionId, String vendedorId, String dispositivoId, Instant abiertaEn) {}
