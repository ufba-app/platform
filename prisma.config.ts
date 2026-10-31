import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  // Pasta: o Prisma lê `schema.prisma` e todos os `.prisma` em `models/`.
  schema: 'prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
});
