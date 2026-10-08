# ==============================================================================
# arqsoft-reto-2 — el Makefile para Windows.
#
# Los mismos objetivos y la misma sintaxis que el Makefile de macOS y Linux:
#   cmd:         make smoke        make grupo G=e01        make veredicto CORRIDA=...
#   PowerShell:  .\make smoke      .\make grupo G=e01
#
# `make` en cmd encuentra make.bat en esta carpeta, que llama a este archivo.
# QUÉ se corre vive en load/plan.tsv; CÓMO se corre, en load/experimento.ps1.
# Aquí solo hay atajos. Si se cambia un objetivo aquí, se cambia en el Makefile.
# ==============================================================================
param(
    [Parameter(Position = 0)][string]$Objetivo = 'help',
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Resto = @()
)

. (Join-Path $PSScriptRoot 'load\comun.ps1')

# Los argumentos van como en make: G=e01, CORRIDA=..., ETAPA=..., CAIDA=..., S=...
$Var = @{}
foreach ($kv in $Resto) {
    if ($kv -match '^([A-Za-z_]+)=(.*)$') { $Var[$Matches[1]] = $Matches[2] }
}
function Get-Var([string]$Nombre, [string]$PorOmision = '') {
    if ($Var.ContainsKey($Nombre) -and $Var[$Nombre]) { return $Var[$Nombre] }
    return $PorOmision
}

$Gradle = Join-Path $Raiz 'gradlew.bat'
$Orquestador = Join-Path $Raiz 'load\experimento.ps1'

function Invoke-Gradle {
    & $Gradle @args
    if ($LASTEXITCODE -ne 0) { throw "gradle falló ($LASTEXITCODE)" }
}

function Invoke-Orquestador([string[]]$Grupos) {
    & $Orquestador @Grupos
}

# --- Los objetivos, con su grupo y su ayuda, en el orden del Makefile --------
$Objetivos = [ordered]@{}
function Add-Objetivo([string]$Grupo, [string]$Nombre, [string]$Ayuda, [scriptblock]$Accion) {
    $Objetivos[$Nombre] = [pscustomobject]@{ Grupo = $Grupo; Ayuda = $Ayuda; Accion = $Accion }
}

$GExp = 'Experimentos — lo que valida las hipótesis'
$GObs = 'Observabilidad — la evidencia en vivo'
$GFal = 'Fallas a mano — para probar el montaje, no para medir'
$GTop = 'Topología'
$GCom = 'Compilación'

Add-Objetivo $GExp 'plan' 'Lista las corridas del plan y a qué pregunta responde cada una' {
    Write-Host ''
    Write-Host ('  {0,-7} {1,-10} {2,-4} {3,-6} {4,-8} {5}' -f 'grupo', 'id', 'exp', 'fase', 'criterio', 'pregunta') -ForegroundColor White
    Get-Content (Join-Path $Raiz 'load\plan.tsv') -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object {
        $c = $_.Split("`t")
        if ($c.Count -ge 7) { Write-Host ('  {0,-7} {1,-10} {2,-4} {3,-6} {4,-8} {5}' -f $c[0], $c[1], $c[2], $c[3], $c[4], $c[6]) }
    }
    Write-Host ''
    Write-Host '  todo: make experimento  ·  un grupo: make grupo G=e02  ·  humo: make smoke'
    Write-Host ''
}
Add-Objetivo $GExp 'smoke' 'Humo de ~7 min: E01 y E02 de punta a punta, con veredicto' { Invoke-Up; Invoke-Orquestador @('humo') }
Add-Objetivo $GExp 'e2e' 'Prueba de punta a punta del montaje (~9 min): compila, levanta, verifica observabilidad, humo y cruce' {
    & (Join-Path $Raiz 'load\e2e.ps1')
    exit $LASTEXITCODE
}
Add-Objetivo $GExp 'experimentos' 'E01 y E02 de corrido, con criterio (~5 h). D4 va aparte: make d4' { Invoke-Up; Invoke-Orquestador @('e01', 'e02') }
Add-Objetivo $GExp 'e01' 'E01 completo (~2 h): S1, S2, S3 y S4' { Invoke-Up; Invoke-Orquestador @('e01') }
Add-Objetivo $GExp 'e02' 'E02 con criterio (~3 h): D1, D2 y D3 con T=2 s y N=3' { Invoke-Up; Invoke-Orquestador @('e02') }
Add-Objetivo $GExp 'd4' 'D4 exploratoria (~9 h, para la noche): las 12 combinaciones de T y N' { Invoke-Up; Invoke-Orquestador @('e02-d4') }
Add-Objetivo $GExp 'experimento' 'El plan completo (~14 h): E01, E02 y D4' { Invoke-Up; Invoke-Orquestador @() }
Add-Objetivo $GExp 'grupo' 'Un grupo del plan: make grupo G=e01' {
    $g = Get-Var 'G'
    if (-not $g) {
        Write-Host 'falta G. Grupos:'
        Get-Content (Join-Path $Raiz 'load\plan.tsv') -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } |
            ForEach-Object { $_.Split("`t")[0] } | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    Invoke-Up
    Invoke-Orquestador @($g.Split(' '))
}
Add-Objetivo $GExp 'veredicto' 'Recalcula el veredicto de una corrida: make veredicto CORRIDA=e01-s1-20261004-120000' {
    $c = Get-Var 'CORRIDA'
    if (-not $c) {
        Write-Host 'falta CORRIDA. Corridas:'
        Invoke-Sql -c 'SELECT id FROM registro.corrida ORDER BY arranque DESC LIMIT 20'
        exit 1
    }
    $exp = (Invoke-Sql -c "SELECT lower(experimento) FROM registro.corrida WHERE id = '$c'") -join ''
    if (-not $exp) { Write-Host "no existe la corrida $c"; exit 1 }
    Invoke-Compose exec -T postgres psql -U reto2 -d reto2 -v "corrida=$c" -f "/analisis/$exp.sql"
}
Add-Objetivo $GExp 'corridas' 'Lista las corridas registradas, con su ventana de medición' {
    Invoke-Compose exec -T postgres psql -U reto2 -d reto2 -c 'SELECT id, experimento, fase, inicio, fin, fin - inicio AS duracion FROM registro.corrida ORDER BY arranque DESC'
}

Add-Objetivo $GObs 'tablero' 'Abre los tableros de Grafana de E01 y E02' {
    Write-Host 'E01 http://localhost:3000/d/e01  ·  E02 http://localhost:3000/d/e02'
    Start-Process 'http://localhost:3000/d/e01'
    Start-Process 'http://localhost:3000/d/e02'
}
Add-Objetivo $GObs 'tableros' 'Regenera los JSON de los tableros desde deploy/observabilidad/generar-tableros.py' {
    $py = Get-Python
    if (-not $py) { throw 'no se encontró Python 3 (python3, python o py)' }
    & $py (Join-Path $Raiz 'deploy\observabilidad\generar-tableros.py')
    Invoke-Compose restart grafana
}
Add-Objetivo $GObs 'estado' 'Salud de cada micro y de la infraestructura' {
    foreach ($p in $Micros) {
        try {
            $r = Invoke-RestMethod -Uri "http://localhost:$p/actuator/health" -TimeoutSec 2
            Write-Host ('  :{0}  {1}' -f $p, ($r | ConvertTo-Json -Compress))
        } catch {
            Write-Host ('  :{0}  sin respuesta' -f $p)
        }
    }
    Invoke-Compose ps --format '  {{.Name}}\t{{.State}}' |
        Where-Object { $_ -notmatch 'reto2-(sesiones|usuario|receptor|onboarding|ventas|logistica|monitor|auditor|notificador)' }
}

Add-Objetivo $GFal 'matar' 'Mata una etapa y la levanta: make matar ETAPA=despacho CAIDA=20' {
    & docker exec inyector inyectar matar (Get-Var 'ETAPA' 'facturacion') (Get-Var 'CAIDA' '20')
}
Add-Objetivo $GFal 'congelar' 'Congela el próximo pedido de una etapa: make congelar ETAPA=inventario' {
    & docker exec inyector inyectar congelar (Get-Var 'ETAPA' 'inventario')
}
Add-Objetivo $GFal 'carga' 'Solo la carga de fondo del Ambiente A, hasta Ctrl-C (para mirar el tablero)' {
    Push-Location (Join-Path $Raiz 'load\k6')
    try { & k6 run -o experimental-prometheus-rw -e ("CORRIDA=manual-" + (Get-Date -Format 'HHmmss')) cadena.js }
    finally { Pop-Location }
}

function Invoke-Imagenes {
    Invoke-Gradle bootJar --console=plain -q
    Invoke-Compose build --quiet
    if ($LASTEXITCODE -ne 0) { throw 'docker compose build falló' }
}

function Invoke-Up {
    Invoke-Imagenes
    Invoke-Compose up -d
    if ($LASTEXITCODE -ne 0) { throw 'docker compose up falló' }
    Write-Host 'esperando a los micros' -NoNewline
    foreach ($p in $Micros) {
        for ($i = 0; $i -lt 90; $i++) {
            if (Test-Salud "http://localhost:$p/actuator/health") { break }
            Write-Host '.' -NoNewline
            Start-Sleep -Seconds 1
        }
    }
    Write-Host ' listos'
    # Grafana arranca su plugin de PostgreSQL con la primera consulta; esa ráfaga de
    # CPU llegó a vencer los sondeos del Monitor. Se dispara aquí, fuera de toda corrida.
    for ($i = 0; $i -lt 30; $i++) {
        if (Test-Salud 'http://localhost:3000/api/health' 2) { break }
        Start-Sleep -Seconds 1
    }
    $consulta = '{"from":"now-5m","to":"now","queries":[{"refId":"A","datasource":{"uid":"registro"},"rawSql":"SELECT 1","format":"table"},{"refId":"B","datasource":{"uid":"prometheus"},"expr":"up"}]}'
    try {
        Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/api/ds/query' -ContentType 'application/json' -Body $consulta -TimeoutSec 20 | Out-Null
        Write-Host 'Grafana precalentado'
    } catch {
        Write-Host 'Grafana no respondió la consulta de precalentamiento'
    }
    Write-Host 'Grafana http://localhost:3000 · Prometheus http://localhost:9090 · RabbitMQ http://localhost:15672 (reto2/reto2)'
}

Add-Objetivo $GTop 'up' 'Levanta todo y espera a que los 12 micros respondan' { Invoke-Up }
Add-Objetivo $GTop 'down' 'Detiene la topología; conserva la base y el histórico de Prometheus' { Invoke-Compose down --remove-orphans }
Add-Objetivo $GTop 'ps' 'Estado de los contenedores' { Invoke-Compose ps }
Add-Objetivo $GTop 'logs' 'Sigue los logs: make logs S=monitor' {
    $s = Get-Var 'S'
    if ($s) { Invoke-Compose logs -f $s } else { Invoke-Compose logs -f }
}
Add-Objetivo $GTop 'psql' 'Abre psql sobre la base del prototipo' { Invoke-Compose exec postgres psql -U reto2 -d reto2 }
Add-Objetivo $GTop 'vistas' 'Recarga las vistas SQL del cruce sin perder datos' {
    # Por la entrada estándar, como en el Makefile. El archivo también está
    # montado en el contenedor, pero un montaje de archivo suelto queda apuntando
    # al archivo viejo cuando git lo reemplaza. comun.ps1 fija la codificación
    # de la tubería en UTF-8.
    Get-Content -Path (Join-Path $Raiz 'deploy\postgres\03-vistas.sql') -Raw -Encoding UTF8 |
        Invoke-Compose exec -T postgres psql -U reto2 -d reto2 -v ON_ERROR_STOP=1
}

Add-Objetivo $GCom 'build' 'Compila los micros y corre sus pruebas unitarias' { Invoke-Gradle build --console=plain }
Add-Objetivo $GCom 'imagenes' 'Compila los jar y arma las imágenes (sin pruebas)' { Invoke-Imagenes }
Add-Objetivo $GCom 'test' 'Pruebas unitarias' { Invoke-Gradle test --console=plain }
Add-Objetivo $GCom 'clean' 'Borra la compilación, los contenedores y los volúmenes (la base y Prometheus)' {
    Invoke-Gradle clean -q
    Invoke-Compose down -v --remove-orphans
}
Add-Objetivo $GCom 'help' 'Muestra esta ayuda' {
    $grupo = ''
    foreach ($nombre in $Objetivos.Keys) {
        $o = $Objetivos[$nombre]
        if ($o.Grupo -ne $grupo) {
            $grupo = $o.Grupo
            Write-Host ''
            Write-Host $grupo -ForegroundColor White
        }
        Write-Host ('  {0,-12} ' -f $nombre) -NoNewline -ForegroundColor Cyan
        Write-Host $o.Ayuda
    }
    Write-Host ''
}

if (-not $Objetivos.Contains($Objetivo)) {
    Write-Host "objetivo desconocido: $Objetivo. Usa: make help"
    exit 2
}
try {
    & $Objetivos[$Objetivo].Accion
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
