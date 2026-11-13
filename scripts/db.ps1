<#
.SYNOPSIS
  Atajos para el ciclo de vida de la base de datos (Sprint 1, §4).

.EXAMPLE
  ./scripts/db.ps1 up          # levanta db + pgadmin
  ./scripts/db.ps1 schema      # aplica db/init/01-schema.sql (idempotente)
  ./scripts/db.ps1 seed        # carga el dataset masivo (lee .env)
  ./scripts/db.ps1 indexes     # crea índices DESPUÉS de la carga
  ./scripts/db.ps1 stats       # tamaño de tablas e índices + conteos
  ./scripts/db.ps1 psql        # shell interactivo
  ./scripts/db.ps1 reset       # BORRA el volumen y vuelve a empezar
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('up','down','schema','seed','indexes','stats','psql','reset','logs')]
  [string]$Action = 'up'
)

$ErrorActionPreference = 'Stop'
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

function Invoke-Psql([string[]]$args, [switch]$NoTty) {
  $flags = @('compose','exec')
  if ($NoTty) { $flags += '-T' }
  $flags += @('db','psql','-U',$dbUser,'-d',$dbName,'-v','ON_ERROR_STOP=1')
  & docker @flags @args
  if ($LASTEXITCODE -ne 0) { throw "psql falló (exit $LASTEXITCODE)" }
}

switch ($Action) {
  'up'      { docker compose up -d db pgadmin; docker compose ps }
  'down'    { docker compose down }
  'logs'    { docker compose logs -f --tail=100 db }
  'schema'  { Invoke-Psql @('-f','/db/init/01-schema.sql','-f','/db/init/02-extensions.sql') }
  'indexes' { Invoke-Psql @('-f','/db/03-indexes.sql') }
  'psql'    { docker compose exec db psql -U $dbUser -d $dbName }
  'reset'   {
    Write-Host 'ATENCIÓN: se borra el volumen pi-pgdata y todos los datos.' -ForegroundColor Yellow
    $confirm = Read-Host 'Escribí BORRAR para confirmar'
    if ($confirm -ne 'BORRAR') { Write-Host 'Cancelado.'; return }
    docker compose down -v
    docker compose up -d db
  }
  'seed' {
    $a = Get-EnvValue 'SEED_ARTICLES' '6000000'
    $c = Get-EnvValue 'SEED_COMMENTS' '6000000'
    $f = Get-EnvValue 'SEED_FAVORITES' '6000000'
    $u = Get-EnvValue 'SEED_USERS' '200000'
    $t = Get-EnvValue 'SEED_TAGS' '5000'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Psql @('-v',"articles=$a",'-v',"comments=$c",'-v',"favorites=$f",'-v',"users=$u",'-v',"tags=$t",'-f','/db/seed/10-seed.sql') -NoTty
    $sw.Stop()
    Write-Host ("Carga terminada en {0:N1} min" -f $sw.Elapsed.TotalMinutes) -ForegroundColor Green
  }
  'stats' {
    Invoke-Psql @('-c', @'
SELECT relname AS tabla,
       n_live_tup AS filas_aprox,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano_total
FROM pg_stat_user_tables t
JOIN pg_class c ON c.oid = t.relid
ORDER BY pg_total_relation_size(c.oid) DESC;
'@)
    Invoke-Psql @('-c', 'SELECT pg_size_pretty(pg_database_size(current_database())) AS base_de_datos;')
  }
}
