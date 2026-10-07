# ==============================================================================
# Piezas comunes de make.ps1, load/experimento.ps1 y load/e2e.ps1: el camino de
# Windows. En macOS y Linux el mismo trabajo lo hacen el Makefile y los .sh.
#
# Compatibles con Windows PowerShell 5.1 (el que trae Windows) y PowerShell 7.
# Tres trampas de 5.1 que se resuelven aquí y no en cada script:
#   - la salida de docker y psql llega en UTF-8, y 5.1 la lee como ANSI;
#   - 5.1 escribe los archivos en UTF-16 si se usa `>`: todo se escribe con
#     Write-Utf8 / Add-Utf8;
#   - 5.1 pierde las comillas dobles al pasar argumentos a un ejecutable: los
#     SQL de los scripts no llevan comillas dobles.
# ==============================================================================

# Los ejecutables (docker, gradle, k6) escriben progreso en stderr. Con 'Stop',
# 5.1 lo tomaría como error: los fallos se miran con $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'   # la barra de Invoke-WebRequest frena 5.1

$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
# Sin consola real (salida redirigida), asignar la codificación de la consola
# lanza una excepción: entonces no hace falta.
try { [Console]::OutputEncoding = $script:Utf8 } catch { }
$OutputEncoding = $script:Utf8
$env:PYTHONIOENCODING = 'utf-8'   # los scripts de Python imprimen ✓ y ✗

$script:Raiz = Split-Path -Parent $PSScriptRoot
$script:ComposeArchivo = Join-Path $script:Raiz 'deploy\docker-compose.yml'
$script:Micros = @(8081, 8082, 8083, 8084, 8090, 8091, 8092, 8093, 8094, 8095, 8096)

function Invoke-Compose {
    & docker compose -f $script:ComposeArchivo @args
}

# psql dentro del contenedor de la base, en modo crudo (-qtA) y con parada al
# primer error. Devuelve las líneas de salida.
function Invoke-Sql {
    & docker compose -f $script:ComposeArchivo exec -T postgres psql -U reto2 -d reto2 -qtA -v ON_ERROR_STOP=1 @args
}

function Write-Log([string]$Texto) {
    Write-Host ('[{0}] ' -f (Get-Date -Format 'HH:mm:ss')) -NoNewline -ForegroundColor White
    Write-Host $Texto
}

function Write-Utf8([string]$Ruta, $Lineas) {
    $texto = (@($Lineas) | ForEach-Object { "$_" }) -join "`n"
    [System.IO.File]::WriteAllText($Ruta, $texto + "`n", $script:Utf8)
}

function Add-Utf8([string]$Ruta, $Lineas) {
    $texto = (@($Lineas) | ForEach-Object { "$_" }) -join "`n"
    [System.IO.File]::AppendAllText($Ruta, $texto + "`n", $script:Utf8)
}

function Test-Salud([string]$Url, [int]$Segundos = 1) {
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $Segundos
        return ($r.StatusCode -lt 400)
    } catch {
        return $false
    }
}

function Wait-Salud([int]$Puerto, [int]$Intentos = 90) {
    for ($i = 0; $i -lt $Intentos; $i++) {
        if (Test-Salud "http://localhost:$Puerto/actuator/health") { return $true }
        Start-Sleep -Seconds 1
    }
    Write-Log "el micro del puerto $Puerto no respondió en $Intentos s"
    return $false
}

# python3 en Linux y macOS; en Windows puede llamarse python, python3 o py.
function Get-Python {
    foreach ($candidato in @('python3', 'python', 'py')) {
        $cmd = Get-Command $candidato -ErrorAction SilentlyContinue
        if ($cmd) {
            & $cmd.Source --version *> $null
            if ($LASTEXITCODE -eq 0) { return $cmd.Source }
        }
    }
    return $null
}

# Una corrida de D4 dura horas: que Windows no suspenda el equipo a mitad. Es el
# equivalente de caffeinate y vale mientras viva el proceso que lo pide.
function Start-SinSuspender {
    if ($env:OS -ne 'Windows_NT') { return }   # solo Windows tiene kernel32
    if (-not ('Reto2.Energia' -as [type])) {
        Add-Type -Namespace Reto2 -Name Energia -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
    }
    # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
    [void][Reto2.Energia]::SetThreadExecutionState([uint32]2147483649)
}

# Detiene un k6 que corre en segundo plano pidiéndoselo por su API REST, para
# que termine con su resumen. Es el equivalente del kill -INT de experimento.sh:
# en Windows no hay forma limpia de mandarle Ctrl-C a otro proceso.
function Stop-K6([int]$Puerto, [System.Diagnostics.Process]$Proceso) {
    $cuerpo = '{"data":{"type":"status","id":"default","attributes":{"stopped":true}}}'
    try {
        Invoke-RestMethod -Method Patch -Uri "http://localhost:$Puerto/v1/status" `
            -ContentType 'application/json' -Body $cuerpo -TimeoutSec 5 | Out-Null
    } catch { }
    if (-not $Proceso.WaitForExit(60000)) {
        Stop-Process -Id $Proceso.Id -Force -ErrorAction SilentlyContinue
    }
}
