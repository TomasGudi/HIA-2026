<#
.SYNOPSIS
  Demo del agente Hermes usando RAGFlow como segundo servidor MCP.

.DESCRIPTION
  Hace preguntas que NO se pueden contestar con la API de la aplicación: solo
  están en la documentación del proyecto, que vive en el dataset de RAGFlow.
  Guarda la salida en evidence/extra-mcp/ragflow-demo.md.

  Requiere:
    docker compose -f automation/hermes/compose.yaml --env-file .env up -d
    stack de RAGFlow levantado (C:\Users\tomas\ragflow\docker)

.EXAMPLE
  ./scripts/ragflow-demo.ps1
#>
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$salida = Join-Path $root 'evidence/extra-mcp'
New-Item -ItemType Directory -Force -Path "$salida/raw" | Out-Null

$preguntas = @(
  @{ id = 'rto-failover'; texto = 'Segun la documentacion del proyecto, que RTO se midio en el failover de la replica y que divergencia aparecio? Cita el documento.' },
  @{ id = 'limitaciones'; texto = 'Que limitaciones declaramos sobre Mantis y por que corre como root? Cita el documento.' }
)

$utf8 = New-Object System.Text.UTF8Encoding($false)
$anterior = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$md = @(
  '# Agente Hermes sobre RAGFlow (segundo servidor MCP)',
  '',
  "Fecha: $(Get-Date -Format o)",
  '',
  'Las respuestas salen de la documentación indexada en RAGFlow (`docs/`), no de',
  'la base de la aplicación. El agente tiene dos servidores MCP conectados:',
  '`practica` (datos vivos) y `ragflow` (documentación).',
  ''
)

try {
  foreach ($p in $preguntas) {
    Write-Host "== $($p.id) =="
    $crudo = & docker exec pi-hermes hermes chat -q $p.texto 2>&1 | Out-String
    [System.IO.File]::WriteAllText("$salida/raw/$($p.id).txt", $crudo, $utf8)

    $herramientas = [regex]::Matches($crudo, '(?:Practica|Ragflow) · ([^\r\n]+)') |
      ForEach-Object { ($_.Groups[1].Value -replace '\s+\d+(\.\d+)?s\s*$', '').Trim() }
    $llamadas = [regex]::Match($crudo, 'Messages:\s+\d+ \(\d+ user, (\d+) tool call')

    $md += "## $($p.texto)"
    $md += ''
    $md += '```'
    $md += (($crudo -split '─{10,}') | Where-Object { $_ -match '☤ Hermes' } |
      Select-Object -Last 1).Trim()
    $md += '```'
    $md += ''
    $md += "- Herramientas usadas: " + (($herramientas | Select-Object -Unique) -join ', ')
    $md += "- Llamadas a herramientas: " + $(if ($llamadas.Success) { $llamadas.Groups[1].Value } else { '?' })
    $md += ''
  }
} finally {
  [Console]::OutputEncoding = $anterior
}

[System.IO.File]::WriteAllText("$salida/ragflow-demo.md", ($md -join "`n"), $utf8)
Write-Host "evidencia en $salida/ragflow-demo.md"
