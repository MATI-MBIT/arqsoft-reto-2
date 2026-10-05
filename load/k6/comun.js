// Piezas comunes de los guiones de carga de E01 y E02.
import http from 'k6/http';

export const SESIONES = __ENV.SESIONES_URL || 'http://localhost:8081';
export const ONBOARDING = __ENV.ONBOARDING_URL || 'http://localhost:8084';
export const VENTAS = __ENV.VENTAS_URL || 'http://localhost:8090';

// Identifica la corrida en cada sesión y cada pedido. El análisis cruza por
// identificador, así que dos corridas no pueden compartir uno.
export const CORRIDA = __ENV.CORRIDA || `manual-${Date.now()}`;

const JSON_HDR = { headers: { 'Content-Type': 'application/json' } };

export function postJson(url, cuerpo, tags) {
  return http.post(url, JSON.stringify(cuerpo), Object.assign({ tags }, JSON_HDR));
}

// Retardo exponencial de media `media` segundos. Los executors de tasa de
// llegada de k6 reparten las llegadas a intervalos fijos; el retardo las
// vuelve aleatorias conservando la tasa media, como en el reto 1.
export function exponencial(media) {
  return -Math.log(1 - Math.random()) * media;
}

export function uniforme(min, max) {
  return min + Math.random() * (max - min);
}

export function vendedor(n) {
  return 'V' + String(n).padStart(4, '0');
}

export function entero(min, max) {
  return min + Math.floor(Math.random() * (max - min + 1));
}
