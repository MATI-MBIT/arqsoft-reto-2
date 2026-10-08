# ==============================================================================
# El orquestador de los experimentos E01 y E02, para Windows. Hace lo mismo que
# load/experimento.sh, paso por paso; si se cambia uno, se cambia el otro.
#
# QUÉ se corre es dato (load/plan.tsv); CÓMO se corre es este archivo. Cada
# corrida sigue el mismo ciclo:
#
#   1. preparar   etapas arriba, operación reiniciada, colas vacías y el Monitor
#                 recreado con el T y el N de la fila
#   2. calentar   la carga de fondo corre WARMUP_S; nada de esto entra al veredicto
#   3. medir      E01: la fase de k6 · E02: D1_S sin fallas, REPS caídas, CONGELAR
#                 congelamientos, en ese orden
#   4. cerrar     GRACIA_S más con carga, para que lleguen las salidas tardías
#   5. veredicto  analisis/e01.sql o e02.sql sobre el registro de eventos
#
# Uso:  .\load\experimento.ps1                 # el plan completo
#       .\load\experimento.ps1 e01 e02         # los grupos que se indiquen
#       .\load\experimento.ps1 humo            # el humo (~7 min)
# ==============================================================================
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Grupos = @())

. (Join-Path $PSScriptRoot 'comun.ps1')

$Plan = Join-Path $Raiz 'load\plan.tsv'
$K6Dir = Join-Path $Raiz 'load\k6'
$Stamp = if ($env:STAMP) { $env:STAMP } else { Get-Date -Format 'yyyyMMdd-HHmmss' }   # el e2e lo fija
$Resultados = Join-Path $Raiz 'analisis\resultados'
$Resumen = Join-Path $Resultados "resumen-$Stamp.tsv"
New-Item -ItemType Directory -Force -Path $Resultados | Out-Null

# k6 empuja sus métricas a Prometheus para verlas junto a las de los micros.
if (-not $env:K6_PROMETHEUS_RW_SERVER_URL) { $env:K6_PROMETHEUS_RW_SERVER_URL = 'http://localhost:9090/api/v1/write' }
if (-not $env:K6_PROMETHEUS_RW_TREND_STATS) { $env:K6_PROMETHEUS_RW_TREND_STATS = 'p(50),p(95),p(99),max' }
if (-not $env:K6_PROMETHEUS_RW_PUSH_INTERVAL) { $env:K6_PROMETHEUS_RW_PUSH_INTERVAL = '5s' }

# Cada k6 de la corrida expone su API en un puerto propio: así se detiene la
# carga de fondo sin tocar la fase que corre al lado.
$PuertoCadena = 6566
$PuertoFase = 6565

# Una corrida suspendida queda contaminada: la máquina de Docker se congela, k6
# deja de generar llegadas y los relojes saltan. Con batería no se arranca,
# salvo FORZAR_BATERIA=1: un portátil con batería se suspende aunque se pida lo
# contrario.
try {
    $bateria = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop | Select-Object -First 1
    # BatteryStatus 1 = descargando: el equipo no está conectado a la corriente.
    if ($bateria -and $bateria.BatteryStatus -eq 1 -and $env:FORZAR_BATERIA -ne '1') {
        Write-Host 'El equipo está con batería y Windows puede suspenderlo a mitad de la corrida.'
        Write-Host 'Conéctalo a la corriente, o corre con $env:FORZAR_BATERIA=1 bajo tu propio riesgo.'
        exit 1
    }
} catch { }
Start-SinSuspender

# Hueco máximo admitido entre dos pedidos de la carga de fondo (1 por segundo).
# En corridas sanas no pasa de 13 s; uno mayor que el plazo de ASR-3 (30 s) solo
# sale si la máquina se congeló. En Windows se mira además el registro de
# suspensiones. Una corrida contaminada no se retoma: se marca inválida y el
# ciclo completo vuelve a empezar desde la primera corrida, hasta REINTENTOS
# veces, para que todas las corridas de un ciclo corran seguidas.
$HuecoMax = if ($env:HUECO_MAX_S) { [double]$env:HUECO_MAX_S } else { 30 }
$Reintentos = if ($env:REINTENTOS) { [int]$env:REINTENTOS } else { 1 }

function Invoke-Preparar([hashtable]$V) {
    # Toda la topología arriba, no solo las etapas: si Docker se reinició (una
    # actualización automática lo hizo a mitad de una corrida el 2026-10-07), la
    # base y el bróker también cayeron.
    Invoke-Compose up -d *> $null
    foreach ($p in $Micros) { if (-not (Wait-Salud $p)) { return $false } }
    Invoke-Sql -c 'SELECT operacion.reiniciar()' | Out-Null
    # Las colas se vacían para que el trabajo pendiente de una corrida no llegue a la siguiente.
    foreach ($cola in 'verificador.sesiones notificador.alertas etapa.facturacion etapa.inventario etapa.despacho ventas.completadas logistica.pedidos dead-letter-queue dead-letter-queue.auditoria'.Split(' ')) {
        Invoke-Compose exec -T rabbitmq rabbitmqctl -q purge_queue $cola *> $null
    }
    # El Monitor se recrea en cada corrida: arranca sin cuentas viejas y con el T y N de la fila.
    $env:SONDEO_T_MS = $V.SONDEO_T_MS
    $env:SONDEO_N = $V.SONDEO_N
    $env:SONDEO_ESPERA_MS = $V.SONDEO_ESPERA_MS
    Invoke-Compose up -d --force-recreate --no-deps monitor *> $null
    return (Wait-Salud 8095)
}

# Las caídas de D2 se reparten por igual entre las tres etapas, en orden aleatorio.
function Get-OrdenDeEtapas([int]$Cuantas) {
    $etapas = @('facturacion', 'inventario', 'despacho')
    $lista = for ($i = 0; $i -lt $Cuantas; $i++) { $etapas[$i % 3] }
    return @($lista | Sort-Object { Get-Random })
}

function Invoke-MedirE02([hashtable]$V, [string]$Dir) {
    $log = Join-Path $Dir 'inyector.log'
    if ([int]$V.D1_S -gt 0) {
        Write-Log "  D1: $($V.D1_S) s sin fallas"
        Start-Sleep -Seconds ([int]$V.D1_S)
    }
    if ([int]$V.REPS -gt 0) {
        $i = 0
        foreach ($etapa in (Get-OrdenDeEtapas ([int]$V.REPS))) {
            $i++
            Write-Log "  D2 $i/$($V.REPS): se mata $etapa por $($V.CAIDA_S) s"
            $salida = & docker exec inyector inyectar matar $etapa $V.CAIDA_S 2>&1
            Add-Utf8 $log $salida
            if ($LASTEXITCODE -ne 0) { Write-Log "  la etapa $etapa no volvió: ver $log" }
            Start-Sleep -Seconds ([int]$V.PAUSA_S)
        }
    }
    if ([int]$V.CONGELAR -gt 0) {
        $i = 0
        foreach ($etapa in (Get-OrdenDeEtapas ([int]$V.CONGELAR))) {
            $i++
            Write-Log "  D3 $i/$($V.CONGELAR): se congela el próximo pedido de $etapa"
            $salida = & docker exec inyector inyectar congelar $etapa 2>&1
            Add-Utf8 $log $salida
            Start-Sleep -Seconds ([int]$V.ESPACIO_S)
        }
    }
}

function Start-K6([string]$Guion, [int]$Puerto, [string]$Salida, [string[]]$Extra, [switch]$Esperar) {
    $argumentos = @('run', '-q', '-o', 'experimental-prometheus-rw', '--address', "localhost:$Puerto") + $Extra + @($Guion)
    $p = Start-Process -FilePath 'k6' -ArgumentList $argumentos -WorkingDirectory $K6Dir -NoNewWindow -PassThru `
        -RedirectStandardOutput $Salida -RedirectStandardError ($Salida -replace '\.txt$', '.err.txt')
    if ($Esperar) { $p.WaitForExit() }
    return $p
}

function Invoke-Corrida($Fila) {
    # Valores por omisión; la fila los sobrescribe.
    $V = @{
        WARMUP_S = '300'; TASA_BASE = '2'; SONDEO_T_MS = '2000'; SONDEO_N = '3'; SONDEO_ESPERA_MS = '500'
        D1_S = '0'; REPS = '0'; CAIDA_S = '45'; PAUSA_S = '30'; CONGELAR = '0'; ESPACIO_S = '60'; GRACIA_S = '60'
    }
    if ($Fila.Vars -ne '-') {
        foreach ($kv in $Fila.Vars.Split(';')) {
            $partes = $kv.Split('=', 2)
            $V[$partes[0]] = $partes[1]
        }
    }

    $corrida = "$($Fila.Id)-$Stamp"
    $dir = Join-Path $Resultados $corrida
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Log "== $corrida · $($Fila.Experimento) $($Fila.Fase) · $($Fila.Pregunta)"

    if (-not (Invoke-Preparar $V)) { Write-Log 'no se pudo preparar la topología'; return $true }

    # Las variables se arman con jsonb_build_object: sin comillas dobles, que 5.1
    # pierde al pasar el SQL a docker.
    $variables = "jsonb_build_object('T_ms', $($V.SONDEO_T_MS), 'N', $($V.SONDEO_N), 'espera_ms', $($V.SONDEO_ESPERA_MS), " +
        "'tasa_base', $($V.TASA_BASE), 'd1_s', $($V.D1_S), 'caidas', $($V.REPS), 'caida_s', $($V.CAIDA_S), " +
        "'congelar', $($V.CONGELAR), 'vars', '$($Fila.Vars)')"
    Invoke-Sql -c ("INSERT INTO registro.corrida (id, experimento, fase, variables, arranque) " +
        "VALUES ('$corrida', '$($Fila.Experimento)', '$($Fila.Fase)', $variables, clock_timestamp())") | Out-Null

    # La carga de fondo del Ambiente A corre durante toda la corrida. La etiqueta
    # guion separa las series de los dos k6: con la misma etiqueta, Prometheus
    # rechaza el lote entero por muestras duplicadas.
    $cadena = Start-K6 'cadena.js' $PuertoCadena (Join-Path $dir 'k6-cadena.txt') `
        @('--tag', "corrida=$corrida", '--tag', 'guion=cadena', '-e', "CORRIDA=$corrida")

    Write-Log "  calentamiento: $($V.WARMUP_S) s"
    if ($Fila.Experimento -eq 'E01') {
        Start-K6 'e01.js' $PuertoFase (Join-Path $dir 'k6-calentamiento.txt') `
            @('--tag', "corrida=$corrida", '--tag', 'guion=e01', '-e', "CORRIDA=$corrida",
              '-e', 'FASE=CALENTAMIENTO', '-e', "DURACION=$($V.WARMUP_S)s", '-e', "TASA_BASE=$($V.TASA_BASE)") -Esperar | Out-Null
    } else {
        Start-Sleep -Seconds ([int]$V.WARMUP_S)
    }
    Invoke-Sql -c "UPDATE registro.corrida SET inicio = clock_timestamp() WHERE id = '$corrida'" | Out-Null

    if ($Fila.Experimento -eq 'E01') {
        Write-Log "  fase $($Fila.Fase) en k6"
        Start-K6 'e01.js' $PuertoFase (Join-Path $dir "k6-$($Fila.Fase).txt") `
            @('--tag', "corrida=$corrida", '--tag', 'guion=e01', '-e', "CORRIDA=$corrida",
              '-e', "FASE=$($Fila.Fase)", '-e', "TASA_BASE=$($V.TASA_BASE)") -Esperar | Out-Null
    } else {
        Invoke-MedirE02 $V $dir
    }
    Invoke-Sql -c "UPDATE registro.corrida SET fin = clock_timestamp() WHERE id = '$corrida'" | Out-Null

    Write-Log "  gracia: $($V.GRACIA_S) s para las salidas tardías"
    Start-Sleep -Seconds ([int]$V.GRACIA_S)
    Stop-K6 $PuertoCadena $cadena
    Start-Sleep -Seconds 1   # el registro de cada micro se vacía cada 200 ms

    $exp = $Fila.Experimento.ToLower()
    $veredicto = Join-Path $dir 'veredicto.txt'
    Write-Utf8 $veredicto (Invoke-Compose exec -T postgres psql -U reto2 -d reto2 -v "corrida=$corrida" -f "/analisis/$exp.sql" 2>&1)
    Write-Utf8 (Join-Path $dir "eventos-$corrida.csv") (Invoke-Sql -c ("\copy (SELECT e.* FROM registro.evento e, registro.corrida c " +
        "WHERE c.id = '$corrida' AND e.ts BETWEEN c.arranque AND c.fin + interval '$($V.GRACIA_S) seconds' ORDER BY e.ts) " +
        'TO STDOUT WITH CSV HEADER'))
    Copy-Item $Plan (Join-Path $dir 'plan.tsv')

    # Enlaces a los tableros fijados en la ventana de la corrida: la evidencia
    # visual se puede volver a abrir mientras Prometheus conserve la serie (15 d).
    $desde = (Invoke-Sql -c "SELECT (extract(epoch FROM arranque) * 1000)::bigint FROM registro.corrida WHERE id = '$corrida'") -join ''
    $hasta = (Invoke-Sql -c "SELECT (extract(epoch FROM fin + interval '$($V.GRACIA_S) seconds') * 1000)::bigint FROM registro.corrida WHERE id = '$corrida'") -join ''
    Write-Utf8 (Join-Path $dir 'tablero.txt') @(
        "tablero  http://localhost:3000/d/$($exp)?from=$desde&to=$hasta",
        "kiosco   http://localhost:3000/d/$($exp)?from=$desde&to=$hasta&kiosk")

    # Validez: si la máquina se congeló, la carga de fondo deja un hueco.
    $huecoTexto = ((Invoke-Sql -c ("SELECT coalesce(round(extract(epoch FROM max(hueco))::numeric, 1), 0) FROM " +
        "(SELECT e.ts - lag(e.ts) OVER (ORDER BY e.ts) AS hueco FROM registro.evento e, registro.corrida c " +
        "WHERE c.id = '$corrida' AND e.tipo = 'pedido.confirmado' AND e.ts BETWEEN c.arranque AND c.fin) x")) -join '').Trim()
    # Sin respuesta de la base, la corrida no se puede validar: se da por contaminada.
    $hueco = 0.0
    if (-not [double]::TryParse($huecoTexto, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hueco)) { $hueco = 9999 }
    $suspensiones = 0
    try {
        $epoch = [long]((Invoke-Sql -c "SELECT extract(epoch FROM arranque)::bigint FROM registro.corrida WHERE id = '$corrida'") -join '')
        $desde = [DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime
        # Evento 42 de Kernel-Power: el equipo entra en suspensión.
        $suspensiones = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 42; StartTime = $desde } -ErrorAction Stop).Count
    } catch { }
    # La carga también tiene que ser la del diseño: si un k6 de la medición tuvo
    # más de 1 % de solicitudes fallidas, la corrida no midió el Ambiente A.
    $fallidas = 0.0
    foreach ($k in (Join-Path $dir 'k6-cadena.txt'), (Join-Path $dir "k6-$($Fila.Fase).txt")) {
        if (Test-Path $k) {
            $m = Select-String -Path $k -Pattern 'http_req_failed\S*\s*([0-9.]+)%' -Encoding UTF8 | Select-Object -First 1
            if ($m) { $fallidas = [math]::Max($fallidas, [double]$m.Matches[0].Groups[1].Value) }
        }
    }
    if ($suspensiones -gt 0 -or $hueco -gt $HuecoMax -or $fallidas -gt 1) {
        Invoke-Sql -c ("UPDATE registro.corrida SET valida = false, motivo = 'corrida inválida: hueco de $hueco s en la " +
            "carga de fondo, $suspensiones suspensiones del equipo, $fallidas % de solicitudes de k6 fallidas' WHERE id = '$corrida'") | Out-Null
        Rename-Item -Path $dir -NewName "$corrida-contaminada"
        Write-Log "  CONTAMINADA: hueco de $hueco s (máximo $HuecoMax s), $suspensiones suspensiones, $fallidas % de solicitudes fallidas (máximo 1 %). Se descarta: analisis\resultados\$corrida-contaminada"
        return $false
    }

    $lineas = @(Select-String -Path $veredicto -Pattern '\| (PASA|FALLA|NO APLICA) *$' -Encoding UTF8 | ForEach-Object { $_.Line })
    foreach ($linea in $lineas) {
        Add-Utf8 $Resumen ("{0}`t{1}`t{2}`t{3}" -f $corrida, $Fila.Criterio, $Fila.Fase, $linea)
    }
    Write-Log "  veredicto en analisis\resultados\$corrida\veredicto.txt"
    $lineas | ForEach-Object { Write-Host "     $_" }
    return $true
}

# Sin argumentos corre todo menos el humo.
function Test-Pertenece([string]$Grupo) {
    if ($Grupos.Count -eq 0) { return ($Grupo -ne 'humo') }
    return ($Grupos -contains $Grupo)
}

# Un ciclo recorre el plan en orden. Si una corrida sale contaminada, devuelve
# $false y el ciclo entero se repite con un sello nuevo.
function Invoke-Ciclo {
    Write-Log "resultados en analisis\resultados\ · resumen en analisis\resultados\resumen-$Stamp.tsv"
    $filas = Get-Content -Path $Plan -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') }
    foreach ($linea in $filas) {
        $c = $linea.Split("`t")
        if ($c.Count -lt 7) { continue }
        $fila = [pscustomobject]@{
            Grupo = $c[0]; Id = $c[1]; Experimento = $c[2]; Fase = $c[3]; Criterio = $c[4]; Vars = $c[5]; Pregunta = $c[6]
        }
        if (-not (Test-Pertenece $fila.Grupo)) { continue }
        # La función devuelve todo lo que sale por su tubería: vale su último valor.
        $resultado = @(Invoke-Corrida $fila)
        if ($resultado.Count -gt 0 -and $resultado[-1] -eq $false) { return $false }
    }
    return $true
}

$base = $Stamp
for ($intento = 0; $intento -le $Reintentos; $intento++) {
    if ($intento -gt 0) {
        $Stamp = "$base-r$intento"
        $Resumen = Join-Path $Resultados "resumen-$Stamp.tsv"
        Write-Log "== se reinicia el ciclo completo (reintento $intento de $Reintentos)"
    }
    $ok = @(Invoke-Ciclo)
    if ($ok.Count -gt 0 -and $ok[-1] -eq $true) { break }
    if ($intento -eq $Reintentos) { Write-Log "el ciclo sigue contaminado tras $Reintentos reintentos: no hay veredicto válido" }
}

Write-Log 'listo. Resumen:'
if (Test-Path $Resumen) {
    Get-Content $Resumen -Encoding UTF8 | ForEach-Object { Write-Host "  $($_ -replace "`t", '  ')" }
}
