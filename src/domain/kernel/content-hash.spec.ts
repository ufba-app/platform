import { contentHash } from './content-hash';

describe('contentHash', () => {
  it('não depende da ordem das chaves', () => {
    expect(contentHash({ a: 1, b: { c: 2, d: 3 } })).toBe(
      contentHash({ b: { d: 3, c: 2 }, a: 1 }),
    );
  });

  it('muda quando o conteúdo muda', () => {
    expect(contentHash({ titulo: 'Prova 1' })).not.toBe(
      contentHash({ titulo: 'Prova 2' }),
    );
  });

  it('respeita a ordem dos elementos de uma lista', () => {
    expect(contentHash([1, 2])).not.toBe(contentHash([2, 1]));
  });

  it('ignora chaves indefinidas', () => {
    expect(contentHash({ a: 1, b: undefined })).toBe(contentHash({ a: 1 }));
  });
});
