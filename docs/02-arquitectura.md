# Arquitectura objetivo

Diagramas en Mermaid (se renderizan en GitHub, VS Code y Obsidian; si el informe final va en PDF,
exportarlos como PNG y referenciarlos).

## 1. Red Docker y servicios

```mermaid
flowchart TB
    subgraph INET[Internet]
        U[Usuario / Docente]
        CF[Cloudflare Tunnel<br/>o Tailscale Funnel]
    end

    subgraph EDGE[Red edge]
        PROXY[nginx / traefik<br/>:443 interno]
    end

    subgraph APPNET[Red appnet - interna]
        FE[frontend<br/>nginx :80]
        BE[backend<br/>:3000]
        APPEXP[app-exporter<br/>:9101]
    end

    subgraph DBNET[Red dbnet - sin salida]
        PG[(postgres primary<br/>:5432)]
        PGR[(postgres replica<br/>:5432)]
        PGA[pgadmin :80]
        PGE[postgres-exporter<br/>:9187]
    end

    subgraph OPSNET[Red opsnet]
        PROM[prometheus :9090]
        GRAF[grafana :3000]
        AM[alertmanager :9093]
        N8N[n8n :5678]
        MANTIS[mantis :80]
        NC[nextcloud :80]
        CAD[cadvisor]
        NODE[node-exporter]
        BB[blackbox-exporter]
    end

    U --> CF --> PROXY
    PROXY --> FE
    PROXY -->|/api| BE
    FE -->|proxy_pass /api| BE
    BE --> PG
    BE -.->|lecturas| PGR
    PG -->|streaming WAL| PGR
    PROM --> APPEXP & PGE & CAD & NODE & BB
    PROM --> AM --> N8N
    GRAF --> PROM
    N8N --> MANTIS
    N8N --> NC
    N8N --> PG
```

Reglas duras:
- `dbnet` **no** tiene `ports:` hacia el host. Solo `expose`.
- `pgadmin`, `prometheus`, `grafana`, `n8n`, `mantis`, `nextcloud` **no** publican puertos al host
  salvo en el perfil `dev`; en `prod` se llega por el túnel y con auth.
- `5432` nunca aparece en la URL pública. Es requisito explícito de §9.

## 2. Replicación

```mermaid
flowchart LR
    subgraph P[primaria]
        W[escrituras]
        WAL[(WAL)]
    end
    subgraph R[replica]
        WALR[(WAL recibido)]
        RO[lecturas]
    end
    W --> WAL -->|pg_basebackup -R<br/>streaming async| WALR --> RO
    MON[postgres-exporter<br/>pg_stat_replication] -.-> P
    MON -.-> R
```

- Método: **streaming replication asíncrona** con `pg_basebackup -R`.
- `synchronous_commit=on` en primaria (integridad > latencia para este caso).
- **No hay failover automático.** Sin Patroni/repmgr no se promueve nada solo.
  §6 lo permite explícitamente: "si el equipo afirma contar con failover automático, deberá demostrarlo".
  Nosotros declaramos **failover manual documentado** y lo probamos.
- Métricas expuestas: `pg_stat_replication` (lag en bytes), `pg_last_wal_replay_lsn()`.

## 3. CI/CD

```mermaid
flowchart LR
    DEV[commit en feature/*] --> PR[Pull Request]
    PR --> CI{CI}
    CI -->|lint| L[ok]
    CI -->|test| T[ok]
    CI -->|gitleaks| G[ok]
    CI -->|build imagen| B[ok]
    L & T & G & B -->|todo verde| MERGE[merge a main]
    MERGE --> PUB[push imagen GHCR<br/>tag: SHA + latest]
    PUB --> DEP[deploy: docker compose pull && up -d]
    DEP --> HC{healthcheck}
    HC -->|falla| RB[rollback al tag anterior]
    HC -->|ok| DONE[listo]
```

- Sin secretos en el repo: todo en GitHub Secrets.
- El pipeline **debe fallar** si el test falla (se prueba con un commit roto a propósito → evidencia §8).
- Deploy: `self-hosted` runner o SSH desde el workflow. Rollback = redeploy del tag anterior (~1-2 min).

## 4. Monitoreo

```mermaid
flowchart LR
    NODE[node-exporter] --> PROM
    CAD[cadvisor] --> PROM
    PGE[postgres-exporter] --> PROM
    APPX[app /metrics] --> PROM
    BB[blackbox-exporter] --> PROM
    PROM --> GRAF[Grafana<br/>8 paneles]
    PROM --> AM[alertmanager]
    AM -->|webhook| N8N[n8n flujo 1]
    N8N --> MANTIS[Mantis issue]
    N8N --> NOTIF[notificacion]
```

Paneles obligatorios (§10): CPU, memoria, disco, red, estado/reinicios de contenedores,
disponibilidad de la app, métricas de DB, conexiones activas y consultas lentas,
estado de replicación.

> Advertencia que el enunciado marca explícitamente: **no afirmar** que se monitorean consultas
> SQL individuales si solo hay métricas agregadas del motor. El panel se llama
> "DB – métricas del motor", no "consultas SQL".

## 5. n8n

```mermaid
flowchart TB
    subgraph F1[Flujo 1 - alerta a incidencia]
        A1[Alertmanager webhook] --> A2[validar payload]
        A2 --> A3[crear issue Mantis]
        A3 --> A4[notificar responsable]
        A2 -.->|invalido| A5[log error]
    end
    subgraph F2[Flujo 2 - backup verificado]
        B1[Cron 03:00] --> B2[ejecutar pg_dump]
        B2 --> B3{integridad ok?}
        B3 -->|si| B4[registrar estado]
        B3 -->|no| B5[notificar error + issue]
    end
    subgraph F3[Flujo 3 - informe IA]
        C1[Cron/metricas] --> C2[script Python analiza]
        C2 --> C3[resumir informe]
        C3 --> C4[subir a Nextcloud]
        C4 --> C5[notificar equipo]
    end
```

Los 3 flujos usan **credenciales de n8n** (no secretos hardcodeados) y webhooks con header token.

## 6. Publicación en Internet (alternativa elegida)

```
Internet → Cloudflare (HTTPS, WAF básico) → cloudflared (túnel saliente) → nginx → app
```

| Opción | Costo | HTTPS | Pros | Contras |
|---|---|---|---|---|
| **Cloudflare Tunnel** (elegida) | Gratis | Automático | No abre puertos en el router, no expone IP, WAF/rate-limit | Depende de Cloudflare; dominio o `trycloudflare.com` |
| Tailscale Funnel | Gratis | Automático | Simple, identidad por dispositivo | URL `ts.net`; menos "producto" |
| VPS | Pago | Manual (Caddy/LE) | Control total | Costo; el enunciado no lo exige |

Riesgo a documentar (§9 lo pide): si el túnel cae, la app queda inaccesible → **plan B Tailscale
configurado y probado antes de la demo**.
