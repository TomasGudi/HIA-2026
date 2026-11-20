# n8n — notas de operación

n8n corre en el perfil `ops` del compose, con su propia base en PostgreSQL
(`n8n`) y los flujos versionados en `workflows/`.

```powershell
docker compose --profile ops up -d n8n
# UI local
start http://127.0.0.1:5678
```

## Credenciales del owner

| | |
|---|---|
| Email | `admin@hia.local` |
| Password | `N8N_OWNER_PASSWORD` del `.env` |

Se puede cambiar desde **Settings → Personal → Change password**.

## Si vuelve a pedir `/setup`

Síntoma: el navegador redirige a `http://127.0.0.1:5678/setup` aunque ya exista
un owner, y el formulario no deja crear otro.

Causa: n8n decide el wizard por el flag `userManagement.isInstanceOwnerSetUp`,
no por la existencia del usuario. Si el owner quedó creado con email vacío y el
flag en `false`, el estado es inconsistente.

Diagnóstico:

```sql
-- en la base n8n
SELECT email, role FROM "user";
SELECT key, value FROM settings WHERE key = 'userManagement.isInstanceOwnerSetUp';
```

Arreglo aplicado (conserva los flujos, que pertenecen a ese usuario):

1. Completar el owner que ya existe (email + hash bcrypt de la contraseña).
2. Poner el flag en `true`.
3. `docker restart pi-n8n` (el flag se lee al arrancar).

```powershell
# hash bcrypt con el propio n8n
docker exec pi-n8n node -e "const b=require('/usr/local/lib/node_modules/n8n/node_modules/bcryptjs');console.log(b.hashSync('NUEVA-CLAVE',10))"
```

```sql
UPDATE "user"
   SET email = 'admin@hia.local',
       password = '<hash bcrypt>',
       "updatedAt" = now()
 WHERE role = 'global:owner';

UPDATE settings SET value = 'true'
 WHERE key = 'userManagement.isInstanceOwnerSetUp';
```

Verificación:

```powershell
curl.exe -s http://127.0.0.1:5678/rest/settings   # showSetupOnFirstLoad: false
# login (el campo es `email`, no `emailOrLdapLoginId`)
curl.exe -s -X POST http://127.0.0.1:5678/rest/login -H "Content-Type: application/json" -d '{\"email\":\"admin@hia.local\",\"password\":\"...\"}'
```

## Notas

- `N8N_HOST=127.0.0.1` y `WEBHOOK_URL=http://n8n:5678/`: pensado para uso local y
  para que los flujos se llamen por nombre dentro de Docker. Si algún día se
  publica por el túnel, hay que ajustar `N8N_EDITOR_BASE_URL` y `WEBHOOK_URL` a
  la URL pública, o los enlaces del editor van a apuntar a loopback.
- El contenedor importa los flujos de `workflows/` solo si la base está vacía;
  reiniciarlo no duplica nada.
