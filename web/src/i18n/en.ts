/**
 * English message catalog — the single source of truth for message keys.
 *
 * Every key is declared here first; `am.ts` is typed against this object so a
 * missing or renamed key fails `tsc`, and a CI test asserts the two never
 * drift. Keys are flat and dot-namespaced, mirroring the ARB key style in
 * `mobile/lib/core/l10n/arb/`.
 *
 * Interpolation: `{name}` placeholders, filled by `format.ts#interpolate`.
 */
export const en = {
  // Identity
  'app.name': 'Kelal Studio',
  'app.tagline': 'Grow your business online',
  'app.portal': 'Management portal',

  // Global chrome
  'nav.sections': 'Sections',
  'nav.brandKit': 'Brand Kit',
  'nav.usage': 'Usage',
  'nav.flags': 'Flagged prompts',
  'nav.users': 'User limits',
  'nav.group.brand': 'Brand',
  'nav.group.oversight': 'Oversight',
  'action.signOut': 'Sign out',
  'action.save': 'Save',
  'action.saving': 'Saving…',
  'action.cancel': 'Cancel',
  'action.retry': 'Try again',
  'state.loading': 'Loading…',

  // Theme control
  'theme.label': 'Theme',
  'theme.light': 'Light',
  'theme.dark': 'Dark',
  'theme.system': 'System',

  // Language control
  'lang.label': 'Language',
  'lang.en': 'English',
  'lang.am': 'አማርኛ',

  // Sign in
  'login.title': 'Sign in',
  'login.subtitle': 'Sign in to configure your brand and review activity.',
  'login.email': 'Email',
  'login.password': 'Password',
  'login.submit': 'Sign in',
  'login.submitting': 'Signing in…',

  // Placeholder screens (removed as each feature branch lands)
  'placeholder.title': 'Coming soon',
  'placeholder.body': 'This screen lands in a branch stacked on top of this one.',

  // Errors (shared, plain-language — never a raw status)
  'error.network': 'Could not reach the server. Check your connection and try again.',
  'error.session': 'Your session expired. Please sign in again.',
  'error.forbidden': 'Your account does not have access to this.',
  'error.emailNotVerified': 'Verify your email address before continuing.',
  'error.accountLocked':
    'This account is temporarily locked after too many failed sign-in attempts.',
  'error.rateLimited': 'Too many requests. Wait a moment and try again.',
  'error.server': 'Something went wrong on our end. Please try again.',
} as const;
