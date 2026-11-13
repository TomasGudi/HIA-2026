# 15 — Backup y restauración

## 1. Política

| Aspecto | Decisión | Motivo |
|---|---|---|
| Tipo | **dump lógico** (`pg_dump`) comprimido con gzip | independiente de la versión del motor; restaurable en otra instancia |
| Ejecución | `scripts/backup.ps1`, pensado para correr por cron (n8n, §13) | el flujo 2 del enunciado verifica el resultado del backup |
| Retención | 7 días (parámetro `-RetentionDays`) | evita llenar el disco; se puede subir sin tocar el código |
| Destino | `./backups/` (montado en el contenedor, **fuera del repo**) | un backup dentro del repo se versiona y se filtra |
| Verificación | restauración en base limpia + comparación de conteos | un backup que nunca se restauró no es un backup |

## 2. Ejecución y resultados medidos

```powershell
./scripts/backup.ps1                 # solo backup
./scripts/backup.ps1 -RestoreTest    # backup + restauración verificada
```

| Métrica | Valor |
|---|---|
| Tamaño de la base | 8.551 MB |
| Tamaño del backup | **402,6 MB** (gzip -6, ~21:1) |
| Tiempo de backup | **84,9 s** |
| Tiempo de restauración | **746,1 s** (~12,5 min) |

Evidencia: `evidence/04/backup-restore.log`.

## 3. Prueba de restauración

Procedimiento del script:

1. `pg_dump --no-owner --no-privileges | gzip` dentro del contenedor (no requiere `psql` en el host).
2. `CREATE DATABASE restore_test` en limpio.
3. `gunzip -c | psql` sobre la base nueva.
4. Comparación de conteos origen vs. restaurada.
5. `DROP DATABASE restore_test`.

Resultado:

| Tabla | Origen | Restaurada |
|---|---|---|
| `Article` | 6.000.001 | 6.000.001 |
| `Comment` | 6.000.001 | 6.000.001 |
| `User` | 200.001 | 200.001 |
| `Tag` | 5.002 | 5.002 |
| `_ArticleToTag` | 6.000.002 | 6.000.002 |
| `_UserFavorites` | 6.000.000 | 6.000.000 |

Los conteos no son redondos porque incluyen las filas creadas por las pruebas E2E y por §5
(usuario `tomas_demo`, artículo de prueba, relaciones). Eso es intencional: demuestra que el backup
captura el estado **real**, no el dataset recién cargado.

## 4. Persistencia de datos (volúmenes)

Prueba: `docker compose --profile ops down` (**sin** `-v`) y `up -d` de nuevo.

| Verificación | Resultado |
|---|---|
| Conteos tras recrear contenedores | idénticos a los de antes |
| `GET /api/articles` tras el reinicio | 200 en 0,23 s |
| Servicios | todos `healthy` |

Evidencia: `evidence/04/persistencia.txt`.

> `down -v` sí borra `pi-pgdata`: en ese caso la base se regenera con `scripts/db.ps1 seed`
> (~13 min). Es la diferencia que hay que saber explicar en la defensa.

## 5. Limitaciones

- El backup es **lógico**: 12,5 min de restauración para 8,5 GB. Un backup físico (`pg_basebackup`)
  sería mucho más rápido, pero es específico de la versión y del clúster.
- No hay backup incremental ni envío a almacenamiento externo: si se pierde el host, se pierden
  backups y base. Se documenta como mejora (§15.16) y es el punto que justifica la réplica de §6.
- El script no cifra el dump. Para datos reales habría que cifrarlo (`age`/`gpg`) antes de sacarlo
  del host.
- La retención se aplica por fecha de archivo; no hay verificación de integridad del dump más allá
  de la restauración de prueba manual.

## 6. Evidencia

| Evidencia | Archivo |
|---|---|
| Script | `scripts/backup.ps1` |
| Backup + restauración con conteos | `evidence/04/backup-restore.log` |
| Persistencia tras recrear contenedores | `evidence/04/persistencia.txt` |
| Volumen y tamaño de la base | `evidence/04/volumen.txt` |
