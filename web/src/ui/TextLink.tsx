import { Link, type LinkProps } from 'react-router';

/** Inline navigational link, styled to the brand's tertiary-text token. */
export function TextLink({ className = '', ...rest }: LinkProps) {
  return (
    <Link
      className={`text-body-sm text-tertiary-text underline-offset-2 hover:underline ${className}`}
      {...rest}
    />
  );
}
