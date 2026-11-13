<#
.SYNOPSIS
  Escaneos de seguridad de §14 (Trivy, npm audit, Semgrep, Bandit, gitleaks).

.DESCRIPTION
  Deja la salida en evidence/14/. No modifica nada: solo audita.
  Requiere Docker. La primera corrida baja la base de Trivy (~50 MB).

.EXAMPLE
  ./scripts/seguridad-scan.ps1
#>
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
New-Item -ItemType Directory -Force -Path evidence/14 | Out-Null
$out = 'evidence/14'

function Linea([string]$texto) {
  Write-Host $texto
  Add-Content -Path "$out/seguridad-scan.log" -Value $texto
}

"" | Set-Content "$out/seguridad-scan.log"
Linea "=== escaneos de seguridad (§14) $(Get-Date -Format o) ==="

# 1) Trivy sobre las imágenes que construimos y las bases que usamos
$imagenes = @(
  'pi-backend:dev',
  'pi-frontend:dev',
  'pi-mantis:2.28.4',
  'postgres:16.4-alpine',
  'docker.n8n.io/n8nio/n8n:1.68.0'
)
foreach ($img in $imagenes) {
  $archivo = "$out/trivy-" + ($img -replace '[:/]', '-') + '.txt'
  Linea "`n=== trivy: $img ==="
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock `
    -v "${PWD}/${out}:/salida" aquasec/trivy:latest image `
    --scanners vuln --severity HIGH,CRITICAL --no-progress --format table `
    --output "/salida/$(Split-Path $archivo -Leaf)" $img 2>&1 |
    Select-Object -Last 3 | ForEach-Object { Linea $_ }
  if (Test-Path $archivo) {
    $criticas = (Select-String -Path $archivo -Pattern 'CRITICAL' -AllMatches).Count
    $altas = (Select-String -Path $archivo -Pattern 'HIGH' -AllMatches).Count
    Linea ("{0}: CRITICAL={1} HIGH={2}" -f $img, $criticas, $altas)
  }
}

# 2) npm audit (solo lockfile, sin instalar)
foreach ($svc in 'backend', 'frontend') {
  Linea "`n=== npm audit: $svc ==="
  docker run --rm -v "${PWD}/app/${svc}:/app" -w /app node:20 `
    npm audit --omit=dev --audit-level=high 2>&1 |
    Tee-Object -FilePath "$out/npm-audit-$svc.txt" |
    Select-Object -Last 12 | ForEach-Object { Linea $_ }
}

# 3) Semgrep sobre el código de la app
Linea "`n=== semgrep (app/) ==="
docker run --rm -v "${PWD}/app:/src" returntocorp/semgrep:latest `
  semgrep --config=auto --metrics=off --quiet /src 2>&1 |
  Tee-Object -FilePath "$out/semgrep.txt" |
  Select-Object -Last 25 | ForEach-Object { Linea $_ }

# 4) Bandit sobre los scripts Python
Linea "`n=== bandit (scripts/) ==="
docker run --rm -v "${PWD}/scripts:/src:ro" python:3.12-alpine `
  sh -c "pip install --quiet bandit && bandit -r /src -q" 2>&1 |
  Tee-Object -FilePath "$out/bandit.txt" |
  Select-Object -Last 20 | ForEach-Object { Linea $_ }

# 5) gitleaks sobre todo el historial
Linea "`n=== gitleaks (historial completo) ==="
docker run --rm -v "${PWD}:/repo" zricethezav/gitleaks:latest `
  detect --source=/repo --config=/repo/.gitleaks.toml --redact --verbose 2>&1 |
  Tee-Object -FilePath "$out/gitleaks.log" |
  Select-Object -Last 8 | ForEach-Object { Linea $_ }

Linea "`n=== fin $(Get-Date -Format o) ==="
