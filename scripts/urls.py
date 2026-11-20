#!/usr/bin/env python
"""Sincroniza las URLs de los tuneles en CREDENCIALES.local.md.

Los quick tunnels cambian de hostname cada vez que se recrean. Este script
lee la URL que quedo en el log de cada contenedor cloudflared y reescribe la
fila correspondiente de la tabla de accesos, para que el archivo de
credenciales nunca quede con URLs muertas.

Uso:
    python scripts/urls.py            # solo muestra
    python scripts/urls.py --escribir # ademas actualiza el .md
"""

import argparse
import io
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "CREDENCIALES.local.md")

# contenedor -> etiqueta de la primera celda de la tabla
TUNELES = [
    ("pi-tunnel", "Aplicación"),
    ("pi-tunnel-taiga", "Taiga"),
    ("pi-tunnel-admin", "pgAdmin"),
    ("pi-tunnel-mantis", "Mantis"),
    ("pi-tunnel-nextcloud", "Nextcloud"),
]

URL = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")


def url_de(contenedor):
    try:
        salida = subprocess.run(
            ["docker", "logs", contenedor], capture_output=True, text=True, timeout=30
        ).stdout + subprocess.run(
            ["docker", "logs", contenedor], capture_output=True, text=True, timeout=30
        ).stderr
    except (subprocess.SubprocessError, FileNotFoundError):
        return None
    encontradas = URL.findall(salida)
    return encontradas[0] if encontradas else None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--escribir", action="store_true")
    args = parser.parse_args()

    urls = {}
    for contenedor, etiqueta in TUNELES:
        urls[etiqueta] = url_de(contenedor)

    ancho = max(len(e) for e in urls)
    for etiqueta, url in urls.items():
        print("%-*s %s" % (ancho, etiqueta, url or "(sin URL: el tunel no esta corriendo)"))

    if not args.escribir:
        return 0

    if not os.path.exists(DESTINO):
        print("\nno existe CREDENCIALES.local.md: nada que actualizar")
        return 0

    lineas = io.open(DESTINO, encoding="utf-8").read().splitlines()
    cambios = 0
    for i, linea in enumerate(lineas):
        if "trycloudflare.com" not in linea or not linea.lstrip().startswith("|"):
            continue
        celdas = linea.split("|")
        if len(celdas) < 3:
            continue
        primera = celdas[1]
        for etiqueta, url in urls.items():
            if url and etiqueta.lower() in primera.lower():
                nueva = URL.sub(url, linea)
                if nueva != linea:
                    lineas[i] = nueva
                    cambios += 1
                break

    io.open(DESTINO, "wb").write(("\n".join(lineas) + "\n").encode("utf-8"))
    print("\nfilas actualizadas en CREDENCIALES.local.md:", cambios)
    return 0


if __name__ == "__main__":
    sys.exit(main())
