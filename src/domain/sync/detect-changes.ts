/** O que se sabe de um item para decidir se mudou: quem ele é na fonte e o hash do conteúdo. */
export interface KnownItem {
  externalId: string;
  contentHash: string;
}

export interface ChangeSet {
  created: KnownItem[];
  updated: KnownItem[];
  removed: KnownItem[];
  unchanged: KnownItem[];
}

/**
 * Compara o que já está no banco (`existing`) com o que a fonte acabou de devolver (`incoming`).
 * Função pura: não lê banco, rede nem relógio. Ver `docs/ARQUITETURA.md`.
 */
export function detectChanges(
  existing: readonly KnownItem[],
  incoming: readonly KnownItem[],
): ChangeSet {
  const known = new Map(existing.map((item) => [item.externalId, item]));
  const seen = new Set<string>();
  const changes: ChangeSet = {
    created: [],
    updated: [],
    removed: [],
    unchanged: [],
  };

  for (const item of incoming) {
    seen.add(item.externalId);
    const previous = known.get(item.externalId);
    if (!previous) {
      changes.created.push(item);
    } else if (previous.contentHash !== item.contentHash) {
      changes.updated.push(item);
    } else {
      changes.unchanged.push(item);
    }
  }

  for (const item of existing) {
    if (!seen.has(item.externalId)) {
      changes.removed.push(item);
    }
  }

  return changes;
}
