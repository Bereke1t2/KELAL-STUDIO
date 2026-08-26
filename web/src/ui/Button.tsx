import type { ButtonHTMLAttributes, ReactNode } from 'react';

/**
 * Primary/secondary/tertiary/destructive button.
 *
 * Metrics pulled from Figma `Components / Button`, node 14:2: px 24 / py 12,
 * radius-md, 8px gap, 15px/23px label with 0.3px tracking. Fill, label, and
 * border are bound to color/interactive/primary/* — never hardcode them.
 */
export type ButtonVariant = 'primary' | 'secondary' | 'tertiary' | 'destructive';

const VARIANTS: Record<ButtonVariant, string> = {
  primary:
    'bg-primary text-on-brand hover:bg-primary-hover active:bg-primary-pressed ' +
    'disabled:bg-primary-disabled disabled:text-ink-tertiary',
  secondary:
    'border border-line-brand text-tertiary-text hover:bg-brand-subtle ' +
    'active:bg-brand-subtle disabled:border-line disabled:text-ink-tertiary',
  tertiary:
    'text-tertiary-text hover:bg-brand-subtle active:bg-brand-subtle ' +
    'disabled:text-ink-tertiary',
  destructive:
    'bg-destructive text-on-brand hover:opacity-90 active:opacity-80 ' +
    'disabled:bg-primary-disabled disabled:text-ink-tertiary',
};

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  children: ReactNode;
}

export function Button({
  variant = 'primary',
  className = '',
  children,
  ...rest
}: ButtonProps) {
  return (
    <button
      // min-h-12 is the design system's accessibility floor (48px tap target,
      // PRD §7.4) — it applies on a pointer surface too, not just touch.
      className={[
        'inline-flex min-h-12 items-center justify-center gap-2 rounded-md',
        'px-6 py-3 text-[15px] leading-[23px] tracking-[0.3px]',
        'transition-colors disabled:cursor-not-allowed',
        VARIANTS[variant],
        className,
      ].join(' ')}
      {...rest}
    >
      {children}
    </button>
  );
}
