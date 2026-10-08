# ==============================================================================
# Prueba de punta a punta del MONTAJE, no de las hipótesis, para Windows. Hace
# lo mismo que load/e2e.sh; si se cambia uno, se cambia el otro.
#
# Verifica que todo lo que el veredicto necesita existe y fluye: compila y pasa
# las pruebas, levanta la topología, Prometheus raspa a los 12 micros y a
# RabbitMQ, las consultas de los tableros responden, el humo de E01 y E02 corre,
# cada tipo de evento llega al registro y cada criterio tiene casos.
#
# Que H1 o H2 pasen o fallen es el resultado del experimento, y se informa
# aparte sin hacer fallar el e2e: D3 falla por diseño si el sondeo no ve el
# pedido congelado. Lo que sí lo hace fallar es un criterio sin casos (NO
# APLICA), un tipo de evento ausente, un duplicado o un panel roto.
#
# Uso: .\load\e2e.ps1        Sale con 0 si el montaje está sano.
# ==============================================================================
. (Join-Path $PSScriptRoot 'comun.ps1')

$env:STAMP = 'e2e-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$Stamp = $env:STAMP
$script:Fallas = 0
$script:Informe = New-Object System.Collections.Generic.List[object]
$Temp = [System.IO.Path]::GetTempPath()

function Write-Titulo([string]$t) { Write-Host ''; Write-Host "== $t" -ForegroundColor White }
function Write-Ok([string]$t) {
    Write-Host '  ✓ ' -NoNewline -ForegroundColor Green; Write-Host $t
    $script:Informe.Add([pscustomobject]@{ Estado = 'ok'; Verificacion = $t })
}
function Write-Falla([string]$t) {
    Write-Host '  ✗ ' -NoNewline -ForegroundColor Red; Write-Host $t
    $script:Informe.Add([pscustomobject]@{ Estado = 'FALLA'; Verificacion = $t })
    $script:Fallas++
}

Write-Titulo '1. Compilación y pruebas unitarias'
$logGradle = Join-Path $Temp 'e2e-gradle.log'
try {
    Write-Utf8 $logGradle (& (Join-Path $Raiz 'gradlew.bat') build --console=plain -q 2>&1)
    $okGradle = ($LASTEXITCODE -eq 0)
} catch {
    Write-Utf8 $logGradle $_.Exception.Message
    $okGradle = $false
}
if ($okGradle) { Write-Ok 'gradle build y pruebas unitarias' }
else { Write-Falla "gradle build: ver $logGradle"; Get-Content $logGradle -Tail 20; exit 1 }

Write-Titulo '2. Topología'
$logUp = Join-Path $Temp 'e2e-up.log'
Write-Utf8 $logUp (& (Join-Path $Raiz 'make.ps1') up 2>&1)
$caidos = @($Micros | Where-Object { -not (Test-Salud "http://localhost:$_/actuator/health" 2) })
if ($caidos.Count -eq 0) { Write-Ok 'los 12 micros responden /actuator/health' }
else { Write-Falla ("no responden: " + ($caidos -join ', ') + ". Ver $logUp"); exit 1 }

Write-Titulo '3. Observabilidad'
Start-Sleep -Seconds 6   # un par de raspados de Prometheus
try {
    $objetivos = (Invoke-RestMethod -Uri 'http://localhost:9090/api/v1/targets' -TimeoutSec 10).data.activeTargets
    $vivos = @($objetivos | Where-Object { $_.health -eq 'up' })
    $muertos = @($objetivos | Where-Object { $_.health -ne 'up' } | ForEach-Object { $_.labels.instance })
    if ($vivos.Count -eq @($objetivos).Count -and $vivos.Count -ge 13) {
        Write-Ok "Prometheus raspa $($vivos.Count) de $(@($objetivos).Count) objetivos"
    } else {
        Write-Falla "Prometheus raspa $($vivos.Count) de $(@($objetivos).Count) objetivos; caídos: $($muertos -join ' ')"
    }
} catch {
    Write-Falla 'Prometheus no respondió'
}
foreach ($uid in 'e01', 'e02') {
    if (Test-Salud "http://localhost:3000/api/dashboards/uid/$uid" 5) { Write-Ok "tablero $uid aprovisionado en Grafana" }
    else { Write-Falla "tablero $uid no está en Grafana" }
}

Write-Titulo '4. Humo de E01 y E02 (~7 min)'
& (Join-Path $PSScriptRoot 'experimento.ps1') humo

Write-Titulo '5. El cruce: cada criterio con casos y cada evento en el registro'
$resultados = Join-Path $Raiz 'analisis\resultados'
foreach ($corrida in "humo-e01-$Stamp", "humo-e02-$Stamp") {
    $v = Join-Path $resultados "$corrida\veredicto.txt"
    if (-not (Test-Path $v) -or (Get-Item $v).Length -eq 0) { Write-Falla "$corrida no dejó veredicto"; continue }
    $sinCasos = @(Select-String -Path $v -Pattern '\| NO APLICA *$' -Encoding UTF8).Count
    if ($sinCasos -eq 0) { Write-Ok "$corrida`: todos los criterios tienen casos" }
    else { Write-Falla "$corrida`: $sinCasos criterios sin casos (NO APLICA)" }
    $csv = Join-Path $resultados "$corrida\eventos-$corrida.csv"
    if ((Test-Path $csv) -and (Get-Item $csv).Length -gt 0) { Write-Ok "$corrida`: eventos exportados a CSV" }
    else { Write-Falla "$corrida`: falta el CSV de eventos" }
}

# Cada tipo de evento que el veredicto cruza tiene que haber llegado en la corrida.
$esperados = @('sesion.abierta', 'huella.comparada', 'aviso.emitido', 'aviso.recibido', 'dispositivo.registrado',
    'pedido.confirmado', 'etapa.completada', 'pedido.listo', 'pedido.en.logistica', 'alerta.notificada',
    'falla.inyectada', 'sondeo.fallido', 'etapa.declarada.detenida', 'pedido.encolado', 'mensaje.en.cola',
    'etapa.reiniciada', 'etapa.recuperada', 'falla.congelada')
$presentes = @(Invoke-Sql -c ("SELECT DISTINCT e.tipo FROM registro.evento e, registro.corrida c " +
    "WHERE c.id LIKE 'humo-%-$Stamp' AND e.ts BETWEEN c.arranque AND c.fin + interval '60 seconds'") | ForEach-Object { "$_".Trim() })
$faltan = @($esperados | Where-Object { $presentes -notcontains $_ })
if ($faltan.Count -eq 0) { Write-Ok "los $($esperados.Count) tipos de evento llegaron al registro" }
else { Write-Falla ('faltan eventos: ' + ($faltan -join ' ')) }

$vE02 = Join-Path $resultados "humo-e02-$Stamp\veredicto.txt"
$dup = @(Select-String -Path $vE02 -Pattern '^\s*Todas · cada pedido encolado.*\| PASA *$' -Encoding UTF8 -ErrorAction SilentlyContinue).Count
if ($dup -eq 1) { Write-Ok 'E02: cero perdidos y cero duplicados en la cola' }
else { Write-Falla 'E02: hay pedidos perdidos o duplicados en la cola' }

Write-Titulo '6. Los tableros sobre los datos del humo'
$py = Get-Python
if (-not $py) {
    Write-Falla 'no se encontró Python 3 (python3, python o py) para verificar los tableros'
} else {
    & $py (Join-Path $Raiz 'deploy\observabilidad\verificar-tableros.py') --vacios
    if ($LASTEXITCODE -eq 0) { Write-Ok 'todas las consultas de los tableros responden con datos' }
    else { Write-Falla 'hay paneles rotos o vacíos' }
}

Write-Titulo 'Resultado de las hipótesis en el humo (informativo, no hace fallar el e2e)'
foreach ($corrida in "humo-e01-$Stamp", "humo-e02-$Stamp") {
    $v = Join-Path $resultados "$corrida\veredicto.txt"
    if (Test-Path $v) {
        Select-String -Path $v -Pattern '\| (PASA|FALLA|NO APLICA) *$' -Encoding UTF8 |
            ForEach-Object { Write-Host ('  ' + $_.Line.Trim()) }
    }
}

Write-Titulo 'Resumen del e2e'
$script:Informe | ForEach-Object { Write-Host ('  {0,-6} {1}' -f $_.Estado, $_.Verificacion) }
if ($script:Fallas -eq 0) {
    Write-Host ''
    Write-Host '  El montaje está sano. Tableros: http://localhost:3000/d/e01 · /d/e02' -ForegroundColor Green
    exit 0
}
Write-Host ''
Write-Host "  $($script:Fallas) verificaciones fallaron." -ForegroundColor Red
exit 1
