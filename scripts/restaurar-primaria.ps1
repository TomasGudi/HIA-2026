<#
.SYNOPSIS
  Reconstruye la primaria después de la demo de failover.

.DESCRIPTION
  La demo deja db-replica promovida como primaria y pi-db detenida. Este script
  reconstruye el nodo viejo como standby de la primaria nueva y, con -SwapBack,
  devuelve los roles originales (db primaria, db-replica standby).

  Es DESTRUCTIVO: borra el volumen pi-pgdata (y con -SwapBack también
  pi-pgdata-replica). Hace dos clones de ~8,5 GB; puede tardar varios minutos.

.EXAMPLE
  ./scripts/restaurar-primaria.ps1                 # reconstruye pi-db como standby
  ./scripts/restaurar-primaria.ps1 -SwapBack       # devuelve db primaria / db-replica standby
#>
param(
  [switch]$SwapBack,
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
$replUser  = Get-EnvValue 'REPL_USER' 'replicador'
$replPass  = Get-EnvValue 'REPL_PASSWORD'

if (-not $Force) {
  Write-Host 'ATENCIÓN: se borra pi-pgdata y se clona desde db-replica.' -ForegroundColor Yellow
  if ($SwapBack) { Write-Host 'Con -SwapBack también se borra pi-pgdata-replica.' -ForegroundColor Yellow }
  $confirm = Read-Host 'Escribí RESTAURAR para confirmar'
  if ($confirm -ne 'RESTAURAR') { Write-Host 'Cancelado.'; return }
}

function Esperar-Psql([string]$servicio, [string]$consulta, [int]$Segundos = 120) {
  $fin = (Get-Date).AddSeconds($Segundos)
  while ((Get-Date) -lt $fin) {
    $out = $consulta | docker compose exec -T $servicio psql -U $adminUser -d $dbName -t -A -f - 2>$null
    if ($LASTEXITCODE -eq 0) { return ($out | Out-String).Trim() }
    Start-Sleep -Seconds 3
  }
  throw "timeout esperando $servicio"
}

function Esperar-Health([int]$Segundos = 120) {
  $fin = (Get-Date).AddSeconds($Segundos)
  while ((Get-Date) -lt $fin) {
    try {
      $r = Invoke-RestMethod 'http://127.0.0.1:8090/health' -TimeoutSec 5
      if ($r.status -eq 'ok' -and $r.db -eq 'up') { return $true }
    } catch { }
    Start-Sleep -Seconds 3
  }
  return $false
}

Write-Host '== 1) detener backend y pi-db ==' -ForegroundColor Cyan
docker compose stop backend 2>&1 | Select-Object -Last 1
docker compose stop db 2>&1 | Select-Object -Last 1
docker compose rm -sf db 2>&1 | Select-Object -Last 1
docker volume rm pi-pgdata 2>&1 | Select-Object -Last 1

Write-Host '== 2) clonar pi-db desde db-replica (8,5 GB) ==' -ForegroundColor Cyan
docker run --rm --network pi-dbnet -e "PGPASSWORD=$replPass" `
  -v pi-pgdata:/var/lib/postgresql/data postgres:16.4-alpine `
  sh -c "chown -R postgres:postgres /var/lib/postgresql/data && su-exec postgres pg_basebackup -h db-replica -U $replUser -D /var/lib/postgresql/data -Fp -Xs -R -P"
if ($LASTEXITCODE -ne 0) { throw 'pg_basebackup falló' }

Write-Host '== 3) arrancar pi-db como standby ==' -ForegroundColor Cyan
docker compose up -d db 2>&1 | Select-Object -Last 2
$enRecovery = Esperar-Psql 'db' 'SELECT pg_is_in_recovery();' 180
if ($enRecovery -ne 't') { throw "pi-db no quedó en recovery (valor: $enRecovery)" }
Write-Host 'pi-db reconstruida como standby de db-replica' -ForegroundColor Green

if (-not $SwapBack) {
  Write-Host 'Listo. La primaria sigue siendo db-replica; el backend no se tocó.' -ForegroundColor Yellow
  return
}

Write-Host '== 4) promover pi-db y repuntar el backend ==' -ForegroundColor Cyan
@'
SELECT pg_promote(wait => true, wait_seconds => 30);
'@ | docker compose exec -T db psql -U $adminUser -d $dbName -f -
if ($LASTEXITCODE -ne 0) { throw 'no se pudo promover pi-db' }

$env:DATABASE_HOST = 'db'
docker compose up -d --no-deps backend 2>&1 | Select-Object -Last 2
if (-not (Esperar-Health 120)) { throw 'el backend no quedó saludable apuntando a db' }
Write-Host 'backend repuntado a db' -ForegroundColor Green

Write-Host '== 5) reconstruir db-replica desde db ==' -ForegroundColor Cyan
docker compose stop db-replica 2>&1 | Select-Object -Last 1
docker compose rm -sf db-replica 2>&1 | Select-Object -Last 1
docker volume rm pi-pgdata-replica 2>&1 | Select-Object -Last 1
docker compose up -d db-replica 2>&1 | Select-Object -Last 2

$fin = (Get-Date).AddMinutes(8)
$streaming = $false
while ((Get-Date) -lt $fin) {
  $out = @'
SELECT count(*) FROM pg_stat_replication WHERE state = 'streaming';
'@ | docker compose exec -T db psql -U $adminUser -d $dbName -t -A -f - 2>$null
  if (($out | Out-String).Trim() -eq '1') { $streaming = $true; break }
  Start-Sleep -Seconds 5
}
if (-not $streaming) { Write-Host 'ADVERTENCIA: la réplica no muestra streaming todavía; revisar logs' -ForegroundColor Yellow }
else { Write-Host 'db-replica reconstruida y en streaming' -ForegroundColor Green }

Write-Host 'Topología restaurada: db primaria, db-replica standby.' -ForegroundColor Green
