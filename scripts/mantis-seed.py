"""Carga las incidencias de ejemplo en Mantis (§11).

Usa la API REST con el token de `.env` (MANTIS_API_TOKEN). Es idempotente:
si una incidencia con el mismo resumen ya existe, no la vuelve a crear.

Uso:
    python scripts/mantis-seed.py
"""
import json
import pathlib
import sys
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:8081/api/rest"
ROOT = pathlib.Path(__file__).resolve().parent.parent


def token():
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        if line.startswith("MANTIS_API_TOKEN="):
            return line.split("=", 1)[1].strip()
    sys.exit("falta MANTIS_API_TOKEN en .env")


TOKEN = token()


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Authorization", TOKEN)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30)  # nosec B310 - URL constante, no viene del usuario as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


# (resumen, categoria, severidad, prioridad, estado, resolucion, descripcion, nota)
INCIDENCIAS = [
    (
        "GET /api/articles tarda 7,9 s con 6M de filas",
        "Rendimiento", "major", "urgent", "resolved", "fixed",
        "El listado principal hace COUNT(*) y ORDER BY sobre article sin índice. "
        "Con 6M de filas el tiempo de respuesta es 7,9 s y el pool de conexiones se satura.",
        "Corregido en PR #2. Se agregó índice en (created_at, id) y se limitó el COUNT a 10.000. "
        "Medición posterior: 0,19 s en la API (antes 7,9 s). Evidencia: evidence/05/.",
    ),
    (
        "Filtro por tag sin índice GIN: 3,5 s",
        "Rendimiento", "major", "high", "resolved", "fixed",
        "GET /api/articles?tag=x recorre toda la tabla porque tagList es un array sin índice. "
        "Consulta Q7: 3.565 ms.",
        "Índice GIN sobre tagList (PR #2). Q7: 3.565 ms -> 1,4 ms. Costo de escritura medido y "
        "documentado en docs/informe/07-optimizacion-sql.md.",
    ),
    (
        "Login permite enumerar usuarios por mensaje de error",
        "Seguridad", "major", "high", "resolved", "fixed",
        "El endpoint devuelve 'email not found' cuando el usuario no existe y 'wrong password' "
        "cuando la contraseña es incorrecta: permite enumerar cuentas.",
        "Se unificó la respuesta a 401 con mensaje genérico y se agregó comparación de tiempo "
        "constante. Verificado con dos intentos: misma respuesta para usuario inexistente y "
        "contraseña incorrecta.",
    ),
    (
        "Webhook de n8n acepta cualquier POST sin token",
        "Seguridad", "critical", "urgent", "resolved", "fixed",
        "El flujo 1 se dispara con cualquier petición: un tercero podría crear incidencias "
        "falsas o inundar Mantis.",
        "Se exige el header x-webhook-token en el nodo IF del flujo 1. Prueba negativa: POST sin "
        "header devuelve 401 y no crea incidencia (evidence/13/).",
    ),
    (
        "La réplica no acepta lecturas (hot_standby apagado)",
        "Infraestructura", "major", "high", "resolved", "fixed",
        "El standby arranca pero rechaza conexiones: 'the database system is starting up'.",
        "Se agregó hot_standby=on al comando del servicio db-replica (PR #4). Verificado: "
        "pg_is_in_recovery()=true y consultas de lectura OK.",
    ),
    (
        "El contenedor de réplica vuelve a clonar en cada reinicio",
        "Infraestructura", "minor", "normal", "resolved", "fixed",
        "pg_basebackup corría siempre y tardaba ~3 minutos en cada arranque.",
        "Entrypoint condicional: solo clona si el volumen no tiene PG_VERSION (PR #4). "
        "Reinicio verificado: arranca en segundos sin re-clonar.",
    ),
    (
        "Carga inicial generó 38 GB de WAL",
        "Base de Datos", "major", "high", "resolved", "fixed",
        "max_wal_size en el default (1 GB) provocaba checkpoints constantes y full-page writes "
        "durante la carga de 24M de filas.",
        "ALTER SYSTEM SET max_wal_size='8GB' y checkpoint_timeout='15min' (D-20). El WAL bajó y la "
        "carga terminó sin llenar el disco. Documentado en docs/05-decisiones.md.",
    ),
    (
        "Backups sin verificación de restauración",
        "Base de Datos", "critical", "urgent", "resolved", "fixed",
        "Se hacía pg_dump pero nunca se probaba restaurar: un backup roto se descubre en el peor "
        "momento.",
        "scripts/backup.ps1 -RestoreTest restaura en una base temporal y compara conteos. "
        "Resultado: 402,6 MB en 84,9 s, restore 746,1 s, conteos idénticos (evidence/04/).",
    ),
    (
        "Frontend no compila en Node 20 (CRA 1.1.1 de 2018)",
        "Aplicacion", "critical", "urgent", "resolved", "fixed",
        "react-scripts 1.1.1 falla con OpenSSL 3 y no soporta Node 20: el build de CI no puede "
        "pasar.",
        "Frontend reescrito con Vite + React 18 (D-18). Build reproducible en CI con Node 20 y "
        "artefacto publicado.",
    ),
    (
        "Contador de artículos hace COUNT(*) sobre 6M de filas",
        "Aplicacion", "major", "high", "resolved", "fixed",
        "El endpoint de listado calcula el total con COUNT(*) completo en cada request.",
        "Se limitó el conteo a 10.000 (cap) porque la UI no muestra más. Medido: 7,9 s -> 0,19 s "
        "en GET /api/articles.",
    ),
    (
        "Panel /admin de Mantis accesible sin restricción",
        "Seguridad", "major", "high", "resolved", "fixed",
        "El instalador y el panel de administración quedaban expuestos en la ruta /admin.",
        "Se bloquea por Apache con 403 y se habilita solo para actualizaciones de esquema. "
        "Verificado: GET /admin -> 403.",
    ),
    (
        "Puertos del stack publicados en 0.0.0.0",
        "Infraestructura", "critical", "urgent", "closed", "fixed",
        "DB, pgAdmin y monitoreo escuchaban en todas las interfaces: visibles desde la LAN.",
        "Todos los puertos pasaron a 127.0.0.1 (PR #8). Verificado con nmap desde la LAN: todos "
        "filtered; el único acceso externo es el túnel de Cloudflare.",
    ),
    (
        "Alerta de CPU no dispara con stress-ng al 79%",
        "Rendimiento", "minor", "normal", "resolved", "fixed",
        "La prueba de carga usaba --cpus 6 sobre 8 vCPU y el umbral era 85%: la regla no podía "
        "disparar.",
        "Se corrigió la prueba (sin --cpus, 16 workers) y se sostuvo 13 minutos. CPU 100%, alerta "
        "firing a los 564 s (evidence/10/alerta-stress.log).",
    ),
    (
        "Falta de autenticación en las rutas administrativas publicadas",
        "Seguridad", "critical", "urgent", "resolved", "fixed",
        "pgAdmin y Mantis quedaban accesibles desde Internet sin barrera previa al publicar por "
        "túnel.",
        "edge/nginx.conf aplica HTTP Basic (apr1) delante de ambos. Verificado sobre HTTPS "
        "público: 401 sin credenciales y con clave incorrecta (evidence/09/acceso-externo.log).",
    ),
]


def existentes():
    code, data = call("GET", "/issues?project_id=1&page_size=100")
    if code != 200 or not isinstance(data, dict):
        return set()
    return {i["summary"] for i in data.get("issues", [])}


def main():
    ya = existentes()
    creadas = 0
    for resumen, cat, sev, pri, estado, resol, desc, nota in INCIDENCIAS:
        if resumen in ya:
            continue
        code, data = call("POST", "/issues", {
            "summary": resumen,
            "description": desc,
            "category": {"name": cat},
            "project": {"id": 1},
            "severity": {"name": sev},
            "priority": {"name": pri},
        })
        if code not in (200, 201):
            print("ERROR al crear:", resumen, code, str(data)[:200])
            continue
        issue = data.get("issue", data)
        iid = issue["id"]
        creadas += 1

        # asignación + estado (genera historial)
        call("PATCH", f"/issues/{iid}", {
            "handler": {"name": "dev.tomas"},
            "status": {"name": estado},
            "resolution": {"name": resol},
        })
        call("POST", f"/issues/{iid}/notes", {"text": nota})
        print(f"#{iid} {cat:15} {estado:8} {resumen[:60]}")

    print(f"\ncreadas: {creadas} | total en el proyecto: {len(existentes())}")


if __name__ == "__main__":
    main()
