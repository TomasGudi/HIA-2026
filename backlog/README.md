# Product Backlog

## Estado real en Jira (13/11/2026)

- Sitio: `tomassgudi-1794538432846.atlassian.net` · Proyecto **HIA-Scrum-2026 (`HS2`)** · Scrum, **team-managed**
- Board: https://tomassgudi-1794538432846.atlassian.net/jira/software/projects/HS2/boards/3
- **136 incidencias creadas por API**: `HS2-1` … `HS2-136` (15 épicas + 121 historias/tareas)
- Jerarquía: **team-managed usa `Parent`**, no `Epic Link` → los 121 hijos ya están colgados de su épica
- Story Points: campo **`Story point estimate`** (`customfield_10016`), cargado en los 121 ítems
- **5 sprints creados y poblados** (115 ítems): `Sprint 1 - Fundaciones` (18), `Sprint 2 - Datos y app` (21),
  `Sprint 3 - Rendimiento y entrega` (22), `Sprint 4 - Operación` (25), `Sprint 5 - Cierre` (29)
- 6 ítems opcionales quedan **sin sprint** (label `backlog`) → mejoras futuras §15.16
- Estado de los sprints: `future`. **Sprint 1 se inicia a mano** cuando se arranca a trabajar (botón *Start sprint*)

> El CSV de abajo ya no hace falta para poblar el proyecto: quedó como **respaldo versionado** y para
> recrear el tablero si se borra. Se mantiene porque un backlog en un archivo es más fácil de revisar
> en un diff que 136 issues en la nube.

Archivo: **`backlog/jira-import.csv`** · 136 filas = **15 épicas + 121 ítems**
(`Story` para lo funcional, `Task` para lo técnico) · separador coma, campos entre comillas.

## Composición

| Épica | Sección | Ítems | Puntos |
|---|---|---|---|
| E01 Selección y diagnóstico | §1 | 4 | 8 |
| E02 Gestión ágil (Scrum) | §2 | 7 | 12 |
| E03 Control de versiones y calidad | §3 | 8 | 14 |
| E04 Contenerización de la base de datos | §4 | 12 | 29 |
| E05 Optimización y análisis SQL | §5 | 10 | 32 |
| E06 Clúster y replicación | §6 | 8 | 21 |
| E07 Contenerización de la aplicación | §7 | 7 | 15 |
| E08 Integración y despliegue continuos | §8 | 9 | 20 |
| E09 Publicación y acceso desde Internet | §9 | 7 | 13 |
| E10 Monitoreo con Prometheus y Grafana | §10 | 10 | 27 |
| E11 Gestión de incidencias (Mantis) | §11 | 6 | 16 |
| E12 Gestión documental (Nextcloud) | §12 | 5 | 9 |
| E13 Automatización con n8n | §13 | 10 | 32 |
| E14 Seguridad informática y amenazas | §14 | 10 | 26 |
| E15 Documentación final y defensa | §15 | 8 | 21 |
| — Extras opcionales (sin sprint) | — | 6 | 23 |
| **Total** | | **121** | **295** |

Los totales por épica incluyen los ítems opcionales de esa épica.
El backlog cubre lo que exige el enunciado: no solo funcionalidades, sino **infraestructura (§4, §7, §9),
pruebas (§5, §6, §7, §10, §14), seguridad (§3, §8, §13, §14), documentación (§12, §15) y despliegue (§8)**.

## Calendario de sprints

Sprints de **un día** — en una ventana de 5 días, el daily *es* el sprint. Los sprints son por
dependencia técnica, no por sección del enunciado (el orden del enunciado no es ejecutable).

| Sprint | Fecha | Objetivo | Ítems | Puntos |
|---|---|---|---|---|
| Sprint 1 | jue 12/11 | Fundaciones: repo, Jira, compose de DB, esquema, script de seed | 18 | 35 |
| Sprint 2 | vie 13/11 | Datos reales: carga y medición, primeras optimizaciones, app contenerizada | 21 | 47 |
| Sprint 3 | sáb 14/11 | Rendimiento y entrega: optimización completa, réplica, CI, túnel | 22 | 59 |
| Sprint 4 | dom 15/11 | Operación: monitoreo, alertas, Mantis, escaneos de seguridad | 27 | 64 |
| Sprint 5 | lun 16/11 | Cierre: n8n, Nextcloud, seguridad restante, documentación | 27 | 67 |
| — | mar 17/11 | **Congelado**: solo ensayo de demo y entrega | 0 | 0 |
| Backlog | — | Extras opcionales no comprometidos | 6 | 23 |

## ¿Es realista? Los números, sin maquillaje

- Equipo: 5 personas × 5 días × ~9 h = **~225 horas-persona**.
- Comprometido: **272 puntos** (295 − 23 opcionales) ≈ **204 h** si 1 punto ≈ 45 min de trabajo enfocado.
- **Holgura: ~10%.** Es decir: entra, pero sin margen para reinventar nada. De ahí la regla de reutilizar
  la app, contenerizar sin reescribir y no agregar herramientas fuera del stack.

Si el equipo se atrasa, el orden de recorte **ya está decidido** (no se decide en caliente):

1. Extras del `Backlog` (23 pt) — nunca entran.
2. `Extra: retención larga de métricas` y `segunda réplica` ya están fuera.
3. `E05 Ajustar parámetros del motor` (3 pt) → se documenta como análisis sin medición.
4. `E12 Verificar usuario no autorizado` (1 pt) → se cubre con la matriz de permisos.
5. **Nunca se recorta**: §4 (volumen de datos), §6 (replicación), §9 (acceso externo), §11 (10 incidencias).
   Son las secciones con requisitos numéricos explícitos en el enunciado.

Todo recorte se registra en `docs/05-decisiones.md` y en `docs/informe/16-limitaciones.md`.

## Cómo importarlo en Jira Free (10 minutos)

1. **Crear el proyecto**: tipo **Scrum**, clave corta (ej. `PI26`). Un solo proyecto para todo.

> **Kanban no sirve para §2.** Un tablero Kanban no tiene sprints, y el enunciado pide
> "dividir el trabajo en sprints" y entrega un "plan de sprints". Si ya creaste un proyecto Kanban
> (ej. `H2`), creá uno **Scrum** al lado y usá ese; el Kanban queda como tablero de operación
> diaria si te resulta cómodo. Dos minutos y te ahorra discutir la sección 2.

> **Team-managed vs company-managed**: los proyectos nuevos de Jira Cloud suelen ser
> *team-managed* (el default). En ese tipo **no existen `Epic Link` ni `Sprint` como campos
> importables**: la jerarquía se arma con `Parent`. Para importar este CSV tal cual, elegí
> **company-managed** al crear el proyecto. Si vas a usar team-managed igual: importá primero las
> 15 épicas, después los 121 ítems, y asigná cada ítem a su épica desde el issue
> (*Parent* / "agregar a épica" en masa).
2. **Importar las épicas primero**:
   - `Configuración` → `Sistemas` → `Importación de sistemas externos` → **CSV**.
   - Delimitador: **coma**. Codificación: **UTF-8**.
   - Importar solo las 15 filas con *Issue Type* = `Epic` (filtrá el CSV antes, es más confiable
     que dejar que Jira resuelva el `Epic Link` en el mismo archivo).
3. **Importar los 121 ítems** restantes con el mismo CSV.
4. **Mapeo de campos**:

| Columna CSV | Campo Jira |
|---|---|
| `Summary` | Summary |
| `Issue Type` | Issue Type |
| `Epic Link` | Epic Link |
| `Priority` | Priority |
| `Labels` | Labels |
| `Story Points` | Story Points |
| `Description` | Description |
| `Sprint` | *ver nota abajo* |

5. **Sprints**: Jira Cloud no siempre crea sprints desde CSV. Si la columna `Sprint` no se mapea:
   - importá igual (los ítems quedan en el backlog), y
   - creá los 5 sprints en el board y usá **Cambio masivo** filtrando por etiqueta de sprint
     (`sprint-1` … `sprint-5`) — 5 operaciones, 5 minutos.

   Para eso conviene agregar la etiqueta antes de importar:
   ```powershell
   # opcional: agrega la etiqueta sprint-N a cada fila según su columna Sprint
   ```
6. **Verificar**: el board debe mostrar 15 épicas y 121 ítems con owner asignado.

## Reglas de trabajo que el backlog asume

- **Un ítem = un PR** siempre que sea posible. El nombre de la rama lleva la clave:
  `feature/PI26-42-listado-por-tag`.
- **Criterio de aceptación en la descripción**, no en un comentario: si no está en la descripción,
  no existe para el evaluador.
- Los ítems con `Story Points` vacío son épicas: no se estiman, se descomponen.
- Cada ítem cerrado deja evidencia en `evidence/<seccion>/` (ver `docs/03-checklist-entregables.md`).

## Mantenimiento

- Al terminar cada sprint: mover lo no hecho al siguiente **con motivo escrito** (no arrastrar en silencio).
- Los 6 ítems `opcional` del Backlog: si algún día sobra tiempo, entran; si no, quedan como
  "mejoras futuras" en §15.16 — que es exactamente donde el enunciado espera verlas.
- Si aparece un bug durante las pruebas: **no se agrega al backlog**, se registra en Mantis (§11) y se
  vincula con el ítem que lo originó. Backlog y bug tracker son cosas distintas (ver D-06).
