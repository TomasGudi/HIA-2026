<#
.SYNOPSIS
  Provisión de Nextcloud (§12): usuarios, grupos, carpeta de grupo y estructura.

.DESCRIPTION
  Deja la gestión documental lista y reproducible:
    init       crea grupos, usuarios y la carpeta de grupo con permisos
    structure  crea las 17 carpetas (00..16) y sube los documentos
    status     muestra usuarios, grupos, permisos y cantidad de archivos

  Requiere que el contenedor `pi-nextcloud` esté arriba:
    docker compose --profile ops up -d nextcloud

.EXAMPLE
  ./scripts/nextcloud.ps1 init
  ./scripts/nextcloud.ps1 structure
  ./scripts/nextcloud.ps1 status
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('init', 'structure', 'status')]
  [string]$Action = 'status'
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

$adminUser = Get-EnvValue 'NEXTCLOUD_ADMIN_USER' 'admin'
$adminPass = Get-EnvValue 'NEXTCLOUD_ADMIN_PASSWORD'
$userPass  = Get-EnvValue 'NEXTCLOUD_USER_PASSWORD'
$base      = 'http://127.0.0.1:8082'
$dav       = "$base/remote.php/dav/files/$adminUser/HIA-2026"
$credencial = "${adminUser}:${adminPass}"

if (-not $adminPass) { throw "falta NEXTCLOUD_ADMIN_PASSWORD en .env" }

function Invoke-Occ {
  param([string[]]$Argumentos, [hashtable]$Env = @{})
  $flags = @('compose', 'exec', '-T')
  foreach ($k in $Env.Keys) { $flags += @('-e', "$k=$($Env[$k])") }
  $flags += @('-u', 'www-data', 'nextcloud', 'php', 'occ')
  & docker @flags @Argumentos
}

function Invoke-Dav {
  param([string]$Metodo, [string]$Ruta, [string]$Archivo)
  $curlArgs = @('-s', '-o', 'NUL', '-w', '%{http_code}', '-X', $Metodo, '-u', $credencial)
  if ($Archivo) { $curlArgs += @('-T', $Archivo) }
  $code = & curl.exe @curlArgs "$dav/$Ruta"
  return $code
}

switch ($Action) {
  'init' {
    if (-not $userPass) { throw "falta NEXTCLOUD_USER_PASSWORD en .env" }

    # grupos
    foreach ($g in 'equipo', 'lectores') {
      Invoke-Occ @('group:add', $g) | Out-Null
    }

    # usuarios: 5 integrantes con escritura, 1 auditor de solo lectura, 1 sin grupo
    foreach ($u in 'r1', 'r2', 'r3', 'r4', 'r5') {
      Invoke-Occ @('user:add', '--password-from-env', '--display-name', "Integrante $($u.ToUpper())", '--group', 'equipo', $u) @{ OC_PASS = $userPass } | Out-Null
    }
    Invoke-Occ @('user:add', '--password-from-env', '--display-name', 'Auditor externo', '--group', 'lectores', 'auditor') @{ OC_PASS = $userPass } | Out-Null
    Invoke-Occ @('user:add', '--password-from-env', '--display-name', 'Invitado sin grupo', 'invitado') @{ OC_PASS = $userPass } | Out-Null

    # el admin administra la carpeta de grupo
    Invoke-Occ @('group:adduser', 'equipo', $adminUser) | Out-Null

    # app de carpetas de grupo y carpeta única del proyecto
    Invoke-Occ @('app:install', 'groupfolders') | Out-Null
    $id = (Invoke-Occ @('groupfolders:create', 'HIA-2026') | Select-Object -Last 1)
    if ($id -notmatch '^\d+$') { $id = '1' }

    # permisos: equipo escribe y comparte; lectores solo leen
    Invoke-Occ @('groupfolders:group', $id, 'equipo', 'read', 'write', 'delete', 'share') | Out-Null
    Invoke-Occ @('groupfolders:group', $id, 'lectores', 'read') | Out-Null

    Write-Host "init: grupos, usuarios y carpeta de grupo listos (id=$id)"
  }

  'structure' {
    $carpetas = @(
      '00-informe-consolidado',
      '01-descripcion-app', '02-arquitectura', '03-inventario-tecnologico',
      '04-manual-instalacion', '05-configuracion-docker', '06-migracion-carga',
      '07-optimizacion-sql', '08-replicacion', '09-cicd', '10-publicacion',
      '11-monitoreo', '12-incidencias', '13-automatizacion', '14-seguridad',
      '15-backup', '16-limitaciones'
    )

    foreach ($c in $carpetas) {
      $code = Invoke-Dav -Metodo 'MKCOL' -Ruta "$c/"
      if ($code -notin '201', '405') { Write-Host "MKCOL $c -> $code" }
    }
    Write-Host "estructura: $($carpetas.Count) carpetas"

    # documentos: cada .md va a su carpeta numerada
    $subidos = 0
    foreach ($doc in Get-ChildItem 'docs/informe' -Filter '*.md' | Sort-Object Name) {
      $carpeta = $doc.BaseName
      $code = Invoke-Dav -Metodo 'PUT' -Ruta "$carpeta/$($doc.Name)" -Archivo $doc.FullName
      if ($code -eq '201' -or $code -eq '204') { $subidos++ } else { Write-Host "PUT $($doc.Name) -> $code" }
    }

    # informe consolidado
    foreach ($f in 'docs/HIA-2026-informe-final.pdf', 'docs/informe-consolidado.md') {
      if (Test-Path $f) {
        $item = Get-Item $f
        $code = Invoke-Dav -Metodo 'PUT' -Ruta "00-informe-consolidado/$($item.Name)" -Archivo $item.FullName
        if ($code -eq '201' -or $code -eq '204') { $subidos++ } else { Write-Host "PUT $($item.Name) -> $code" }
      }
    }
    Write-Host "estructura: $subidos archivos subidos"
  }

  'status' {
    Invoke-Occ @('status')
    Write-Host "`n--- grupos ---"
    Invoke-Occ @('group:list')
    Write-Host "`n--- usuarios ---"
    Invoke-Occ @('user:list')
    Write-Host "`n--- carpeta de grupo y permisos ---"
    Invoke-Occ @('groupfolders:list')
    Write-Host "`n--- archivos en la carpeta ---"
    $body = '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>'
    $tmp = Join-Path $env:TEMP 'dav-propfind.xml'
    [System.IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding($false)))
    $r = & curl.exe -s -u $credencial -X PROPFIND -H 'Depth: 1' --data-binary "@$tmp" "$dav/"
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    $hrefs = [regex]::Matches($r, '<d:href>([^<]+)</d:href>') | ForEach-Object { $_.Groups[1].Value }
    Write-Host "$($hrefs.Count - 1) entradas de primer nivel"
  }
}
