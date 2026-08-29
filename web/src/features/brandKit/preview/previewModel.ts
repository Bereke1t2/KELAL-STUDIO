import { normalizeHex, readableInkOn } from '../../../lib/hex';

/** Design-system gold, used when a colour field is empty or mid-type. */
const FALLBACK_PRIMARY = '#855312'; // --color-interactive-primary-default (light)
const FALLBACK_SECONDARY = '#c6821f'; // --color-border-brand

export interface PreviewInput {
  brandName: string;
  primaryColorHex: string;
  secondaryColorHex: string;
  tone: string;
}

export interface PreviewModel {
  brandName: string;
  /** True when `brandName` was blank and a placeholder is being shown. */
  isPlaceholderName: boolean;
  /** Always a valid `#rrggbb`. */
  primary: string;
  secondary: string;
  /** Legible ink for text placed on `primary`. */
  onPrimary: string;
  tone: string;
}

/**
 * Turn the in-progress form values (which may be blank or half-typed) into
 * props the preview card can render without ever looking broken.
 */
export function toPreviewModel(
  input: PreviewInput,
  placeholderName: string,
): PreviewModel {
  const name = input.brandName.trim();
  const primary = normalizeHex(input.primaryColorHex) ?? FALLBACK_PRIMARY;
  const secondary = normalizeHex(input.secondaryColorHex) ?? FALLBACK_SECONDARY;

  return {
    brandName: name || placeholderName,
    isPlaceholderName: name.length === 0,
    primary,
    secondary,
    onPrimary: readableInkOn(primary),
    tone: input.tone.trim(),
  };
}
