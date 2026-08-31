/**
 * Small colour helpers for the Brand Kit preview. The Brand Kit stores hex
 * strings as free text; the user can be mid-type, so every function tolerates
 * junk and returns `null` rather than throwing.
 */

/** `#abc`, `abc`, `#AABBCC`, `aabbcc` → `#aabbcc`. Anything else → null. */
export function normalizeHex(input: string): string | null {
  const v = input.trim().replace(/^#/, '').toLowerCase();
  if (/^[0-9a-f]{3}$/.test(v)) {
    return `#${v[0]}${v[0]}${v[1]}${v[1]}${v[2]}${v[2]}`;
  }
  if (/^[0-9a-f]{6}$/.test(v)) return `#${v}`;
  return null;
}

export function isHex(input: string): boolean {
  return normalizeHex(input) !== null;
}

function channels(hex: string): [number, number, number] | null {
  const n = normalizeHex(hex);
  if (!n) return null;
  return [
    parseInt(n.slice(1, 3), 16),
    parseInt(n.slice(3, 5), 16),
    parseInt(n.slice(5, 7), 16),
  ];
}

/** WCAG relative luminance (0 = black, 1 = white). Returns null on bad input. */
export function relativeLuminance(hex: string): number | null {
  const rgb = channels(hex);
  if (!rgb) return null;
  const [r, g, b] = rgb.map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  }) as [number, number, number];
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG contrast ratio between two hex colours (1–21). Null on bad input. */
export function contrastRatio(a: string, b: string): number | null {
  const la = relativeLuminance(a);
  const lb = relativeLuminance(b);
  if (la === null || lb === null) return null;
  const [hi, lo] = la > lb ? [la, lb] : [lb, la];
  return (hi + 0.05) / (lo + 0.05);
}

/**
 * Pick a legible foreground for text sitting on `bgHex`. Returns the design
 * system's near-black or near-white ink, whichever has more contrast; falls
 * back to near-white when the background can't be parsed.
 */
export function readableInkOn(bgHex: string): '#fafafa' | '#171717' {
  const onDark = contrastRatio(bgHex, '#fafafa') ?? 0;
  const onLight = contrastRatio(bgHex, '#171717') ?? 0;
  return onLight > onDark ? '#171717' : '#fafafa';
}
