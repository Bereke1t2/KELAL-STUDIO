import { normalizeHex, readableInkOn } from '../lib/hex';

/**
 * Square monogram tile — radius-md, never a circle (mirrors the mobile
 * Avatar / Logo Tile, Figma node 48:2). Used where a brand has no displayable
 * logo (which, on web, is always: there is no GET /assets route).
 */
function initials(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return '—';
  if (words.length === 1) return words[0]!.slice(0, 2).toUpperCase();
  return (words[0]![0]! + words[1]![0]!).toUpperCase();
}

export function BrandAvatar({
  name,
  colorHex,
  sizeClass = 'size-12',
  className = '',
}: {
  name: string;
  colorHex?: string;
  sizeClass?: string;
  className?: string;
}) {
  const bg = (colorHex && normalizeHex(colorHex)) || null;
  const style = bg
    ? { backgroundColor: bg, color: readableInkOn(bg) }
    : undefined;

  return (
    <span
      aria-hidden
      style={style}
      className={[
        sizeClass,
        'inline-flex items-center justify-center rounded-md text-body-sm',
        bg ? '' : 'border border-line bg-brand-subtle text-tertiary-text',
        className,
      ].join(' ')}
    >
      {initials(name)}
    </span>
  );
}
