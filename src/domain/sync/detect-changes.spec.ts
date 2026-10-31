import { detectChanges, KnownItem } from './detect-changes';

const item = (externalId: string, contentHash: string): KnownItem => ({
  externalId,
  contentHash,
});

describe('detectChanges', () => {
  it('classifica itens novos, alterados, removidos e inalterados', () => {
    const existing = [item('a', 'h1'), item('b', 'h2'), item('c', 'h3')];
    const incoming = [item('a', 'h1'), item('b', 'h2-novo'), item('d', 'h4')];

    const result = detectChanges(existing, incoming);

    expect(result.unchanged).toEqual([item('a', 'h1')]);
    expect(result.updated).toEqual([item('b', 'h2-novo')]);
    expect(result.created).toEqual([item('d', 'h4')]);
    expect(result.removed).toEqual([item('c', 'h3')]);
  });

  it('tudo é novo quando o banco está vazio', () => {
    const result = detectChanges([], [item('a', 'h1')]);

    expect(result.created).toEqual([item('a', 'h1')]);
    expect(result.removed).toEqual([]);
  });

  it('tudo é removido quando a fonte devolve vazio', () => {
    const result = detectChanges([item('a', 'h1')], []);

    expect(result.removed).toEqual([item('a', 'h1')]);
    expect(result.created).toEqual([]);
  });
});
