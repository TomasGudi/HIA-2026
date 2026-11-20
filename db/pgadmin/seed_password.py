#!/usr/bin/env python3
"""Guarda la contraseña de la base en pgAdmin sin pasar por la UI.

`setup.py load-servers` ignora el campo Password, así que el servidor queda
registrado pero pgAdmin la pide al conectar. Esto la cifra con la misma clave
que usa pgAdmin en modo escritorio (hash del usuario, porque el contenedor no
tiene keyring con PGADMIN_CONFIG_USE_OS_SECRET_STORAGE=False) y la escribe en
la tabla `server`.

Uso (la contraseña entra por variable de entorno, no por argumento):

  docker exec -e PGGUI_DB_PASSWORD=... pi-pgadmin \
      /venv/bin/python3 /pgadmin4/config/seed_password.py
"""
import os
import sqlite3
import sys

# el módulo se carga por ruta: importar pgadmin.utils arrastra pgadmin/__init__
# y termina en un import circular con config.py
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "pgcrypto", "/pgadmin4/pgadmin/utils/crypto.py")
_crypto = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_crypto)
encrypt = _crypto.encrypt
decrypt = _crypto.decrypt

DB = "/var/lib/pgadmin/pgadmin4.db"
SERVER_NAME = "Practica (primaria)"


def main() -> int:
    password = os.environ.get("PGGUI_DB_PASSWORD")
    if not password:
        print("PGGUI_DB_PASSWORD no definida", file=sys.stderr)
        return 2

    con = sqlite3.connect(DB)
    row = con.execute(
        "SELECT password FROM user WHERE id = 1").fetchone()
    if not row or not row[0]:
        print("usuario de escritorio sin password en la base de pgAdmin",
              file=sys.stderr)
        return 3
    key = row[0]

    target = con.execute(
        "SELECT id FROM server WHERE name = ?", (SERVER_NAME,)).fetchone()
    if not target:
        print(f"servidor '{SERVER_NAME}' no registrado", file=sys.stderr)
        return 4

    stored = encrypt(password, key).hex()
    con.execute(
        "UPDATE server SET password = ?, save_password = 1 WHERE id = ?",
        (stored, target[0]))
    con.commit()

    check = con.execute(
        "SELECT password FROM server WHERE id = ?", (target[0],)).fetchone()[0]
    ok = decrypt(bytes.fromhex(check), key).decode() == password
    print(f"servidor {target[0]}: contraseña guardada, "
          f"verificación {'OK' if ok else 'FALLÓ'}")
    return 0 if ok else 5


if __name__ == "__main__":
    sys.exit(main())
