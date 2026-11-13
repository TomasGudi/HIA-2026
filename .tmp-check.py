import pathlib
import re

p = pathlib.Path("docs/03-checklist-entregables.md")
t = p.read_text(encoding="utf-8")

nuevo_11 = """## \u00a711 Incidencias - R3

| \u2611 | Entregable | Evidencia esperada |
|---|---|---|
| \u2611 | Mantis funcionando | `http://127.0.0.1:8081` (admin) y usuarios `dev.tomas` / `qa.analista` |
| \u2611 | =10 incidencias | 14 en `HIA-2026` (`scripts/mantis-seed.py`) |
| \u2611 | Asignaci\u00f3n y seguimiento | 70 filas en `mantis_bug_history_table` |
| \u2611 | Resoluci\u00f3n | 13 resueltas + 1 cerrada, con `commit_sha` y `pr_url` |

> Requisito: 1 de rendimiento (#1, #2, #10, #13) y 1 de seguridad (#3, #4, #11, #14).

"""

nuevo_13 = """## \u00a713 n8n - R4

| \u2611 | Entregable | Evidencia esperada |
|---|---|---|
| \u2611 | Configuraci\u00f3n | `compose.yaml` (perfil `ops`) + volumen + base `n8n` propia |
| \u2611 | Diagramas | `docs/02-arquitectura.md` \u00a75 + JSON en `automation/n8n/workflows/` |
| \u2611 | Evidencias de ejecuci\u00f3n | `evidence/13/flujo-1.log` (ejecuciones 14, 21, 22) |
| \u2611 | Registro de errores | ejecuci\u00f3n 21 en `error` con Mantis ca\u00eddo |
| \u2611 | Pruebas de integraci\u00f3n | 401 sin token, 400 payload inv\u00e1lido, 200 con incidencia |
| \u2611 | An\u00e1lisis de riesgos | `docs/informe/13-automatizacion.md` \u00a75 |

> Flujos 2 y 3 **no implementados**: el 2 necesita imagen de n8n con `postgresql-client`;
> el 3 depende de Nextcloud (\u00a712). Declarado en el informe.

"""

for patron, nuevo in (
    (r"## \u00a711 Incidencias.*?(?=\n## )", nuevo_11),
    (r"## \u00a713 n8n.*?(?=\n## )", nuevo_13),
):
    if re.search(patron, t, re.S):
        t = re.sub(patron, nuevo, t, count=1, flags=re.S)
    else:
        print("no encontrado:", patron[:20])

p.write_text(t, encoding="utf-8")
print("checklist §11 y §13 actualizados")
