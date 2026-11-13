<#
.SYNOPSIS
  Corre el agente Hermes contra el servidor MCP y deja la evidencia en evidence/extra-mcp/.

.DESCRIPTION
  Hace tres preguntas que obligan a usar herramientas distintas (estado, base de
  datos y contenido) y guarda la salida cruda y un resumen en Markdown.

  Requiere el stack levantado y el agente corriendo:
    docker compose -f automation/hermes/compose.yaml --env-file .env up -d

.EXAMPLE
  ./scripts/hermes-demo.ps1
#>
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$salida = Join-Path $root 'evidence/extra-mcp'
New-Item -ItemType Directory -Force -Path "$salida/raw" | Out-Null

$preguntas = @(
  @{ id = 'estado';    texto = '¿Está funcionando la plataforma? Decime versión y uptime.' },
  @{ id = 'base-datos'; texto = '¿Cuánto ocupa la base de datos y qué tabla tiene más filas?' },
  @{ id = 'contenido'; texto = 'Mostrame el título y el autor del artículo más reciente.' }
)

$utf8 = New-Object System.Text.UTF8Encoding($false)
$anterior = [Console]::OutputEncoding
# docker escribe UTF-8: sin esto PowerShell decodifica como ANSI y rompe los acentos
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$md = @(
  '# Agente Hermes sobre MCP — evidencia',
  '',
  "Fecha: $(Get-Date -Format o)",
  '',
  'Cada bloque es la respuesta del agente a una pregunta. Las líneas `Practica · ...`',
  'son las herramientas MCP que ejecutó (el nombre se ve en la salida cruda).',
  ''
)

try {
  foreach ($p in $preguntas) {
    Write-Host "== $($p.id) =="
    $crudo = & docker exec pi-hermes hermes chat -q $p.texto 2>&1 | Out-String
    [System.IO.File]::WriteAllText("$salida/raw/$($p.id).txt", $crudo, $utf8)

    $herramientas = [regex]::Matches($crudo, 'Practica · ([^\r\n]+)') |
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

[System.IO.File]::WriteAllText("$salida/hermes-demo.md", ($md -join "`n"), $utf8)
Write-Host "evidencia en $salida/hermes-demo.md"
