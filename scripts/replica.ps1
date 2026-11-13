<#
.SYNOPSIS
  Operación de la réplica (§6): estado, lag, escritura de prueba, promoción.

.EXAMPLE
  ./scripts/replica.ps1 status     # estado de replicación en la primaria
  ./scripts/replica.ps1 lag        # atraso de replay
  ./scripts/replica.ps1 test       # escritura en primaria + lectura en réplica
  ./scripts/replica.ps1 promote    # failover MANUAL: promueve la réplica
  ./scripts/replica.ps1 reinit     # destruye y vuelve a clonar la réplica
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('status','lag','test','promote','reinit','readonly')]
  [string]$Action = 'status'
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-EnvValue([string]$key, [string]$default) {
  if (-not (Test-Path '.env')) { return $default }
  $line = Get-Content '.env' | Where-Object { $_ -match "^\s*$key\s*=" } | Select-Object -Last 1
  if (-not $line) { return $default }
  return ($line -split '=', 2)[1].Trim()
}
$dbUser = Get-EnvValue 'POSTGRES_USER' 'practica_app'
$dbName = Get-EnvValue 'POSTGRES_DB' 'practica'

switch ($Action) {
  'status' {
    @'
SELECT client_addr, state, sync_state,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_replay,
       write_lag, flush_lag, replay_lag
FROM pg_stat_replication;
'@ | docker compose exec -T db psql -U $dbUser -d $dbName -f -
    @'
SELECT pg_is_in_recovery() AS primaria_en_recuperacion,
       (SELECT count(*) FROM pg_stat_replication) AS replicas_conectadas;
'@ | docker compose exec -T db psql -U $dbUser -d $dbName -f -
  }

  'lag' {
    @'
SELECT pg_last_wal_replay_lsn() AS lsn_replica,
       now() - pg_last_xact_replay_timestamp() AS atraso_replay,
       pg_is_in_recovery() AS es_standby;
'@ | docker compose exec -T db-replica psql -U $dbUser -d $dbName -f -
  }

  'readonly' {
    Write-Host "Intento de escritura en la réplica (debe fallar):" -ForegroundColor Yellow
    @"
INSERT INTO "Tag" (name) VALUES ('escritura-en-replica-' || to_char(now(),'HH24MISS'));
"@ | docker compose exec -T db-replica psql -U $dbUser -d $dbName -f -
    Write-Host "Si el mensaje anterior dice 'read-only transaction', la réplica está protegida." -ForegroundColor DarkGray
  }

  'test' {
    $name = 'replica-test-' + (Get-Date -Format 'yyyyMMddHHmmss')
    $t0 = Get-Date
    @"
INSERT INTO "Tag" (name) VALUES ('$name') RETURNING id, name, now() AS escrito_en;
"@ | docker compose exec -T db psql -U $dbUser -d $dbName -f -

    $visible = $false
    for ($i = 0; $i -lt 30; $i++) {
      $out = @"
SELECT count(*) AS encontrado FROM "Tag" WHERE name = '$name';
"@ | docker compose exec -T db-replica psql -U $dbUser -d $dbName -t -A -f -
      if ($out.Trim() -eq '1') { $visible = $true; break }
      Start-Sleep -Milliseconds 200
    }
    $ms = [math]::Round(((Get-Date) - $t0).TotalMilliseconds, 0)
    if ($visible) {
      Write-Host ("Fila '$name' visible en la réplica tras {0} ms" -f $ms) -ForegroundColor Green
    } else {
      Write-Host "La fila NO apareció en la réplica (revisar lag)" -ForegroundColor Red
    }
  }

  'promote' {
    Write-Host "Failover MANUAL: se promueve la réplica. No hay detección automática." -ForegroundColor Yellow
    $t0 = Get-Date
    @'
SELECT pg_promote(wait => true, wait_seconds => 30) AS promovida;
'@ | docker compose exec -T db-replica psql -U $dbUser -d $dbName -f -
    $secs = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
    @'
SELECT pg_is_in_recovery() AS sigue_en_recuperacion;
'@ | docker compose exec -T db-replica psql -U $dbUser -d $dbName -f -
    Write-Host ("Promoción completada en {0} s" -f $secs) -ForegroundColor Green
    Write-Host "Falta repuntar la aplicación: DATABASE_URL -> db-replica y reiniciar el backend." -ForegroundColor Yellow
  }

  'reinit' {
    Write-Host "Se destruye el volumen de la réplica y se vuelve a clonar." -ForegroundColor Yellow
    docker compose rm -sf db-replica
    docker volume rm pi-pgdata-replica
    docker compose up -d db-replica
    Write-Host "Clon en curso: seguir con 'docker compose logs -f db-replica'" -ForegroundColor DarkGray
  }
}
