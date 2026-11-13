<#
.SYNOPSIS
  Despliegue pull-based con rollback automático (§8).

.DESCRIPTION
  Baja las imágenes publicadas en el registro, recrea backend y frontend,
  verifica salud real y, si la versión nueva no responde, vuelve sola a la
  versión anterior. El estado queda en .deploy/state.json.

.EXAMPLE
  ./scripts/deploy.ps1 -Tag sha-1a2b3c4
  ./scripts/deploy.ps1 -Rollback
#>
param(
  [string]$Tag = 'latest',
  [string]$Registry = '127.0.0.1:5000',
  [switch]$Rollback,
  [switch]$SkipPull,
  [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$stateDir = Join-Path $root '.deploy'
$stateFile = Join-Path $stateDir 'state.json'
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir | Out-Null }

function Read-State {
  if (Test-Path $stateFile) {
    try { return Get-Content $stateFile -Raw | ConvertFrom-Json } catch { }
  }
  return [pscustomobject]@{ current = $null; previous = $null; history = @() }
}

function Write-State($state) {
  $state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding utf8
}

function Set-Images([string]$t) {
  $env:BACKEND_IMAGE = "$Registry/hia-2026-backend:$t"
  $env:FRONTEND_IMAGE = "$Registry/hia-2026-frontend:$t"
  $env:APP_VERSION = $t
}

function Get-Health {
  try {
    $r = Invoke-WebRequest 'http://127.0.0.1:8090/health' -UseBasicParsing -TimeoutSec 5
    return ($r.Content | ConvertFrom-Json)
  } catch { return $null }
}

function Wait-Healthy([int]$timeout) {
  $fin = (Get-Date).AddSeconds($timeout)
  while ((Get-Date) -lt $fin) {
    $h = Get-Health
    $estado = (docker inspect pi-backend --format '{{.State.Health.Status}}' 2>$null)
    if ($h -and $h.status -eq 'ok' -and $estado -eq 'healthy') { return $true }
    Start-Sleep -Seconds 3
  }
  return $false
}

function Deploy-Tag([string]$t) {
  Set-Images $t
  Write-Host "== desplegando $t ==" -ForegroundColor Cyan
  docker compose up -d --no-build --no-deps backend frontend 2>&1 | Select-Object -Last 3
}

$state = Read-State

if ($Rollback) {
  if (-not $state.previous) { Write-Host "No hay versión anterior registrada." -ForegroundColor Red; exit 1 }
  $Tag = $state.previous
  Write-Host "Rollback manual a '$Tag'" -ForegroundColor Yellow
}

Write-Host ("Registro: {0} | tag: {1}" -f $Registry, $Tag)

# 1) bajar las imágenes ANTES de tocar lo que está corriendo:
#    si el pull falla, el servicio actual sigue intacto.
if (-not $SkipPull) {
  foreach ($svc in 'backend','frontend') {
    $img = "$Registry/hia-2026-$svc`:$Tag"
    docker pull $img 2>&1 | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) {
      Write-Host "ERROR: no se pudo bajar $img. El despliegue actual no se tocó." -ForegroundColor Red
      exit 1
    }
  }
}

$anterior = $state.current
Deploy-Tag $Tag

$ok = Wait-Healthy $TimeoutSeconds
$h = Get-Health

if ($ok) {
  $nuevo = [pscustomobject]@{
    current    = $Tag
    previous   = $anterior
    deployed_at = (Get-Date).ToString('o')
    history    = @($state.history) + $Tag
  }
  Write-State $nuevo
  Write-Host ("OK: versión '{0}' saludable (status={1}, db={2})" -f $h.version, $h.status, $h.db) -ForegroundColor Green
  exit 0
}

# 2) rollback automático
Write-Host "FALLO: '$Tag' no quedó saludable en $TimeoutSeconds s" -ForegroundColor Red
if (-not $anterior) {
  Write-Host "No hay versión anterior para volver. Intervención manual." -ForegroundColor Red
  exit 1
}

Write-Host "Rollback automático a '$anterior'" -ForegroundColor Yellow
Deploy-Tag $anterior
$ok2 = Wait-Healthy $TimeoutSeconds
$h2 = Get-Health

if ($ok2) {
  Write-State ([pscustomobject]@{
    current     = $anterior
    # se conserva el anterior real (v1), no el tag que falló: así un
    # `-Rollback` posterior no vuelve a intentar la versión rota
    previous    = $state.previous
    deployed_at = (Get-Date).ToString('o')
    rolled_back = $true
    failed_tag  = $Tag
    history     = @($state.history) + "$Tag (falló)"
  })
  Write-Host ("Rollback OK: corre '{0}' (status={1})" -f $h2.version, $h2.status) -ForegroundColor Green
  exit 0
}

Write-Host "El rollback tampoco quedó saludable. Revisar manualmente." -ForegroundColor Red
exit 1
