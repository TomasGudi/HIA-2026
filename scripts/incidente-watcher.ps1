<#
.SYNOPSIS
  Watcher de remediaciÃ³n: ejecuta el failover cuando Hermes aprueba un incidente.

.DESCRIPTION
  Consulta la tabla ops.incident cada N segundos. Cuando encuentra un incidente
  en estado `approved`, promueve la rÃ©plica, repunta el backend y verifica
  /health. DespuÃ©s marca el incidente como `resolved` o `failed`.

  Es un proceso del HOST (no un contenedor con Docker socket): asÃ­ el privilegio
  de tocar contenedores queda fuera de la red del agente.

  Requisitos:
    * incidente aprobado (Hermes o ./scripts/incidentes.ps1 aprobar <id>)
    * primaria detenida: el script se niega a promover si pi-db sigue corriendo
    * rÃ©plica en streaming

.EXAMPLE
  ./scripts/incidente-watcher.ps1 -DryRun -UnaVez   # ensayo sin tocar nada
  ./scripts/incidente-watcher.ps1                    # queda escuchando
#>
param(
  [int]$Intervalo = 3,
  [switch]$UnaVez,
  [switch]$DryRun,
  [switch]$Force
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
$mcpToken  = Get-EnvValue 'MCP_TOKEN'
$mcpUrl    = 'http://127.0.0.1:8098'

function Invoke-Mcp([string]$Method, [string]$Path, $Body = $null) {
  if (-not $mcpToken) { throw 'falta MCP_TOKEN en .env' }
  $params = @{
    Uri        = "$mcpUrl$Path"
    Method     = $Method
    Headers    = @{ Authorization = "Bearer $mcpToken" }
    TimeoutSec = 60
  }
  if ($Body -ne $null) {
    $params.ContentType = 'application/json; charset=utf-8'
    $params.Body = ($Body | ConvertTo-Json -Depth 10)
  }
  Invoke-RestMethod @params
}

function Get-Pendiente {
  $out = @'
SELECT id FROM ops.incident
WHERE estado = 'approved'
ORDER BY COALESCE(aprobado_at, created_at), id
LIMIT 1;
'@ | docker compose exec -T opsdb psql -U $opsUser -d $opsDb -t -A -f - 2>$null
  $id = ($out | Out-String).Trim()
  if ($id -match '^\d+$') { return [int]$id }
  return 0
}

function Esperar-Health([int]$Segundos = 90) {
  $fin = (Get-Date).AddSeconds($Segundos)
  while ((Get-Date) -lt $fin) {
    try {
      $r = Invoke-RestMethod 'http://127.0.0.1:8090/health' -TimeoutSec 5
      if ($r.status -eq 'ok' -and $r.db -eq 'up') { return $r }
    } catch { }
    Start-Sleep -Seconds 2
  }
  return $null
}

Write-Host "watcher de incidentes (DryRun=$DryRun, cada $Intervalo s)" -ForegroundColor Cyan

while ($true) {
  $id = Get-Pendiente
  if ($id -gt 0) {
    Write-Host "== incidente #$id aprobado: iniciando remediaciÃ³n ==" -ForegroundColor Yellow
    $t0 = Get-Date

    if ($DryRun) {
      Write-Host "[dry-run] se promoverÃ­a db-replica y se recrearÃ­a backend con DATABASE_HOST=db-replica"
      Write-Host "[dry-run] no se cambia ningÃºn estado"
      if ($UnaVez) { break }
      Start-Sleep -Seconds $Intervalo
      continue
    }

    # 1) no permitir split-brain: si la primaria sigue viva, no promover
    $primaria = (docker inspect pi-db --format '{{.State.Running}}' 2>$null | Out-String).Trim()
    if ($primaria -eq 'true' -and -not $Force) {
      $msg = 'la primaria pi-db sigue corriendo; no se promueve la rÃ©plica (usar -Force para simulaciÃ³n)'
      Write-Host "ERROR: $msg" -ForegroundColor Red
      Invoke-Mcp 'POST' "/incidentes/$id/estado" @{ estado = 'failed'; resultado = $msg } | Out-Null
    } else {
      try {
        Invoke-Mcp 'POST' "/incidentes/$id/estado" @{ estado = 'resolving'; resultado = 'watcher: promoviendo rÃ©plica' } | Out-Null

        # 2) promover la rÃ©plica si todavÃ­a estÃ¡ en recovery
        $enRecovery = (@'
SELECT pg_is_in_recovery();
'@ | docker compose exec -T db-replica psql -U $adminUser -d $dbName -t -A -f - 2>$null | Out-String).Trim()
        if ($enRecovery -eq 't') {
          Write-Host "promoviendo db-replica..." -ForegroundColor Cyan
          @'
SELECT pg_promote(wait => true, wait_seconds => 30);
'@ | docker compose exec -T db-replica psql -U $adminUser -d $dbName -f -
          if ($LASTEXITCODE -ne 0) { throw "pg_promote fallÃ³ (exit $LASTEXITCODE)" }
        } else {
          Write-Host "db-replica ya no estÃ¡ en recovery: se usa como primaria" -ForegroundColor DarkGray
        }

        # 3) repuntar el backend
        Write-Host "recreando backend con DATABASE_HOST=db-replica..." -ForegroundColor Cyan
        $env:DATABASE_HOST = 'db-replica'
        docker compose up -d --no-deps backend 2>&1 | Select-Object -Last 2
        if ($LASTEXITCODE -ne 0) { throw "docker compose up backend fallÃ³ (exit $LASTEXITCODE)" }

        # 4) verificar salud real
        $h = Esperar-Health 90
        $seg = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        if (-not $h) { throw "el backend no quedÃ³ saludable en 90 s" }

        $resultado = "failover completado en ${seg}s: db-replica promovida y backend repuntado (version=$($h.version))"
        Invoke-Mcp 'POST' "/incidentes/$id/estado" @{ estado = 'resolved'; resultado = $resultado } | Out-Null
        Write-Host "OK: $resultado" -ForegroundColor Green
      } catch {
        $seg = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        $msg = "remediaciÃ³n fallida tras ${seg}s: $($_.Exception.Message)"
        Write-Host "ERROR: $msg" -ForegroundColor Red
        try { Invoke-Mcp 'POST' "/incidentes/$id/estado" @{ estado = 'failed'; resultado = $msg } | Out-Null } catch { }
      }
    }

    if ($UnaVez) { break }
  }

  if ($UnaVez) { break }
  Start-Sleep -Seconds $Intervalo
}

