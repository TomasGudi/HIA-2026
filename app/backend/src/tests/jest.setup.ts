// Setup global de Jest: el mock de Prisma tiene que registrarse ANTES de que
// cualquier servicio importe el cliente real.
//
// Antes estaba dentro de `prisma-mock.ts`, que cada test importa *después* del
// servicio: los imports se evalúan en orden, así que `new PrismaClient()` corría
// primero y los tests de AuthService fallaban intentando conectarse a la base.
import { mockDeep } from 'jest-mock-extended';
import { PrismaClient } from '@prisma/client';

jest.mock('../prisma/prisma-client', () => ({
  __esModule: true,
  default: mockDeep<PrismaClient>(),
}));
