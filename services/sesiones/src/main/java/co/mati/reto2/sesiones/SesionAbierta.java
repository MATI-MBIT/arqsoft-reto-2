package co.mati.reto2.sesiones;

/** El evento sesion.abierta que el Gestor de sesión publica en el bróker. */
record SesionAbierta(String sesionId, String vendedorId, String dispositivoId, String abiertaEn) {}
