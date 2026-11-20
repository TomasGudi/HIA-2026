# RAGFlow como motor documental (extra)

Segundo servidor MCP del proyecto: además de `practica` (datos vivos de la
aplicación), el agente Hermes consulta `ragflow` (documentación indexada).

## Por qué

La API de la aplicación responde "cuántos artículos hay". No responde "qué RTO
medimos en el failover". Ese conocimiento está en `docs/`, y para que un agente
lo use hace falta un motor de recuperación. RAGFlow aporta chunking, embeddings
y un servidor MCP propio, sin escribir código de búsqueda.

## Costo (declarado)

| Recurso | Valor |
|---|---|
| Contenedores | 6 (`ragflow`, `infinity`, `mysql`, `minio`, `kvrocks`, `nats`) + TEI |
| RAM medida | ~4,5 GB en reposo (TEI 2,6 GB incluido) |
| Disco | ~20 GB de imágenes + 26 documentos |
| Puertos | 8095 (UI), 9380 (API/MCP), 9381 (admin) — todos en loopback |

Es **infraestructura duplicada** respecto del stack principal (MySQL, object
storage, colas). Se acepta porque el objetivo es mostrar una alternativa, no
reemplazar la arquitectura de la práctica.

## Puesta en marcha

```powershell
# 1) código (fuera del repo: son ~6 GB de imágenes)
git clone --depth 1 --branch v1.0.0 https://github.com/infiniflow/ragflow.git C:\Users\<user>\ragflow
cd C:\Users\<user>\ragflow\docker

# 2) configuración local: copiar docker-compose.override.yml de este directorio
#    y ajustar .env (DOC_ENGINE=infinity, puertos 8095/8453/9380/9381,
#    contraseñas propias, ADMIN_DEFAULT_PASSWORD)

# 3) levantar
docker compose up -d
docker compose --profile tei-cpu up -d tei-cpu

# 4) ingestar la documentación y crear usuario + API key
RAGFLOW_ENV=C:/Users/<user>/ragflow/docker/.env node scripts/ragflow-ingestar.mjs
```

El script imprime la API key y el dataset id. Es idempotente: se puede correr
de nuevo y solo procesa lo que falta.

## Decisiones que no son obvias

| Decisión | Motivo |
|---|---|
| `infinity` en vez de Elasticsearch | evita `vm.max_map_count=262144` en WSL2 |
| TEI con MiniLM multilingüe | el compose hornea `bge-m3` (16 GB RAM en CPU) y `bge-small-en` (solo inglés) |
| Instancia `default` del proveedor | el dataset resuelve `modelo@proveedor` contra la instancia `default`; con otro nombre falla |
| Login por RSA en el script | RAGFlow no acepta contraseña en claro: el frontend cifra con la clave pública |
| `parse_type: 1` al crear el dataset | sin ese campo la API responde `parse_type is required` |

## Integración con Hermes

`automation/hermes/config.yaml` declara el segundo servidor:

```yaml
  ragflow:
    url: "http://pi-ragflow:9380/api/v1/mcp"
    headers:
      Authorization: "Bearer ${RAGFLOW_API_KEY}"
    tools:
      include: [ragflow_retrieval, ragflow_list_datasets]
```

El contenedor de Hermes se conecta además a la red `docker_ragflow`; por eso
resuelve `pi-ragflow` por nombre.

## Evidencia

`evidence/extra-mcp/ragflow-demo.md`: dos preguntas que solo se contestan con la
documentación, con las citas que devolvió el agente.
