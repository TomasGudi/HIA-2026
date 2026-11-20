#Requires -Version 5.1
<#
.SYNOPSIS
    Operacion del tablero Taiga (S2) del proyecto HIA-2026.

.DESCRIPTION
    Taiga reemplaza a Jira Cloud: el backlog vive en el servidor local, sin
    licencia y sin depender de un servicio externo.

    Acciones:
      init    primer arranque: levanta los contenedores, crea el admin y los
              usuarios de trabajo y carga el backlog desde backlog/*.csv
      seed    vuelve a cargar el backlog (idempotente: no duplica)
      status  contenedores, conteos del tablero y URL de acceso
      url     imprime la URL local y la publica (si hay tunel activo)

.EXAMPLE
    ./scripts/taiga.ps1 init

.EXAMPLE
    ./scripts/taiga.ps1 status
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'seed', 'status', 'url')]
    [string]$Accion = 'status'
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

$base = 'http://127.0.0.1:8084'

function Leer-Env {
    $valores = @{}
    Get-Content .env | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        $valores[$k] = $v
    }
    return $valores
}

function Esperar-Api {
    param([int]$Segundos = 180)
    $limite = (Get-Date).AddSeconds($Segundos)
    while ((Get-Date) -lt $limite) {
        try {
            $r = Invoke-WebRequest "$base/api/v1/" -UseBasicParsing -TimeoutSec 5
            if ($r.StatusCode -eq 200) { return $true }
        }
        catch { Start-Sleep -Seconds 4 }
    }
    return $false
}

switch ($Accion) {
    'init' {
        $env_vars = Leer-Env
        Write-Host '==> levantando Taiga'
        docker compose --profile ops up -d taiga-gateway taiga-async | Out-Null

        if (-not (Esperar-Api)) {
            throw "la API de Taiga no respondio en $base/api/v1/"
        }

        Write-Host '==> creando usuarios'
        Get-Content app/taiga/usuarios.py -Raw |
            docker compose --profile ops run --rm -T --entrypoint python `
                -e "TAIGA_ADMIN_PASSWORD=$($env_vars['TAIGA_ADMIN_PASSWORD'])" `
                -e "TAIGA_ADMIN_USER=$($env_vars['TAIGA_ADMIN_USER'])" `
                -e "TAIGA_ADMIN_EMAIL=$($env_vars['TAIGA_ADMIN_EMAIL'])" `
                taiga-back manage.py shell | Select-String -Pattern 'creado|existe'

        Write-Host '==> cargando el backlog'
        python scripts/taiga-seed.py --base-url $base
    }

    'seed' {
        python scripts/taiga-seed.py --base-url $base
    }

    'status' {
        docker compose --profile ops ps --format '{{.Name}} {{.Status}}' |
            Select-String -Pattern 'taiga'

        Write-Host ''
        docker compose --profile ops exec -T taiga-db psql -U taiga -d taiga -c @'
select (select count(*) from epics_epic) as epicas,
       (select count(*) from userstories_userstory) as historias,
       (select count(*) from milestones_milestone) as sprints,
       (select count(*) from projects_membership) as miembros;
'@ -c @'
select s.name as estado, count(*)
from userstories_userstory u
join projects_userstorystatus s on s.id = u.status_id
group by s.name order by 2 desc;
'@

        Write-Host "local: $base"
    }

    'url' {
        Write-Host "local: $base"
        $estado = Get-ChildItem -Path "$env:TEMP" -Filter 'cloudflared-taiga*.log' -ErrorAction SilentlyContinue
        if ($estado) {
            $linea = Select-String -Path $estado.FullName -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' |
                Select-Object -Last 1
            if ($linea) { Write-Host ('publica: ' + $linea.Matches[0].Value) }
        }
        else {
            Write-Host 'publica: sin tunel activo (./scripts/publicar.ps1 up)'
        }
    }
}
