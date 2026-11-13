/**
 * Acceso a variables de entorno obligatorias.
 *
 * Motivo: el código original usaba `process.env.JWT_SECRET || 'superSecret'`.
 * Si la variable faltaba, la API arrancaba igual y firmaba los tokens con una
 * clave pública conocida — cualquiera podía forjar un JWT válido.
 * Ahora el arranque falla explícitamente (fail-fast) en vez de degradarse.
 *
 * Hallazgo registrado en la gestión de incidencias (§11) e informe de §14.
 */
export const getJwtSecret = (): string => {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new Error('JWT_SECRET no está definido: la API no puede firmar tokens de forma segura');
  }
  if (secret.length < 16) {
    throw new Error('JWT_SECRET es demasiado corto (mínimo 16 caracteres)');
  }
  return secret;
};
