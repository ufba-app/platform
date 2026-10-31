import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, posix, relative, sep } from 'node:path';

/**
 * Regra de dependência entre camadas (ver docs/ARQUITETURA.md):
 *   interface, infrastructure → application → domain
 * O compilador não impõe isso dentro de um único pacote; este teste lê os imports e falha se a regra for quebrada.
 */

type Layer = 'domain' | 'application' | 'interface' | 'infrastructure';

const LAYERS: readonly Layer[] = [
  'domain',
  'application',
  'interface',
  'infrastructure',
];

const ALLOWED: Record<Layer, readonly Layer[]> = {
  domain: ['domain'],
  application: ['domain', 'application'],
  interface: ['domain', 'application', 'interface'],
  infrastructure: ['domain', 'application', 'infrastructure'],
};

/** O domínio não conhece framework, banco, fila nem HTTP. */
const FORBIDDEN_IN_DOMAIN = [
  '@nestjs',
  '@prisma',
  'express',
  'ioredis',
  'bullmq',
];

interface SourceFile {
  /** Caminho relativo a `src`, com `/`. Ex.: `domain/sync/detect-changes.ts`. */
  path: string;
  /** Especificadores de import encontrados no arquivo. */
  imports: string[];
}

function layerOf(path: string): Layer | undefined {
  const first = path.split('/')[0];
  return LAYERS.find((layer) => layer === first);
}

function isForbiddenPackage(specifier: string): boolean {
  return FORBIDDEN_IN_DOMAIN.some(
    (pkg) => specifier === pkg || specifier.startsWith(`${pkg}/`),
  );
}

export function findViolations(files: readonly SourceFile[]): string[] {
  const violations: string[] = [];

  for (const file of files) {
    const from = layerOf(file.path);
    // Arquivos na raiz de src (main.ts, app.module.ts) são a raiz de composição: ligam as camadas.
    if (!from) continue;

    for (const specifier of file.imports) {
      if (from === 'domain' && isForbiddenPackage(specifier)) {
        violations.push(
          `${file.path}: o domain não pode importar '${specifier}'`,
        );
        continue;
      }

      if (!specifier.startsWith('.')) continue;

      const target = posix.normalize(
        posix.join(posix.dirname(file.path), specifier),
      );
      const to = layerOf(target);
      if (!to) continue;

      if (!ALLOWED[from].includes(to)) {
        violations.push(`${file.path}: ${from} não pode importar ${to} ('${specifier}')`);
        continue;
      }

      // O kernel é a base de todo o domínio: não depende de mais nada dele.
      const inKernel = file.path.startsWith('domain/kernel/');
      if (inKernel && to === 'domain' && !target.startsWith('domain/kernel/')) {
        violations.push(
          `${file.path}: o domain/kernel não pode importar o resto do domain ('${specifier}')`,
        );
      }
    }
  }

  return violations;
}

const IMPORT_PATTERNS = [
  /(?:^|\n)\s*(?:import|export)\s[^;'"]*?from\s*['"]([^'"]+)['"]/g,
  /(?:^|\n)\s*import\s*['"]([^'"]+)['"]/g,
  /import\(\s*['"]([^'"]+)['"]\s*\)/g,
];

function extractImports(source: string): string[] {
  const found = new Set<string>();
  for (const pattern of IMPORT_PATTERNS) {
    for (const match of source.matchAll(pattern)) {
      found.add(match[1]);
    }
  }
  return [...found];
}

function collectFiles(srcDir: string): SourceFile[] {
  const files: SourceFile[] = [];

  const walk = (dir: string): void => {
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      if (statSync(full).isDirectory()) {
        walk(full);
      } else if (name.endsWith('.ts')) {
        files.push({
          path: relative(srcDir, full).split(sep).join('/'),
          imports: extractImports(readFileSync(full, 'utf8')),
        });
      }
    }
  };

  walk(srcDir);
  return files;
}

describe('arquitetura em camadas', () => {
  it('o código em src respeita a regra de dependência', () => {
    const files = collectFiles(join(__dirname, '..', 'src'));

    expect(files.length).toBeGreaterThan(0);
    expect(findViolations(files)).toEqual([]);
  });

  describe('findViolations', () => {
    it('barra o domain importando application, interface ou infrastructure', () => {
      const violations = findViolations([
        { path: 'domain/sync/a.ts', imports: ['../../application/x'] },
        { path: 'domain/sync/b.ts', imports: ['../../interface/x'] },
        { path: 'domain/sync/c.ts', imports: ['../../infrastructure/x'] },
      ]);

      expect(violations).toHaveLength(3);
    });

    it('barra a application importando interface', () => {
      expect(
        findViolations([
          { path: 'application/sync/a.ts', imports: ['../../interface/rest/x'] },
        ]),
      ).toHaveLength(1);
    });

    it('barra o domain importando framework e banco', () => {
      const violations = findViolations([
        {
          path: 'domain/sync/a.ts',
          imports: ['@nestjs/common', '@prisma/client', 'bullmq'],
        },
      ]);

      expect(violations).toHaveLength(3);
    });

    it('barra o kernel importando o resto do domain', () => {
      expect(
        findViolations([
          { path: 'domain/kernel/a.ts', imports: ['../sync/detect-changes'] },
        ]),
      ).toHaveLength(1);
    });

    it('permite as dependências para dentro', () => {
      expect(
        findViolations([
          { path: 'domain/sync/a.ts', imports: ['../kernel/content-hash', 'node:crypto'] },
          { path: 'application/sync/a.ts', imports: ['../../domain/sync/a', '@nestjs/common'] },
          { path: 'interface/rest/a.ts', imports: ['../../application/sync/a'] },
          { path: 'infrastructure/persistence/a.ts', imports: ['../../domain/sync/a'] },
        ]),
      ).toEqual([]);
    });

    it('ignora a raiz de composição', () => {
      expect(
        findViolations([
          { path: 'app.module.ts', imports: ['./interface/rest/health.controller'] },
        ]),
      ).toEqual([]);
    });
  });
});
