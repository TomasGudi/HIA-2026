"""Crea el administrador y los usuarios de trabajo de Taiga.

Se ejecuta dentro del contenedor, con el contexto de Django:

    Get-Content app/taiga/usuarios.py |
        docker compose --profile ops run --rm -T --entrypoint python taiga-back manage.py shell

Taiga 6 no permite crear usuarios por API (POST /api/v1/users responde 405),
asi que se usa el ORM. El script es idempotente: se puede correr las veces que
haga falta.
"""

import os

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "settings")
django.setup()

from django.contrib.auth import get_user_model  # noqa: E402

Usuario = get_user_model()
clave = os.environ["TAIGA_ADMIN_PASSWORD"]

administrador = os.environ.get("TAIGA_ADMIN_USER", "admin")
correo_admin = os.environ.get("TAIGA_ADMIN_EMAIL", "admin@example.com")

if Usuario.objects.filter(username=administrador).exists():
    print("existe:", administrador)
else:
    Usuario.objects.create_superuser(
        username=administrador, email=correo_admin, password=clave
    )
    print("creado (superusuario):", administrador)

equipo = [
    ("dev.tomas", "Tomas Dev", "dev.tomas@pi.local"),
    ("qa.analista", "QA Analista", "qa.analista@pi.local"),
    ("ops.admin", "Ops Admin", "ops.admin@pi.local"),
]

for usuario, nombre, correo in equipo:
    if Usuario.objects.filter(username=usuario).exists():
        print("existe:", usuario)
        continue
    Usuario.objects.create_user(
        username=usuario, email=correo, password=clave, full_name=nombre
    )
    print("creado:", usuario)
