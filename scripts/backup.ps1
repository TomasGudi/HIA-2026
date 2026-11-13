<#
.SYNOPSIS
  Backup lógico de la base (§4) y prueba de restauración.

.EXAMPLE
  ./scripts/backup.ps1                 # genera un backup
  ./scripts/backup.ps1 -RestoreTest    # backup + restauración en base limpia + comparación
#>
param(
  [switch]$RestoreTest,
  [switch]$SkipBackup,
  [int]$RetentionDays = 7
)

# 'Continue': psql escribe NOTICE por stderr y con 'Stop' PowerShell lo trata
# como excepción. Los errores reales se validan con $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
New-Item -ItemType Directory -Force -Path backups | Out-Null

function Get-EnvValue([string]$key, [string]$default) {
  if (-not (Test-Path '.env')) { return $default }
  $line = Get-Content '.env' | Where-Object { $_ -match "^\s*$key\s*=" } | Select-Object -Last 1
  if (-not $line) { return $default }
  return ($line -split '=', 2)[1].Trim()
}

$dbUser = Get-EnvValue 'POSTGRES_USER' 'practica_app'
$dbName = Get-EnvValue 'POSTGRES_DB' 'practica'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$file   = "practica-$stamp.sql.gz"

if ($SkipBackup) {
  $file = (Get-ChildItem backups -Filter 'practica-*.sql.gz' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
  if (-not $file) { throw "No hay backups para restaurar" }
  Write-Host "== Reutilizando backup existente: $file ==" -ForegroundColor Cyan
} else {
Write-Host "== Backup de '$dbName' ==" -ForegroundColor Cyan
$sw = [Diagnostics.Stopwatch]::StartNew()
# pg_dump dentro del contenedor: no depende de tener psql en el host
docker compose exec -T db sh -c "pg_dump -U $dbUser -d $dbName --no-owner --no-privileges | gzip -6 > /backups/$file"
$sw.Stop()
if ($LASTEXITCODE -ne 0) { throw "pg_dump falló" }

$sizeMb = [math]::Round((Get-Item "backups/$file").Length / 1MB, 1)
Write-Host ("Backup OK: backups/{0} ({1} MB) en {2:N1} s" -f $file, $sizeMb, $sw.Elapsed.TotalSeconds) -ForegroundColor Green
}

# retención
$viejos = Get-ChildItem backups -Filter 'practica-*.sql.gz' | Where-Object {
  $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays)
}
if ($viejos) {
  $viejos | Remove-Item -Force
  Write-Host ("Retención: {0} backup(s) eliminados (> {1} días)" -f $viejos.Count, $RetentionDays)
}

if (-not $RestoreTest) { return }

Write-Host "`n== Prueba de restauración en base limpia ==" -ForegroundColor Cyan
$target = "restore_test"

docker compose exec -T db psql -q -U $dbUser -d postgres -c "DROP DATABASE IF EXISTS $target;" 2>&1 | Out-Null
docker compose exec -T db psql -q -U $dbUser -d postgres -c "CREATE DATABASE $target;" 2>&1 | Out-Null

$sw2 = [Diagnostics.Stopwatch]::StartNew()
docker compose exec -T db sh -c "gunzip -c /backups/$file | psql -q -U $dbUser -d $target"
$sw2.Stop()
if ($LASTEXITCODE -ne 0) { throw "restauración falló" }
Write-Host ("Restauración OK en {0:N1} s" -f $sw2.Elapsed.TotalSeconds) -ForegroundColor Green

$query = @'
SELECT 'Article' AS tabla, count(*) FROM "Article"
UNION ALL SELECT 'Comment', count(*) FROM "Comment"
UNION ALL SELECT 'User', count(*) FROM "User"
UNION ALL SELECT 'Tag', count(*) FROM "Tag"
UNION ALL SELECT '_UserFavorites', count(*) FROM "_UserFavorites"
UNION ALL SELECT '_ArticleToTag', count(*) FROM "_ArticleToTag"
ORDER BY tabla;
'@
Write-Host "`n-- origen --"
docker compose exec -T db psql -U $dbUser -d $dbName -c $query
Write-Host "-- restaurada --"
docker compose exec -T db psql -U $dbUser -d $target -c $query

docker compose exec -T db psql -q -U $dbUser -d postgres -c "DROP DATABASE $target;" 2>&1 | Out-Null
Write-Host "Base de prueba eliminada." -ForegroundColor DarkGray
