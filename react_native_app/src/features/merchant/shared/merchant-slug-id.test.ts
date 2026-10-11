import { generateMerchantSlugId } from './merchant-slug-id';

describe('generateMerchantSlugId', () => {
  it('slugifies the seed and appends a base-36 suffix', () => {
    expect(generateMerchantSlugId('  Bakaal Fresh!! ', () => 0.5)).toBe(`bakaal-fresh-${Math.floor(0.5 * 0xffffff).toString(36)}`);
  });

  it("falls back to 'item' when the seed has no slug characters", () => {
    expect(generateMerchantSlugId('***', () => 0)).toBe('item-0');
  });
});
