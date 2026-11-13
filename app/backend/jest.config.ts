/* eslint-disable */
export default {
  displayName: 'api',
  preset: './jest.preset.js',
  testEnvironment: 'node',
  // registra el mock de Prisma antes de que los servicios importen el cliente
  setupFiles: ['<rootDir>/src/tests/jest.setup.ts'],
  transform: {
    '^.+\\.[tj]s$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.spec.json' }],
  },
  moduleFileExtensions: ['ts', 'js', 'html'],
  coverageDirectory: './coverage/api',
  testMatch: [
    '<rootDir>/src/**/__tests__/**/*.[jt]s?(x)',
    '<rootDir>/src/**/*(*.)@(spec|test).[jt]s?(x)',
  ],
};
