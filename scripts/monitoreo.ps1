<#
.SYNOPSIS
  Operación del monitoreo (§10): estado, prueba de alerta y URLs.

.EXAMPLE
  ./scripts/monitoreo.ps1 status
  ./scripts/monitoreo.ps1 test-alerta -Minutos 8
  ./scripts/monitoreo.ps1 urls
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet('status','test-alerta','urls','recargar')]
  [string]$Action = 'status',
  [int]$Minutos = 8
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Prom([string]$path) {
  (Invoke-WebRequest ("http://127.0.0.1:9090/api/v1/" + $path) -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
}
function Query([string]$q) {
  $u = 'http://127.0.0.1:9090/api/v1/query?query=' + [uri]::EscapeDataString($q)
  ((Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json).data.result
}

switch ($Action) {
  'status' {
    Write-Host "== targets ==" -ForegroundColor Cyan
    $t = Invoke-Prom 'targets'
    $t.data.activeTargets |
      Select-Object @{n='job';e={$_.labels.job}}, @{n='instancia';e={$_.labels.instance}}, health |
      Format-Table -AutoSize | Out-String -Width 120 | Write-Host

    Write-Host "== reglas ==" -ForegroundColor Cyan
    $r = Invoke-Prom 'rules'
    $r.data.groups.rules |
      Select-Object name, state, health, @{n='for';e={$_.duration}} |
      Format-Table -AutoSize | Out-String -Width 120 | Write-Host

    Write-Host "== alertas en Alertmanager ==" -ForegroundColor Cyan
    try {
      $am = (Invoke-WebRequest 'http://127.0.0.1:9093/api/v2/alerts' -UseBasicParsing -TimeoutSec 15).Content | ConvertFrom-Json
      if (-not $am) { Write-Host "ninguna" }
      else { $am | ForEach-Object { $_.labels.alertname + ' [' + $_.status.state + '] ' + $_.labels.instance } }
    } catch { Write-Host "Alertmanager no responde" -ForegroundColor Red }
  }

  'urls' {
    Write-Host "Prometheus    http://127.0.0.1:9090"
    Write-Host "Alertmanager  http://127.0.0.1:9093"
    Write-Host "Grafana       http://127.0.0.1:3001/d/pi-overview"
  }

  'recargar' {
    Invoke-WebRequest -Method POST 'http://127.0.0.1:9090/-/reload' -UseBasicParsing -TimeoutSec 20 | Out-Null
    Write-Host "Prometheus recargado"
  }

  'test-alerta' {
    # Prueba de anomalía: se satura la CPU del anfitrión con stress-ng y se
    # sigue la transición inactive -> pending -> firing de la regla CPUAlta.
    # El contenedor de estrés NO forma parte del stack: se crea y se destruye.
    $inicio = Get-Date
    Write-Host ("== prueba de alerta ({0}) ==" -f $inicio.ToString('o')) -ForegroundColor Cyan

    $cpu0 = (Query '100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)')[0].value[1]
    Write-Host ("CPU antes: {0:N1}%" -f [double]$cpu0)

    docker rm -f pi-stress 2>$null | Out-Null
    docker run -d --name pi-stress alexeiled/stress-ng `
      --cpu 16 --timeout ([string]($Minutos * 60) + 's') 2>&1 | Select-Object -Last 1 | Out-Null

    $visto = @{}
    $fin = (Get-Date).AddMinutes($Minutos + 3)
    while ((Get-Date) -lt $fin) {
      $cpu = (Query '100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)')[0].value[1]
      # el estado se lee de la API de reglas, no de ALERTS: ALERTS se consulta
      # contra la TSDB y puede devolver series viejas dentro del lookback.
      $reglas = (Invoke-WebRequest 'http://127.0.0.1:9090/api/v1/rules' -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
      $regla = $reglas.data.groups.rules | Where-Object { $_.name -eq 'CPUAlta' } | Select-Object -First 1
      $s = if ($regla) { $regla.state } else { 'desconocido' }
      if (-not $visto.ContainsKey($s)) {
        $visto[$s] = $true
        $seg = [math]::Round(((Get-Date) - $inicio).TotalSeconds, 0)
        Write-Host ("[{0,4}s] CPU {1,5:N1}%  alerta: {2}" -f $seg, [double]$cpu, $s)
      }
      if ($s -eq 'firing' -and $visto.ContainsKey('firing')) {
        Start-Sleep -Seconds 20   # dar tiempo a que Alertmanager notifique
        break
      }
      Start-Sleep -Seconds 10
    }

    Write-Host "== alertas en Alertmanager ==" -ForegroundColor Cyan
    try {
      $am = (Invoke-WebRequest 'http://127.0.0.1:9093/api/v2/alerts' -UseBasicParsing -TimeoutSec 15).Content | ConvertFrom-Json
      $am | ForEach-Object { $_.labels.alertname + ' [' + $_.status.state + '] ' + $_.labels.instance }
    } catch { Write-Host "Alertmanager no responde" -ForegroundColor Red }

    Write-Host "== payload recibido por el receptor ==" -ForegroundColor Cyan
    if (Test-Path 'evidence/10/alertmanager-payloads.jsonl') {
      Get-Content 'evidence/10/alertmanager-payloads.jsonl' | Select-Object -Last 1 |
        ForEach-Object { $_.Substring(0, [Math]::Min(600, $_.Length)) }
    } else { Write-Host "sin payloads todavía" -ForegroundColor Yellow }

    docker rm -f pi-stress 2>$null | Out-Null
    Write-Host ("== fin: {0:N0}s ==" -f ((Get-Date) - $inicio).TotalSeconds) -ForegroundColor Cyan
  }
}
