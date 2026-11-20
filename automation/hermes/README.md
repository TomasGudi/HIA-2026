# Agente Hermes (extra)

Contenedor con [Hermes Agent](https://hermes-agent.nousresearch.com/) conectado
al servidor MCP de la aplicación (`app/mcp`).

Se levanta **aparte** del stack principal y se une a su red:

```powershell
# desde la raíz del repo
docker compose -f automation/hermes/compose.yaml --env-file .env up -d
```

Requisitos en `.env`: `MCP_TOKEN`, `OPENCODE_GO_API_KEY`,
`HERMES_DASHBOARD_PASSWORD`, `HERMES_DASHBOARD_SECRET`, `HERMES_API_KEY`.

## Archivos

| Archivo | Qué es |
|---|---|
| `compose.yaml` | servicio `hermes` + volumen `pi-hermes-data` |
| `config.yaml` | modelo y conexión MCP (sin secretos) |
| `SOUL.md` | rol y límites del agente |

## Uso

```powershell
# una consulta
docker exec pi-hermes hermes chat -q "¿Cuánto ocupa la base?"

# sesión interactiva
docker exec -it pi-hermes hermes chat

# dashboard
start http://127.0.0.1:9119
```

## Verificar la conexión MCP

```powershell
docker exec pi-hermes hermes mcp catalog    # debe listar `practica` y `ragflow`
docker exec pi-hermes sh -c "grep 'MCP:' /opt/data/logs/agent.log | tail -2"
# MCP: registered 7 tool(s) from 2 server(s)
```

`practica` responde sobre los datos de la aplicación; `ragflow` (extra) sobre la
documentación indexada. El segundo requiere el stack de RAGFlow levantado y el
contenedor conectado a la red `docker_ragflow` (ya declarada en `compose.yaml`).

Si dice `Name or service not known`, el contenedor del MCP no está en
`pi-appnet` o cambió de nombre: la URL de `config.yaml` usa el alias `mcp`.

## Apagarlo

```powershell
docker compose -f automation/hermes/compose.yaml down
```

El volumen `pi-hermes-data` conserva sesiones y memoria del agente.
