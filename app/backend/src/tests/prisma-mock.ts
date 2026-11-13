import { mockDeep, mockReset, DeepMockProxy } from 'jest-mock-extended';

import prisma from '../prisma/prisma-client';
import { PrismaClient } from '@prisma/client';

// El `jest.mock` vive en `jest.setup.ts` (setupFiles de Jest): tiene que correr
// antes de que cualquier servicio importe el cliente real. Acá solo se tipa y
// se resetea entre tests.
const prismaMock = prisma as unknown as DeepMockProxy<PrismaClient>;

beforeEach(() => {
  mockReset(prismaMock);
});

export default prismaMock;
