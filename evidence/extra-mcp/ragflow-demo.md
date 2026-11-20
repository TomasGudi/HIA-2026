# Agente Hermes sobre RAGFlow (segundo servidor MCP)

Fecha: 2026-11-20T13:28:24.2426136-03:00

Las respuestas salen de la documentación indexada en RAGFlow (`docs/`), no de
la base de la aplicación. El agente tiene dos servidores MCP conectados:
`practica` (datos vivos) y `ragflow` (documentación).

## Segun la documentacion del proyecto, que RTO se midio en el failover de la replica y que divergencia aparecio? Cita el documento.

```
☤ Hermes
Según docs/08-replicacion.md (§4 "Pruebas de fallo" y §6 "Divergencia detectada"), replicado en el informe consolidado:

RTO medido
- Escenario C) failover manual con pg_promote(): promoción en 1,2 s, nodo fuera de recovery.
- C3) RTO total: 8,6 s desde el inicio de la promoción hasta que la app vuelve a responder 200. El repunte es manual: DATABASE_HOST=db-replica + recrear el backend.
- La misma cifra aparece en docs/02-arquitectura.md §5 ("RTO 8,6 s"), en 20-guion-demo.md (frase de demo: "El failover es manual y está medido: 8,6 s") y en docs/16-limitaciones.md §2 fila A1, que la redondea a "~9 s medidos, más el tiempo de detección".Divergencia aparecida
- Cita textual de 08-replicacion.md §6: "Al promover la réplica y seguir escribiendo, el nodo promovido quedó con un usuario que la primaria vieja no tiene (failover_demo). Al restaurar la topología original hubo que descartar el volumen de la réplica promovida y volver a clonar, perdiendo esa escritura."- Se documenta como consecuencia esperable de un failover manual sin cuórum (riesgo de split-brain si la primaria solo estaba aislada), y la consecuencia declarada es RPO ≠ 0. En la prueba el lag era 0 bytes, así que la pérdida fue la escritura hecha después de la promoción, no WAL previo sin replicar.
- Contexto del escenario C4: POST /api/users → 201 sobre el nodo promovido, 200.002 usuarios.

Referencias: docs/08-replicacion.md §4 y §6; docs/16-limitaciones.md §2 (A1); docs/02-arquitectura.md §5; docs/20-guion-demo.md (bloque R1); informe-consolidado.md (mismos pasajes, sin cifras distintas).

Nota: los documentos no registran un RTO medido para el escenario B (caída de la primaria sin failover): ahí solo hay primera respuesta no-200 a los 1,4 s y 20/20 fallos HTTP 500 en 10 s.
```

- Herramientas usadas: ragflow retrieval
- Llamadas a herramientas: 6

## Que limitaciones declaramos sobre Mantis y por que corre como root? Cita el documento.

```
☤ Hermes
Según la documentación de la práctica (dataset practica-documentacion), hay tres documentos que lo declaran, y coinciden.Fuente principal: 16-limitaciones.md, §7 "Limitaciones declaradas" (tabla Limitación / Motivo / Riesgo aceptado):

  "Mantis corre como root | Apache necesita el puerto 80 y escribir en el web root | mitigado con borde autenticado y /admin bloqueado"

La misma limitación aparece en el §4 "Limitaciones de seguridad" de ese documento, como S1, con dos columnas más:

  "S1 | Mantis corre como root | Apache necesita el puerto 80 y escribir en el web root | mitigado con borde autenticado y /admin bloqueado (403) | Para cerrarla: imagen con su-exec y puerto alto"

Y en 14-seguridad.md, §3.3 Semgrep, que explica por qué se acepta el hallazgo en vez de corregirlo:

  "Semgrep --config=auto sobre app/: 6 hallazgos, todos dockerfile.security.missing-user en app/mantis/Dockerfile (Apache corre como root). Es el mismo hallazgo que declara la matriz: no se corrige porque Apache necesita el puerto 80 y escribir en el web root; se mitiga con el borde autenticado y /admin bloqueado."

Resumen de las dos preguntas:

- Por qué corre como root: decisión de diseño del contenedor, no un descuido. Apache necesita bindear el puerto 80 (privilegiado) y escribir en el web root; en lugar de montar una imagen con su-exec y puerto alto, se aceptó el privilegio.
- Qué limitaciones se declaran: (a) el proceso corre como root — hallazgo de Semgrep dockerfile.security.missing-user, 6 ocurrencias en app/mantis/Dockerfile; (b) riesgo aceptado = mitigado por borde autenticado + /admin bloqueado con 403; (c) cierre pendiente = imagen con su-exec y puerto alto.

Contexto adicional de la misma lista: 03-checklist-entregables.md lo resume en una línea — "Limitaciones declaradas: Mantis corre como root, Prometheus/Grafana sin auth propia, tar y zlib con CVE crítica sin fix compatible" — y el informe-consolidado.md reproduce las mismas tablas.

Aclaración: esto es lo que declara el documento. Las herramientas de la plataforma (estado_plataforma, estadisticas_bd) no exponen el usuario de proceso de los contenedores, así que no puedo verificar en vivo que hoy siga corriendo como root; solo cito lo documentado.
```

- Herramientas usadas: ragflow list datasets, ragflow retrieval
- Llamadas a herramientas: 13
