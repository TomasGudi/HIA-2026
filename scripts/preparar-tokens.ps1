<#
.SYNOPSIS
  Genera los archivos de secreto que algunos servicios leen del disco.

.DESCRIPTION
  Alertmanager no soporta variables de entorno en su configuración, así que
  el token del webhook de n8n se escribe en un archivo montado. El archivo
  está en .gitignore: nunca se versiona.

  Es idempotente: se puede correr antes de cada `up`.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-EnvValue([string]$key) {
  $line = Get-Content '.env' | Where-Object { $_ -match "^\s*$key\s*=" } | Select-Object -Last 1
  if (-not $line) { throw "falta $key en .env" }
  return ($line -split '=', 2)[1].Trim()
}

$token = Get-EnvValue 'N8N_WEBHOOK_TOKEN'
$destino = Join-Path $root 'monitoring/alertmanager/n8n_token'
[System.IO.File]::WriteAllText($destino, $token, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "token de n8n escrito en monitoring/alertmanager/n8n_token" -ForegroundColor Green
