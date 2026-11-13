<#
.SYNOPSIS
  Publica el stack por Cloudflare Tunnel (§9).

.DESCRIPTION
  Levanta el borde con auth y tres túneles rápidos (app, pgAdmin, Mantis).
  Imprime las URLs públicas, que cambian en cada arranque.

.EXAMPLE
  ./scripts/publicar.ps1 up
  ./scripts/publicar.ps1 urls
  ./scripts/publicar.ps1 down
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('up','down','urls')]
  [string]$Action = 'up'
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$tunnels = @(
  @{ name = 'pi-tunnel';        net = 'pi-appnet'; url = 'http://frontend:80'; label = 'app    ' },
  @{ name = 'pi-tunnel-admin';  net = 'pi-dbnet';  url = 'http://edge:8080';   label = 'pgadmin' },
  @{ name = 'pi-tunnel-mantis'; net = 'pi-dbnet';  url = 'http://edge:8081';   label = 'mantis ' }
)

function Get-TunnelUrl([string]$name) {
  $log = docker logs $name 2>&1 | Out-String
  $m = [regex]::Match($log, 'https://[a-z0-9-]+\.trycloudflare\.com')
  if ($m.Success) { return $m.Value } else { return $null }
}

switch ($Action) {
  'up' {
    Write-Host "== borde con auth ==" -ForegroundColor Cyan
    docker compose --profile ops up -d edge 2>&1 | Select-Object -Last 1

    foreach ($t in $tunnels) {
      docker rm -f $t.name 2>$null | Out-Null
      docker run -d --name $t.name --network $t.net `
        cloudflare/cloudflared:latest tunnel --no-autoupdate --url $t.url 2>&1 | Out-Null
      Write-Host ("túnel {0} iniciado" -f $t.label)
    }

    Write-Host "esperando URLs (10-20 s)..." -ForegroundColor DarkGray
    for ($i = 0; $i -lt 20; $i++) {
      Start-Sleep -Seconds 3
      $listas = ($tunnels | ForEach-Object { Get-TunnelUrl $_.name }) | Where-Object { $_ }
      if ($listas.Count -eq $tunnels.Count) { break }
    }

    Write-Host "`n== URLs públicas ==" -ForegroundColor Green
    foreach ($t in $tunnels) {
      $u = Get-TunnelUrl $t.name
      if ($u) { "{0} {1}" -f $t.label, $u } else { "{0} (sin URL todavía: docker logs {1})" -f $t.label, $t.name }
    }
    Write-Host "`nSon efímeras: cambian al reiniciar los túneles." -ForegroundColor DarkGray
  }

  'urls' {
    foreach ($t in $tunnels) {
      $u = Get-TunnelUrl $t.name
      if (-not $u) { $u = '(sin URL)' }
      "{0} {1}" -f $t.label, $u
    }
  }

  'down' {
    foreach ($t in $tunnels) { docker rm -f $t.name 2>$null | Out-Null }
    Write-Host "túneles detenidos"
  }
}
