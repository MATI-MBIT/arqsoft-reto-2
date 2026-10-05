// Carga de E01: aperturas de sesión, según la fase.
//
//   CALENTAMIENTO  solo aperturas de fondo, durante DURACION
//   S1             50 aperturas desde un dispositivo no registrado en 30 min
//   S2             100 cambios legítimos: registra el dispositivo nuevo y abre
//                  sesión desde él entre 5 y 60 s después
//   S3             20 cambios con la apertura a menos de 1 s del registro
//   S4             fondo a 1, 3 y 5 veces la tasa base, 10 min por nivel, con
//                  10 intrusos en cada nivel
//   SMOKE          una versión de 100 s de S1, S2 y S3 juntas
//
// En todas corre el fondo: aperturas desde el dispositivo registrado a
// TASA_BASE por segundo (supuesto S-10). Ningún fondo debe producir aviso.
//
// El identificador de cada sesión lleva la fase y el tipo como prefijo
// (<FASE>-<TIPO>-<corrida>-...). El micro lo trata como opaco; el análisis
// sabe por él qué esperaba de cada sesión.
//
// Los vendedores se reparten para que las fases no se pisen:
//   V0001–V1000 fondo · V1001–V1100 S2 · V1201–V1220 S3 · V1501–V2000 intrusos
//
// Uso: k6 run -e FASE=S1 -e CORRIDA=<id> e01.js
import { check, sleep } from 'k6';
import exec from 'k6/execution';
import { CORRIDA, ONBOARDING, SESIONES, entero, postJson, uniforme, vendedor } from './comun.js';

const FASE = (__ENV.FASE || 'S1').toUpperCase();
const BASE = Number(__ENV.TASA_BASE || 2);
const NIVEL_S = Number(__ENV.NIVEL_S || 600);

function deFondo(duracion, prefijo = 'FONDO') {
  return {
    executor: 'constant-arrival-rate', exec: 'fondo', env: { PREFIJO: prefijo },
    rate: BASE, timeUnit: '1s', duration: duracion, preAllocatedVUs: 10, maxVUs: 100,
  };
}

// Exactamente `cuantos` llegadas en `ventanaS` segundos: la ventana se parte en
// turnos iguales y cada llegada cae en un momento aleatorio de su turno. Un
// executor de tasa de llegada daría una iteración de más en el borde, y el
// criterio de S1 cuenta 50, no 51.
function repartidas(fn, cuantos, ventanaS, prefijo, extra = {}) {
  return {
    executor: 'shared-iterations', exec: fn, vus: cuantos, iterations: cuantos,
    maxDuration: `${ventanaS + 120}s`,
    env: Object.assign({ PREFIJO: prefijo, TURNO_S: String(ventanaS / cuantos) }, extra),
  };
}

// Espera hasta un momento aleatorio del turno que le toca a esta iteración.
function esperarTurno(fraccion = 1) {
  const turno = Number(__ENV.TURNO_S);
  sleep(exec.scenario.iterationInTest * turno + uniforme(0, turno * fraccion));
}

function escenarios() {
  switch (FASE) {
    case 'CALENTAMIENTO':
      return { fondo: deFondo(__ENV.DURACION || '5m') };
    case 'S1':
      return { fondo: deFondo('31m'), intrusos: repartidas('intruso', 50, 1800, 'S1') };
    case 'S2':
      return {
        fondo: deFondo('22m'),
        cambios: repartidas('cambio', 100, 1200, 'S2', { ESPERA_MIN: '5', ESPERA_MAX: '60', DESDE: '1001' }),
      };
    case 'S3':
      return {
        fondo: deFondo('6m'),
        pegados: repartidas('cambio', 20, 300, 'S3', { ESPERA_MIN: '0', ESPERA_MAX: '0.9', DESDE: '1201' }),
      };
    case 'S4': {
      const n = `${NIVEL_S}s`;
      const e = {
        fondo: {
          executor: 'ramping-arrival-rate', exec: 'fondoPorNivel', startRate: BASE, timeUnit: '1s',
          preAllocatedVUs: 20, maxVUs: 300,
          stages: [
            { duration: n, target: BASE }, { duration: '1s', target: 3 * BASE },
            { duration: n, target: 3 * BASE }, { duration: '1s', target: 5 * BASE },
            { duration: n, target: 5 * BASE },
          ],
        },
      };
      [1, 3, 5].forEach((nivel, i) => {
        e[`intrusos_${nivel}x`] = Object.assign(repartidas('intruso', 10, NIVEL_S, `S4N${nivel}`),
          { startTime: `${i * (NIVEL_S + 1)}s` });
      });
      return e;
    }
    case 'SMOKE':
      return {
        fondo: deFondo('100s'),
        intrusos: repartidas('intruso', 5, 60, 'S1'),
        cambios: repartidas('cambio', 5, 60, 'S2', { ESPERA_MIN: '2', ESPERA_MAX: '5', DESDE: '1001' }),
        pegados: repartidas('cambio', 3, 60, 'S3', { ESPERA_MIN: '0', ESPERA_MAX: '0.9', DESDE: '1201' }),
      };
    default:
      throw new Error(`FASE desconocida: ${FASE}`);
  }
}

export const options = {
  scenarios: escenarios(),
  summaryTrendStats: ['med', 'p(95)', 'p(99)', 'max'],
  tags: { corrida: CORRIDA, fase: FASE },
};

function abrir(prefijo, tipo, v, dispositivo) {
  // Escenario e iteración global: únicos en toda la corrida. (vu.idInTest con
  // vu.iterationInInstance se repetía y el micro rechazaba la sesión duplicada.)
  const sesionId = `${prefijo}-${tipo}-${CORRIDA}-${exec.scenario.name}-${exec.scenario.iterationInTest}`;
  const r = postJson(`${SESIONES}/sesiones`,
    { sesionId, vendedorId: v, password: `clave-${v}`, dispositivoId: dispositivo },
    { tipo: tipo.toLowerCase(), name: 'abrir sesion' });
  check(r, { 'sesión abierta': (x) => x.status === 201 });
}

export function fondo() {
  const v = vendedor(entero(1, 1000));
  abrir(__ENV.PREFIJO, 'LEGIT', v, `D-${v}-1`);
}

export function fondoPorNivel() {
  const transcurrido = (Date.now() - exec.scenario.startTime) / 1000;
  const nivel = [1, 3, 5][Math.min(2, Math.floor(transcurrido / (NIVEL_S + 1)))];
  const v = vendedor(entero(1, 1000));
  abrir(`S4N${nivel}`, 'LEGIT', v, `D-${v}-1`);
}

// Credenciales correctas de un vendedor y un dispositivo que no es el suyo.
export function intruso() {
  esperarTurno();
  const v = vendedor(entero(1501, 2000));
  abrir(__ENV.PREFIJO, 'INTRUSO', v, `D-ATACANTE-${entero(1, 1e6)}`);
}

// Cambio legítimo: Onboarding registra el dispositivo nuevo y el vendedor abre
// sesión desde él después de una espera. Cada iteración usa un vendedor distinto.
export function cambio() {
  esperarTurno(0.5);
  const v = vendedor(Number(__ENV.DESDE) + exec.scenario.iterationInTest);
  const nuevo = `D-${v}-${__ENV.PREFIJO}-${exec.scenario.iterationInTest + 2}`;
  const r = postJson(`${ONBOARDING}/vendedores/${v}/dispositivos`, { dispositivoId: nuevo },
    { tipo: 'registro', name: 'registrar dispositivo' });
  check(r, { 'dispositivo registrado': (x) => x.status === 200 });
  sleep(uniforme(Number(__ENV.ESPERA_MIN), Number(__ENV.ESPERA_MAX)));
  abrir(__ENV.PREFIJO, __ENV.PREFIJO === 'S3' ? 'PEGADO' : 'CAMBIO', v, nuevo);
}
