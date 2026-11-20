#!/usr/bin/env python
"""Importa el backlog de HIA-2026 a Taiga.

Fuentes (ambas versionadas en backlog/):
  jira-import.csv   estructura: epicas, historias, puntos, sprint, etiquetas
  jira-estados.csv  estado real de cada incidencia en el Jira Cloud

Taiga no tiene campo de prioridad: se traduce a etiquetas prio-alta /
prio-media / prio-baja, y los puntos de historia van al campo nativo.

Uso:
    python scripts/taiga-seed.py [--base-url http://127.0.0.1:8084]
"""

import argparse
import csv
import io
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PROYECTO = "HIA-2026"
DESCRIPCION = (
    "Backlog Scrum de la Practica Integradora Final 2026: aplicacion Conduit "
    "contenerizada, base replicada, CI/CD, monitoreo, incidencias, Nextcloud, "
    "automatizacion con n8n y seguridad."
)

# estado de Jira -> nombre del estado en Taiga
ESTADOS = {
    "Por hacer": "New",
    "En curso": "In progress",
    "En revisión": "Ready for test",
    "Listo": "Done",
}

PRIORIDADES = {
    "High": "prio-alta",
    "Highest": "prio-alta",
    "Medium": "prio-media",
    "Low": "prio-baja",
    "Lowest": "prio-baja",
}

SPRINTS = {
    "Sprint 1": ("2026-11-12", "2026-11-13", True),
    "Sprint 2": ("2026-11-13", "2026-11-14", True),
    "Sprint 3": ("2026-11-14", "2026-11-15", True),
    "Sprint 4": ("2026-11-15", "2026-11-16", False),
    "Sprint 5": ("2026-11-16", "2026-11-20", False),
}

# seccion del proyecto -> responsable
RESPONSABLES = [
    (range(1, 6), "dev.tomas"),
    (range(6, 11), "qa.analista"),
    (range(11, 17), "ops.admin"),
]

USUARIOS = [
    ("dev.tomas", "Tomas Dev", "dev.tomas@pi.local"),
    ("qa.analista", "QA Analista", "qa.analista@pi.local"),
    ("ops.admin", "Ops Admin", "ops.admin@pi.local"),
]


class Taiga:
    def __init__(self, base):
        self.base = base.rstrip("/")
        self.token = None

    def _pedir(self, metodo, ruta, datos=None):
        url = self.base + ruta
        cuerpo = None
        cabeceras = {"Content-Type": "application/json"}
        if datos is not None:
            cuerpo = json.dumps(datos).encode("utf-8")
        if self.token:
            cabeceras["Authorization"] = "Bearer " + self.token
        req = urllib.request.Request(url, data=cuerpo, headers=cabeceras, method=metodo)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                texto = r.read().decode("utf-8")
                return r.status, (json.loads(texto) if texto.strip() else None)
        except urllib.error.HTTPError as e:
            texto = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(texto)
            except ValueError:
                return e.code, texto

    def login(self, usuario, clave):
        codigo, datos = self._pedir(
            "POST", "/api/v1/auth", {"type": "normal", "username": usuario, "password": clave}
        )
        if codigo != 200:
            raise SystemExit("no se pudo autenticar: %s %s" % (codigo, datos))
        self.token = datos["auth_token"]
        self.user_id = datos.get("id")
        return datos

    def get(self, ruta):
        return self._pedir("GET", ruta)

    def listar(self, ruta):
        """Recorre todas las paginas: Taiga devuelve 30 objetos por defecto."""
        resultados = []
        separador = "&" if "?" in ruta else "?"
        for pagina in range(1, 60):
            codigo, datos = self.get("%s%spage=%d" % (ruta, separador, pagina))
            if codigo != 200 or not isinstance(datos, list) or not datos:
                break
            resultados.extend(datos)
            if len(datos) < 30:
                break
        return resultados

    def post(self, ruta, datos):
        return self._pedir("POST", ruta, datos)

    def patch(self, ruta, datos):
        return self._pedir("PATCH", ruta, datos)


def leer_env():
    valores = {}
    ruta = os.path.join(RAIZ, ".env")
    for linea in io.open(ruta, encoding="utf-8").read().splitlines():
        if "=" in linea and not linea.strip().startswith("#"):
            k, v = linea.split("=", 1)
            valores[k.strip()] = v.strip()
    return valores


def leer_estructura():
    ruta = os.path.join(RAIZ, "backlog", "jira-import.csv")
    with io.open(ruta, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def leer_estados():
    ruta = os.path.join(RAIZ, "backlog", "jira-estados.csv")
    mapa = {}
    for linea in io.open(ruta, encoding="utf-8").read().splitlines():
        if not linea.strip() or linea.startswith("key|"):
            continue
        partes = linea.split("|", 2)
        if len(partes) == 3:
            mapa[partes[2].strip()] = partes[1].strip()
    return mapa


def responsable_de(etiquetas):
    for etiqueta in etiquetas:
        if etiqueta.startswith("seccion-"):
            try:
                numero = int(etiqueta.split("-")[1])
            except (IndexError, ValueError):
                continue
            for rango, usuario in RESPONSABLES:
                if numero in rango:
                    return usuario
    return "dev.tomas"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8084")
    args = parser.parse_args()

    env = leer_env()
    cliente = Taiga(args.base_url)
    cliente.login(env["TAIGA_ADMIN_USER"], env["TAIGA_ADMIN_PASSWORD"])
    print("autenticado en", args.base_url)

    # --- usuarios -------------------------------------------------------
    # Taiga 6 no permite crear usuarios por API (POST /api/v1/users -> 405):
    # los crea app/taiga/usuarios.py con el ORM antes de este script.
    _, listado = cliente.get("/api/v1/users")
    existentes = {u["username"] for u in listado or []}
    faltan = [u for u, _, _ in USUARIOS if u not in existentes]
    if faltan:
        raise SystemExit(
            "faltan usuarios en Taiga: %s (correr scripts/taiga.ps1 init)"
            % ", ".join(faltan)
        )

    # --- proyecto -------------------------------------------------------
    codigo, proyectos = cliente.get("/api/v1/projects?member=%s" % cliente.user_id)
    proyecto = None
    for p in proyectos or []:
        if p["name"] == PROYECTO:
            proyecto = p
            break
    if proyecto is None:
        codigo, proyecto = cliente.post(
            "/api/v1/projects",
            {
                "name": PROYECTO,
                "description": DESCRIPCION,
                "is_private": False,
                "is_backlog_activated": True,
                "is_kanban_activated": False,
                "is_wiki_activated": True,
                "is_issues_activated": True,
            },
        )
        if codigo != 201:
            raise SystemExit("no se pudo crear el proyecto: %s %s" % (codigo, proyecto))
        print("proyecto creado:", proyecto["slug"])
    else:
        print("proyecto existente:", proyecto["slug"])

    pid = proyecto["id"]
    codigo, detalle = cliente.get("/api/v1/projects/%d" % pid)
    roles = detalle.get("roles") or []
    puntos_validos = {
        p["value"]: p["id"]
        for p in (detalle.get("points") or [])
        if p.get("value") is not None
    } or {1: 1, 2: 2, 3: 3, 5: 5, 8: 8, 13: 13}

    # --- miembros -------------------------------------------------------
    miembros = {m["username"]: m["id"] for m in detalle.get("members") or []}
    rol_miembro = None
    for buscado in ("back", "front", "ux", "design"):
        for rol in roles:
            if rol["name"].lower() == buscado:
                rol_miembro = rol
                break
        if rol_miembro:
            break
    if rol_miembro is None and roles:
        rol_miembro = roles[-1]

    for usuario, _, correo in USUARIOS:
        if usuario in miembros:
            continue
        # el endpoint valida el dominio del correo: hay que pasar el email,
        # no el nombre de usuario
        codigo, datos = cliente.post(
            "/api/v1/memberships",
            {"project": pid, "role": rol_miembro["id"], "username": correo},
        )
        if codigo == 201:
            miembros[usuario] = datos["user"]
            print("miembro agregado:", usuario)
        else:
            print("membership con problemas:", usuario, codigo, str(datos)[:120])

    # --- estados --------------------------------------------------------
    _, estados_us = cliente.get("/api/v1/userstory-statuses?project=%d" % pid)
    _, estados_ep = cliente.get("/api/v1/epic-statuses?project=%d" % pid)

    def buscar(lista, nombre):
        for e in lista:
            if e["name"].lower() == nombre.lower():
                return e["id"]
        for e in lista:
            if e.get("is_closed") and nombre == "Done":
                return e["id"]
        return lista[0]["id"]

    # --- epicas ---------------------------------------------------------
    filas = leer_estructura()
    estados = leer_estados()
    existentes = cliente.listar("/api/v1/epics?project=%d" % pid)
    por_asunto = {e["subject"]: e["id"] for e in existentes}

    epicas = {}
    for fila in filas:
        if fila["Issue Type"] != "Epic":
            continue
        asunto = fila["Summary"].strip()
        if asunto in por_asunto:
            epicas[asunto] = por_asunto[asunto]
            continue
        estado = ESTADOS.get(estados.get(asunto, "Por hacer"), "New")
        codigo, datos = cliente.post(
            "/api/v1/epics",
            {
                "project": pid,
                "subject": asunto,
                "description": fila["Description"].strip(),
                "status": buscar(estados_ep, estado),
                "tags": [t for t in fila["Labels"].split(",") if t],
            },
        )
        if codigo == 201:
            epicas[asunto] = datos["id"]
        else:
            print("epica con problemas:", asunto, codigo, str(datos)[:150])
    print("epicas:", len(epicas))

    # --- sprints --------------------------------------------------------
    milestones = cliente.listar("/api/v1/milestones?project=%d" % pid)
    sprints = {m["name"]: m["id"] for m in milestones}
    for nombre, (inicio, fin, cerrado) in SPRINTS.items():
        if nombre in sprints:
            continue
        codigo, datos = cliente.post(
            "/api/v1/milestones",
            {
                "project": pid,
                "name": nombre,
                "estimated_start": inicio,
                "estimated_finish": fin,
            },
        )
        if codigo == 201:
            sprints[nombre] = datos["id"]
            if cerrado:
                cliente.patch("/api/v1/milestones/%d" % datos["id"], {"closed": True})
        else:
            print("sprint con problemas:", nombre, codigo, str(datos)[:150])

    # Taiga cierra solo un sprint cuando todas sus historias estan Done y lo
    # reabre si despues entra una historia nueva, asi que el cierre real se
    # aplica al final del script (ver "cierre de sprints").
    print("sprints:", len(sprints))

    # --- historias ------------------------------------------------------
    historias = cliente.listar("/api/v1/userstories?project=%d" % pid)
    ya_estan = {h["subject"] for h in historias}

    creadas = 0
    for fila in filas:
        if fila["Issue Type"] == "Epic":
            continue
        asunto = fila["Summary"].strip()
        if asunto in ya_estan:
            continue
        etiquetas = [t for t in fila["Labels"].split(",") if t]
        prioridad = PRIORIDADES.get(fila["Priority"].strip())
        if prioridad:
            etiquetas.append(prioridad)

        estado = ESTADOS.get(estados.get(asunto, "Por hacer"), "New")
        usuario = responsable_de(etiquetas)
        datos = {
            "project": pid,
            "subject": asunto,
            "description": fila["Description"].strip(),
            "status": buscar(estados_us, estado),
            "tags": etiquetas,
        }
        if fila["Sprint"].strip() in sprints:
            datos["milestone"] = sprints[fila["Sprint"].strip()]
        if fila["Epic Link"].strip() in epicas:
            datos["epic"] = epicas[fila["Epic Link"].strip()]
        if usuario in miembros:
            datos["assigned_to"] = miembros[usuario]

        try:
            puntos = int(fila["Story Points"].strip())
        except (ValueError, AttributeError):
            puntos = None
        if puntos is not None:
            # la API espera {rol: id_del_punto}, no el valor
            cercano = min(puntos_validos, key=lambda v: abs(v - puntos))
            if rol_miembro:
                datos["points"] = {str(rol_miembro["id"]): puntos_validos[cercano]}

        codigo, respuesta = cliente.post("/api/v1/userstories", datos)
        if codigo == 201:
            creadas += 1
        else:
            print("historia con problemas:", asunto[:60], codigo, str(respuesta)[:150])

    print("historias creadas:", creadas, "| total en el proyecto:", len(ya_estan) + creadas)

    # --- incidencias que existen en Jira y no en el CSV (agregadas despues) ---
    en_csv = {f["Summary"].strip() for f in filas}
    extra = [s for s in estados if s not in en_csv and s not in ya_estan]
    for asunto in extra:
        estado = ESTADOS.get(estados[asunto], "New")
        datos = {
            "project": pid,
            "subject": asunto,
            "description": "Incidencia agregada al backlog despues de la exportacion inicial.",
            "status": buscar(estados_us, estado),
            "tags": ["seccion-extra"],
        }
        if "dev.tomas" in miembros:
            datos["assigned_to"] = miembros["dev.tomas"]
        codigo, respuesta = cliente.post("/api/v1/userstories", datos)
        if codigo == 201:
            creadas += 1
        else:
            print("extra con problemas:", asunto[:60], codigo, str(respuesta)[:150])
    if extra:
        print("extras fuera del CSV:", len(extra))

    # --- cierre de sprints (al final: agregar historias reabre el sprint) ---
    for nombre, (_, _, cerrado) in SPRINTS.items():
        if nombre not in sprints:
            continue
        _, actual = cliente.get("/api/v1/milestones/%d" % sprints[nombre])
        if actual.get("closed") != cerrado:
            codigo, respuesta = cliente.patch(
                "/api/v1/milestones/%d" % sprints[nombre], {"closed": cerrado}
            )
            estado = "cerrado" if cerrado else "abierto"
            if codigo == 200:
                print("sprint %s -> %s" % (nombre, estado))
            else:
                print("no se pudo dejar %s %s: %s" % (nombre, estado, codigo))

    return 0


if __name__ == "__main__":
    sys.exit(main())
