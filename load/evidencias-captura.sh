#!/usr/bin/env bash
# Captura de un caso de load/evidencias.sh en una sola pantalla, con foto y video.
# Solo macOS: usa Terminal, Google Chrome, screencapture y avconvert.
#
# Arriba, dos terminales: el estímulo a la izquierda y la respuesta del sistema a
# la derecha. Abajo, el tablero de evidencias de Grafana y, si el caso lo pide, la
# consola de RabbitMQ. Antes de abrir, la pila debe estar arriba y, para los
# casos de E02, con la carga de fondo corriendo (make carga).
#
#   load/evidencias-captura.sh abrir "<izquierda>" <caso> <url-grafana> [url-rabbitmq|-] [segundos de video]
#     <izquierda> es lo que corre load/evidencias.sh a la izquierda: el caso de la demo, o «vivo e01»
#     durante una corrida de decisión; <caso> elige los logs de la derecha (load/evidencias.sh mirar).
#   load/evidencias-captura.sh foto <archivo.png>
#   load/evidencias-captura.sh cerrar <archivo.mp4>
set -euo pipefail
cd "$(dirname "$0")/.."
R=$PWD
ESTADO=${TMPDIR:-/tmp}/evidencias-captura
mkdir -p "$ESTADO"
# Pantalla en puntos, sin la barra de menú: 1512 × 957 en un MacBook Pro de 14".
ANCHO=1512; ARRIBA=25; MITAD=430; ABAJO=982
# Chrome se abre más arriba, detrás de las terminales, para que sus pestañas,
# su barra de direcciones y sus avisos queden tapados: solo se ve la página.
BARRAS=168

chrome() { # url x1 y1 x2 y2 → id de la ventana
  osascript <<OSA
tell application "Google Chrome"
  set w to make new window
  set URL of active tab of w to "$1"
  set bounds of w to {$2, $3, $4, $5}
  return id of w
end tell
OSA
}

case "${1:-}" in
  abrir)
    izquierda=$2; caso=$3; grafana=$4; rabbit=${5:--}; segundos=${6:-60}
    rm -f "$ESTADO"/*
    if [ "$rabbit" = "-" ]; then
      chrome "$grafana" 0 $((MITAD - BARRAS)) $ANCHO $ABAJO > "$ESTADO/chrome"
    else
      chrome "$grafana" 0 $((MITAD - BARRAS)) 940 $ABAJO > "$ESTADO/chrome"
      chrome "$rabbit" 940 $((MITAD - BARRAS)) $ANCHO $ABAJO >> "$ESTADO/chrome"
    fi
    osascript > "$ESTADO/terminal" <<OSA
tell application "Terminal"
  activate
  set t1 to do script ""
  set w1 to front window
  set bounds of w1 to {$((ANCHO / 2)), $ARRIBA, $ANCHO, $MITAD}
  set t2 to do script ""
  set w2 to front window
  set bounds of w2 to {0, $ARRIBA, $((ANCHO / 2)), $MITAD}
  delay 6
  do script "cd $R && clear && load/evidencias.sh mirar $caso" in t1
  delay 3
  return (id of w1 as text) & " " & (id of w2 as text)
end tell
OSA
    nohup screencapture -x -v -V"$segundos" -R0,$ARRIBA,$ANCHO,$((ABAJO - ARRIBA)) "$ESTADO/video.mov" \
      >/dev/null 2>&1 &
    echo $! > "$ESTADO/grabando"
    disown
    sleep 2
    w2=$(cut -d' ' -f2 "$ESTADO/terminal")
    osascript -e "tell application \"Terminal\" to do script \"cd $R && clear && load/evidencias.sh $izquierda\" in (selected tab of (first window whose id is $w2))" >/dev/null
    echo "grabando $segundos s; la foto se toma con: $0 foto <archivo.png>"
    ;;
  foto)
    screencapture -x -R0,$ARRIBA,$ANCHO,$((ABAJO - ARRIBA)) "$2"
    echo "foto: $2"
    ;;
  cerrar)
    while kill -0 "$(cat "$ESTADO/grabando")" 2>/dev/null; do sleep 1; done
    pkill -f "logs -f --since 1s" || true
    for i in $(cat "$ESTADO/terminal"); do
      osascript -e "tell application \"Terminal\" to close (every window whose id is $i) saving no" >/dev/null 2>&1 || true
    done
    for i in $(cat "$ESTADO/chrome"); do
      osascript -e "tell application \"Google Chrome\" to close (every window whose id is $i)" >/dev/null 2>&1 || true
    done
    avconvert -s "$ESTADO/video.mov" -p Preset1920x1080 -o "$2" --replace >/dev/null
    echo "video: $2 ($(du -h "$2" | cut -f1))"
    ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
