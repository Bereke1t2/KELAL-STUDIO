import type { ElementType, ReactNode } from 'react';

/**
 * The flat container. Depth in this system is a surface tint and a 1px
 * hairline — never a shadow (mobile has no elevation tokens by design).
 */
type Pad = 'none' | 'sm' | 'md' | 'lg';

const PAD: Record<Pad, string> = {
  none: '',
  sm: 'p-4',
  md: 'p-6',
  lg: 'p-8',
};

export function Card({
  as,
  pad = 'md',
  className = '',
  children,
}: {
  as?: ElementType;
  pad?: Pad;
  className?: string;
  children: ReactNode;
}) {
  const Tag = as ?? 'div';
  return (
    <Tag
      className={`rounded-lg border border-line bg-surface ${PAD[pad]} ${className}`}
    >
      {children}
    </Tag>
  );
}
