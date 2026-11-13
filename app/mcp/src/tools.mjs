// Definición de las herramientas MCP.
//
// Reglas de diseño (pensadas para que un modelo chico acierte):
//  - pocas herramientas y con nombres que digan qué hacen;
//  - la descripción explica CUÁNDO usarla y qué devuelve;
//  - toda respuesta es texto JSON con los campos ya recortados;
//  - los errores vuelven como isError con una explicación accionable.

import { z } from 'zod';
import { api } from './api.mjs';
import { db } from './db.mjs';
import { config } from './config.mjs';

const texto = (datos) => ({
  content: [{ type: 'text', text: JSON.stringify(datos, null, 2) }],
});

const error = (mensaje) => ({
  isError: true,
  content: [{ type: 'text', text: `Error: ${mensaje}` }],
});

// Los artículos traen el cuerpo completo (varios KB). Para listados se recorta:
// el agente necesita saber de qué se habla, no el texto entero.
const recortar = (a) => ({
  slug: a.slug,
  titulo: a.title,
  descripcion: a.description,
  autor: a.author?.username,
  tags: a.tagList,
  favoritos: a.favoritesCount,
  creado: a.createdAt,
});

export function registrarHerramientas(server) {
  // Se registran con un envoltorio para poder informar cuántas herramientas
  // expone el servidor sin depender de APIs internas del SDK.
  const nombres = [];
  const registrar = (nombre, cfg, fn) => {
    nombres.push(nombre);
    return server.registerTool(nombre, cfg, fn);
  };

  registrar(
    'estado_plataforma',
    {
      title: 'Estado de la plataforma',
      description:
        'Devuelve el estado de salud del backend, la base de datos, la versión desplegada y el uptime. ' +
        'Usala cuando pregunten si la aplicación está funcionando, caída, o qué versión corre.',
      inputSchema: {},
      annotations: { readOnlyHint: true, idempotentHint: true },
    },
    async () => {
      try {
        const s = await api.salud();
        return texto({
          estado: s.status,
          base_de_datos: s.db,
          version: s.version,
          uptime_segundos: Math.round(s.uptime ?? 0),
        });
      } catch (e) {
        return error(`no se pudo consultar /health: ${e.message}`);
      }
    },
  );

  registrar(
    'listar_articulos',
    {
      title: 'Listar artículos',
      description:
        'Lista los artículos publicados, del más reciente al más viejo. Acepta filtro por tag o por autor ' +
        'y paginación con limit/offset. Devuelve slug, título, descripción, autor, tags y favoritos. ' +
        'Usala para "qué artículos hay", "mostrame los de React", "cuántos escribió X". ' +
        'Ojo: el total que devuelve la API está topeado en 10.000 y los offsets altos tardan ' +
        '(la API cuenta sobre millones de filas); para acotar conviene filtrar por tag o autor. ' +
        'Para leer el contenido completo de uno, usá obtener_articulo con el slug.',
      inputSchema: {
        limit: z.number().int().min(1).max(20).optional().describe('cuántos artículos devolver (1-20, por defecto 5)'),
        offset: z.number().int().min(0).optional().describe('cuántos saltear, para paginar'),
        tag: z.string().optional().describe('filtra por tag exacto, por ejemplo "react" o "docker"'),
        autor: z.string().optional().describe('filtra por nombre de usuario del autor'),
      },
      annotations: { readOnlyHint: true },
    },
    async ({ limit = 5, offset = 0, tag, autor }) => {
      try {
        const r = await api.articulos({ limit, offset, tag, autor });
        return texto({
          total: r.articlesCount,
          mostrados: r.articles?.length ?? 0,
          articulos: (r.articles ?? []).map(recortar),
        });
      } catch (e) {
        return error(`no se pudo listar artículos: ${e.message}`);
      }
    },
  );

  registrar(
    'obtener_articulo',
    {
      title: 'Leer un artículo',
      description:
        'Devuelve el artículo completo (cuerpo incluido) a partir del slug. ' +
        'Usala cuando pidan el contenido o un resumen de un artículo concreto.',
      inputSchema: {
        slug: z.string().min(1).describe('identificador del artículo, por ejemplo "mi-primer-post"'),
      },
      annotations: { readOnlyHint: true, idempotentHint: true },
    },
    async ({ slug }) => {
      try {
        const r = await api.articulo(slug);
        const a = r.article;
        if (!a) return error(`no existe un artículo con slug "${slug}"`);
        return texto({
          slug: a.slug,
          titulo: a.title,
          descripcion: a.description,
          cuerpo: a.body,
          autor: a.author?.username,
          tags: a.tagList,
          favoritos: a.favoritesCount,
          creado: a.createdAt,
          actualizado: a.updatedAt,
        });
      } catch (e) {
        if (e.status === 404) return error(`no existe un artículo con slug "${slug}"`);
        return error(`no se pudo leer el artículo: ${e.message}`);
      }
    },
  );

  registrar(
    'listar_tags',
    {
      title: 'Listar tags',
      description:
        'Devuelve los tags de los artículos del usuario de demostración (es lo que expone la API). ' +
        'Usala para saber sobre qué temas se escribe o para elegir un tag válido antes de filtrar.',
      inputSchema: {},
      annotations: { readOnlyHint: true, idempotentHint: true },
    },
    async () => {
      try {
        const r = await api.tags();
        const tags = r.tags ?? [];
        return texto({ total: tags.length, tags });
      } catch (e) {
        return error(`no se pudieron listar los tags: ${e.message}`);
      }
    },
  );

  registrar(
    'estadisticas_bd',
    {
      title: 'Estadísticas de la base',
      description:
        'Métricas de PostgreSQL: tamaño de la base, filas estimadas por tabla, uso de índices, ' +
        'conexiones por estado, cache hit y consultas activas. Usala para preguntas de rendimiento, ' +
        'volumen de datos o saturación. No devuelve el contenido de las filas. ' +
        'Si `estadisticas_actualizadas` es false, las filas estimadas no son confiables: decilo.',
      inputSchema: {},
      annotations: { readOnlyHint: true },
    },
    async () => {
      try {
        return texto(await db.resumen());
      } catch (e) {
        return error(`no se pudieron leer las estadísticas: ${e.message}`);
      }
    },
  );

  // La escritura es opt-in: sin MCP_ALLOW_WRITE=true la herramienta ni aparece,
  // así el modelo no puede intentar algo que el servidor va a rechazar.
  if (config.allowWrite) {
    registrar(
      'crear_articulo',
      {
        title: 'Publicar un artículo',
        description:
          'Publica un artículo nuevo en la plataforma a nombre del usuario configurado. ' +
          'Requiere título, descripción corta y cuerpo. Los tags son opcionales. ' +
          'Usala solo si piden explícitamente publicar o crear un artículo.',
        inputSchema: {
          titulo: z.string().min(1).max(120).describe('título del artículo'),
          descripcion: z.string().min(1).max(200).describe('resumen corto, una o dos frases'),
          cuerpo: z.string().min(1).describe('cuerpo completo en texto'),
          tags: z.array(z.string()).max(5).optional().describe('hasta 5 tags'),
        },
        annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
      },
      async ({ titulo, descripcion, cuerpo, tags }) => {
        try {
          const a = await api.crearArticulo({ titulo, descripcion, cuerpo, tags });
          return texto({ creado: true, slug: a.slug, titulo: a.title, url: `/article/${a.slug}` });
        } catch (e) {
          return error(`no se pudo publicar: ${e.message}`);
        }
      },
    );
  }

  return nombres;
}
