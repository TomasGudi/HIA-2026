# 10 — Publicación en Internet

## 1. Objetivo

Que la aplicación sea accesible desde Internet **sin abrir un solo puerto** en el host, con HTTPS,
y que las herramientas de administración queden detrás de autenticación. Además, demostrar con
`nmap` que la superficie expuesta es la mínima.

## 2. Arquitectura de publicación

```
                    Internet
                       │  HTTPS 443
                       ▼
        ┌──────────────────────────────┐
        │  Cloudflare (borde)          │  TLS, DDoS, IP del origen oculta
        │  104.16.x.x                  │
        └──────────────┬───────────────┘
                       │  túnel saliente (QUIC/HTTP2)
                       │  el host NO abre puertos entrantes
                       ▼
        ┌──────────────────────────────┐
        │  cloudflared (contenedor)    │
        └───┬──────────────────┬───────┘
            │ appnet           │ dbnet
            ▼                  ▼
   frontend:80            edge:8080 (pgAdmin)
      │                   edge:8081 (Mantis)
      ▼                        │
   backend:3000 ──▶ db:5432    ├──▶ pgadmin:80
                               └──▶ mantis:80

   Host: 127.0.0.1:8090 (frontend), 127.0.0.1:8088/8089 (edge),
         127.0.0.1:9090/9093/3001 (monitoreo), 127.0.0.1:5433 (DB)
         → nada escucha en la interfaz de LAN.
```

La clave: **el túnel es una conexión saliente**. `cloudflared` inicia la conexión hacia Cloudflare y
mantiene un canal abierto; Cloudflare le reenvía el tráfico. No hay NAT, ni port forwarding, ni IP
pública, ni certificado que renovar en el origen.

## 3. Endpoints publicados

| Servicio | URL pública (túnel rápido) | Auth |
|---|---|---|
| Aplicación | `https://macintosh-pension-california-grey.trycloudflare.com` | login propio de la app (JWT) |
| pgAdmin | `https://progress-bulk-trailers-traditions.trycloudflare.com` | **Basic auth** + login de pgAdmin |
| Mantis | `https://experts-baseball-simulation-floating.trycloudflare.com` | **Basic auth** + login de Mantis |

Comando usado (túnel rápido, sin cuenta):

```powershell
docker run -d --name pi-tunnel --network pi-appnet cloudflare/cloudflared:latest \
  tunnel --no-autoupdate --url http://frontend:80
```

> **Estas URLs son efímeras**: los túneles rápidos mueren al detener el contenedor y el nombre
> cambia. Para la defensa hay que levantarlos de nuevo y usar la URL que imprima el log. En
> producción se usa un **túnel con nombre** y un dominio propio (ver §7).

## 4. Autenticación en rutas administrativas

`edge/nginx.conf` publica pgAdmin y Mantis detrás de HTTP Basic:

```nginx
auth_basic           "Administracion - Practica Integradora";
auth_basic_user_file /etc/nginx/.htpasswd;
```

- El hash es **apr1** (`$apr1$...`), no la contraseña: `edge/.htpasswd` se puede versionar.
- La contraseña vive en `.env` (`EDGE_ADMIN_PASSWORD`) y no se versiona.
- Basic auth **no reemplaza** el login propio de cada herramienta: lo antepone. Dos barreras.

Verificación sobre HTTPS público:

| Petición | Resultado |
|---|---|
| `GET pgadmin/` sin credenciales | **401** |
| `GET mantis/` sin credenciales | **401** |
| `GET pgadmin/` con clave incorrecta | **401** |
| `GET pgadmin/` con credenciales | **308** → login de pgAdmin |
| `GET mantis/` con credenciales | **302** → login de Mantis |

## 5. Verificación de superficie con `nmap`

### 5.1 Desde la LAN (¿el host expone algo?)

```powershell
docker run --rm instrumentisto/nmap -Pn -T4 -p 5000,3001,5433,8080,8081,8088,8089,8090,9090,9093 192.168.1.8
```

```
PORT     STATE    SERVICE
3001/tcp filtered nessus
5000/tcp filtered upnp
5433/tcp filtered pyrrho
8080/tcp filtered http-proxy
8081/tcp filtered blackice-icecap
8088/tcp filtered radan-http
8089/tcp filtered unknown
8090/tcp filtered opsmessaging
9090/tcp filtered zeus-admin
9093/tcp filtered copycat
```

**Todos `filtered`.** No es casualidad: cada puerto del compose está publicado como
`127.0.0.1:<puerto>`, así que Docker los ata al loopback y no a la interfaz de red.

### 5.2 Desde Internet (¿qué se ve del otro lado?)

```powershell
docker run --rm instrumentisto/nmap -Pn -p 80,443 macintosh-pension-california-grey.trycloudflare.com
```

```
Nmap scan report for ...trycloudflare.com (104.16.231.132)
PORT    STATE SERVICE
80/tcp  open  http
443/tcp open  https
```

Lo que se ve es **Cloudflare**, no el host. El origen no tiene dirección pública: no hay nada que
escanear del otro lado. Ese es el punto del túnel.

## 6. Riesgos y limitaciones

| Riesgo | Impacto | Mitigación / decisión |
|---|---|---|
| Túnel rápido sin SLA | la URL muere y no hay garantía de uptime | es para demo; producción usa túnel con nombre |
| Basic auth sin MFA | una contraseña filtrada da acceso al panel | contraseña fuerte en `.env` + login propio de la herramienta; Cloudflare Access para MFA |
| pgAdmin expuesto a Internet | superficie de ataque alta si hay un CVE | se publica solo con auth; en producción conviene VPN o Access |
| Cloudflare ve el tráfico | el TLS termina en el borde | aceptable para esta práctica; alternativa: túnel con TLS de extremo a extremo |
| Sin rate limiting ni WAF | fuerza bruta / abuso | reglas de Cloudflare (no configuradas, requieren cuenta) |
| Un solo nodo | si el host cae, el túnel cae | no hay alta disponibilidad; es una limitación del alcance |
| Sin logs de acceso centralizados | difícil auditar intentos | se mitiga con §10 (métricas) y logs de `cloudflared` |

**Lo que NO se hizo y por qué**: no se configuró Cloudflare Access (requiere cuenta y dominio), no
se configuró WAF ni rate limiting, y no se usó un túnel con nombre. Todo eso es la evolución natural
de esta arquitectura, no una omisión silenciosa.

## 7. Plan B: Tailscale Funnel

Se evaluó como alternativa. **No se implementó**: requiere cuenta de Tailscale y un `tailscale up`
interactivo, igual que un túnel con nombre de Cloudflare requiere dominio propio.

Procedimiento si se quisiera:

```powershell
tailscale up --advertise-exit-node=false
tailscale funnel 8090
```

Diferencia con Cloudflare: Funnel publica el servicio en `*.ts.net` sin abrir puertos, pero el
tráfico entra por la red de Tailscale (WireGuard) y no hay borde con DDoS/WAF. Para esta práctica
Cloudflare es mejor opción porque además aporta TLS y ocultamiento del origen.

## 8. Evidencia

| Evidencia | Archivo |
|---|---|
| Acceso externo (HTTPS, auth, versión desplegada) | `evidence/09/acceso-externo.log` |
| `nmap` desde la LAN y contra el endpoint público | `evidence/09/nmap.log` |
| Configuración del borde | `edge/nginx.conf`, `edge/.htpasswd` |
| Servicios en `compose.yaml` | `edge`, túneles creados con `docker run` |
