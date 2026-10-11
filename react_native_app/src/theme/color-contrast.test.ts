/**
 * WCAG 2.x contrast check for the main text/background token pairs (issue
 * #416). AA requires 4.5:1 for normal-size text and 3:1 for large text
 * (>= 24px regular / ~18.7px bold) and non-text UI components.
 *
 * `MAIN_TEXT_PAIRS` must meet AA for normal text. `KNOWN_GAPS` lists the
 * token pairs that are used for text today but only reach the 3:1 large-text
 * / UI floor. They are pinned here so they stay visible (and can't silently
 * get worse) until design decides on a fix — see the issue #416 PR for why
 * each one wasn't changed in this pass. Fixing one should move it from
 * `KNOWN_GAPS` into `MAIN_TEXT_PAIRS`.
 */
import { ServiceThemes } from '@/theme/service-theme';
import { colors } from '@/theme/tokens';

function channel(value: number): number {
  const c = value / 255;
  return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function rgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '');
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)) as [number, number, number];
}

function luminance(hex: string): number {
  const [r, g, b] = rgb(hex).map(channel);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrastRatio(foreground: string, background: string): number {
  const a = luminance(foreground);
  const b = luminance(background);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

/** Composites `hex` at `alpha` over an opaque `base`, for tinted pill backgrounds. */
function blend(hex: string, alpha: number, base: string): string {
  const top = rgb(hex);
  const bottom = rgb(base);
  return `#${top
    .map((value, i) => Math.round(value * alpha + bottom[i] * (1 - alpha)))
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('')}`;
}

const AA_NORMAL = 4.5;
const AA_LARGE_OR_UI = 3;

type Pair = [label: string, foreground: string, background: string];

const surfaces = ['bg', 'card', 'cardMuted'] as const;

const MAIN_TEXT_PAIRS: Pair[] = [
  ...(['light', 'dark'] as const).flatMap((scheme) =>
    (['text', 'textMuted'] as const).flatMap((fg) =>
      surfaces.map((bg): Pair => [`${scheme} ${fg} on ${bg}`, colors[scheme][fg], colors[scheme][bg]]),
    ),
  ),
  ...surfaces.map((bg): Pair => [`light primary on ${bg}`, colors.light.primary, colors.light[bg]]),
  ...surfaces.map((bg): Pair => [`light error on ${bg}`, colors.light.error, colors.light[bg]]),
  ...surfaces.map((bg): Pair => [`dark error on ${bg}`, colors.dark.error, colors.dark[bg]]),
  ['light text on searchFill', colors.light.text, colors.light.searchFill],
  ['light textMuted on searchFill', colors.light.textMuted, colors.light.searchFill],
  ['light onPrimary on primary', colors.light.onPrimary, colors.light.primary],
  ['light primary on primarySoft', colors.light.primary, colors.light.primarySoft],
  // grocery-product-card.tsx's in-stock pill: #0F7A54 on tertiary @ 0x24 over the white card.
  ['light in-stock pill', '#0F7A54', blend(colors.light.tertiary, 0x24 / 255, colors.light.card)],
  ...Object.entries(ServiceThemes).flatMap(([name, palette]): Pair[] => [
    [`${name} onAccent on accent`, palette.onAccent, palette.accent],
    [`${name} accent on background`, palette.accent, palette.background],
    [`${name} accent on card`, palette.accent, palette.card],
    // Food's accent-on-soft is a known gap (below); every other palette passes.
    ...(name === 'food' ? [] : [[`${name} accent on soft`, palette.accent, palette.soft] as Pair]),
  ]),
];

const KNOWN_GAPS: Pair[] = [
  // Dark palette is this port's own (not from Flutter) and flagged for
  // design review in tokens.ts. White button labels on blue500, and blue500
  // links on the dark card, sit between 3:1 and 4.5:1.
  ['dark onPrimary on primary', colors.dark.onPrimary, colors.dark.primary],
  ['dark primary on card', colors.dark.primary, colors.dark.card],
  ['dark primary on cardMuted', colors.dark.primary, colors.dark.cardMuted],
  // Out-of-stock pill / destructive chip: error (red600) text on errorSoft
  // (red100). Ported 1:1 from Flutter's TwColors.
  ['light error on errorSoft', colors.light.error, colors.light.errorSoft],
  // Unselected food category chips (category-chip-bar.tsx) and other
  // accent-on-soft tints: orange-700 on the food soft peach is ~4.4:1.
  // Fixing it means changing the food brand accent or soft tint, a design call.
  ['food accent on soft', ServiceThemes.food.accent, ServiceThemes.food.soft],
];

describe('theme token color contrast (WCAG AA)', () => {
  it('computes known reference ratios', () => {
    expect(contrastRatio('#000000', '#FFFFFF')).toBeCloseTo(21, 5);
    expect(contrastRatio('#FFFFFF', '#FFFFFF')).toBeCloseTo(1, 5);
    // Symmetric in its arguments.
    expect(contrastRatio('#0066CC', '#FFFFFF')).toBeCloseTo(contrastRatio('#FFFFFF', '#0066CC'), 10);
  });

  it.each(MAIN_TEXT_PAIRS)('%s meets 4.5:1', (_label, foreground, background) => {
    expect(contrastRatio(foreground, background)).toBeGreaterThanOrEqual(AA_NORMAL);
  });

  it.each(KNOWN_GAPS)('%s (known gap) still meets the 3:1 large-text/UI floor', (_label, foreground, background) => {
    const ratio = contrastRatio(foreground, background);
    expect(ratio).toBeGreaterThanOrEqual(AA_LARGE_OR_UI);
    expect(ratio).toBeLessThan(AA_NORMAL);
  });
});
