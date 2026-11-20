<#
.SYNOPSIS
  OperaciÃ³n de incidentes (extra: Hermes + remediaciÃ³n).

.DESCRIPTION
  Inicializa el esquema `ops` en un volumen existente, lista incidentes y
  permite simular/aprobar/rechazar el flujo sin tocar la base.

  El flujo real de la demo es:
    alerta -> n8n -> MCP (incidente + correo + Telegram) -> Hermes pregunta
    -> aprobaciÃ³n -> scripts/incidente-watcher.ps1 ejecuta el failover.

.EXAMPLE
  ./scripts/incidentes.ps1 init
  ./scripts/incidentes.ps1 demo
  ./scripts/incidentes.ps1 listar
  ./scripts/incidentes.ps1 aprobar 12
  ./scripts/incidentes.ps1 rechazar 12
  ./scripts/incidentes.ps1 estado 12
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('init','demo','listar','aprobar','rechazar','estado')]
  [string]$Action = 'listar',

  [Parameter(Position = 1)]
  [int]$Id = 0
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-EnvValue([string]$key, [string]$default = '') {
  if (-not (Test-Path '.env')) { return $default }
  $line = Get-Content '.env' | Where-Object { $_ -match "^\s*$key\s*=" } | Select-Object -Last 1
  if (-not $line) { return $default }
  return ($line -split '=', 2)[1].Trim()
}

$adminUser = Get-EnvValue 'POSTGRES_USER' 'practica_app'
$dbName    = Get-EnvValue 'POSTGRES_DB' 'practica'
$opsDb     = Get-EnvValue 'OPS_DB_NAME' 'ops'
$opsUser   = Get-EnvValue 'OPS_DB_USER' 'mcp_ops'
$opsPass   = Get-EnvValue 'MCP_OPS_DB_PASSWORD'
$mcpToken  = Get-EnvValue 'MCP_TOKEN'
$mcpUrl    = 'http://127.0.0.1:8098'

function Invoke-OpsPsql([string[]]$SqlArgs, [switch]$NoTty) {
  $flags = @('compose','exec')
  if ($NoTty) { $flags += '-T' }
  $flags += @('opsdb','psql','-U',$opsUser,'-d',$opsDb,'-v','ON_ERROR_STOP=1')
  & docker @flags @SqlArgs
  if ($LASTEXITCODE -ne 0) { throw "psql de opsdb fallÃ³ (exit $LASTEXITCODE)" }
}

function Invoke-Mcp([string]$Method, [string]$Path, $Body = $null) {
  if (-not $mcpToken) { throw 'falta MCP_TOKEN en .env' }
  $params = @{
    Uri         = "$mcpUrl$Path"
    Method      = $Method
    Headers     = @{ Authorization = "Bearer $mcpToken" }
    TimeoutSec  = 30
  }
  if ($Body -ne $null) {
    $params.ContentType = 'application/json; charset=utf-8'
    $params.Body = ($Body | ConvertTo-Json -Depth 10)
  }
  Invoke-RestMethod @params
}

switch ($Action) {
  'init' {
    # La base y el usuario los crea el contenedor `opsdb` en el primer
    # arranque. AcÃ¡ solo se aplica el esquema (idempotente) por si el
    # volumen ya existÃ­a antes de este cambio.
    Invoke-OpsPsql @('-f','/docker-entrypoint-initdb.d/01-incidentes.sql')
    Write-Host "init: esquema de incidentes y runbooks listos en opsdb" -ForegroundColor Green
  }

  'demo' {
    $alerta = @{
      status = 'firing'
      alerts = @(@{
        labels = @{
          alertname = 'PostgresCaido'
          severity  = 'critical'
          instance  = 'db:5432'
          job       = 'postgres'
        }
        annotations = @{
          summary     = 'La primaria PostgreSQL no responde'
          description = 'pg_up == 0 desde hace 1 minuto (simulaciÃ³n controlada)'
        }
      })
    }

    $r = Invoke-Mcp 'POST' '/incidentes' @{ alerta = $alerta }
    $inc = $r.incidente
    Write-Host ("incidente #{0} creado: {1} [{2}]" -f $inc.id, $inc.titulo, $inc.estado) -ForegroundColor Green
    Write-Host ("correo: {0} | telegram: {1}" -f $r.notificaciones.correo.enviado, $r.notificaciones.telegram.enviado) -ForegroundColor DarkGray
    Write-Host "revisar MailHog en http://127.0.0.1:8025 y Telegram" -ForegroundColor Cyan
  }

  'listar' {
    Invoke-OpsPsql @('-c', @'
SELECT id, codigo, estado, severidad, titulo,
       to_char(created_at, 'HH24:MI:SS') AS creado
FROM ops.incident
ORDER BY id DESC
LIMIT 20;
'@) -NoTty
  }

  'estado' {
    if ($Id -le 0) { throw 'indicÃ¡ el id: ./scripts/incidentes.ps1 estado 12' }
    $r = Invoke-Mcp 'GET' "/incidentes/$Id"
    $r.incidente | Format-List
  }

  'aprobar' {
    if ($Id -le 0) { throw 'indicÃ¡ el id: ./scripts/incidentes.ps1 aprobar 12' }
    $r = Invoke-Mcp 'POST' "/incidentes/$Id/aprobar" @{ usuario = 'demo-script' }
    Write-Host ("incidente #{0} -> {1}" -f $r.incidente.id, $r.incidente.estado) -ForegroundColor Green
  }

  'rechazar' {
    if ($Id -le 0) { throw 'indicÃ¡ el id: ./scripts/incidentes.ps1 rechazar 12' }
    $r = Invoke-Mcp 'POST' "/incidentes/$Id/rechazar" @{ usuario = 'demo-script' }
    Write-Host ("incidente #{0} -> {1}" -f $r.incidente.id, $r.incidente.estado) -ForegroundColor Yellow
  }
}
