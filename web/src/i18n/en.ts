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

  // Shared form fields
  'field.email': 'Email',
  'field.password': 'Password',
  'field.newPassword': 'New password',
  'field.confirmPassword': 'Confirm password',
  'field.passwordHint': 'At least 8 characters',
  'field.passwordMismatch': 'Those passwords do not match.',

  // Sign in
  'login.title': 'Sign in',
  'login.subtitle': 'Sign in to configure your brand and review activity.',
  'login.submit': 'Sign in',
  'login.submitting': 'Signing in…',
  'login.toRegister': 'New here? Create an account',
  'login.toForgot': 'Forgot your password?',

  // Register
  'register.title': 'Create your account',
  'register.subtitle': 'Set up an account to manage your brand and team activity.',
  'register.submit': 'Create account',
  'register.submitting': 'Creating account…',
  'register.emailExists': 'An account with this email already exists. Try signing in.',
  'register.done.title': 'Check your email',
  'register.done.body':
    'We sent a verification link to {email}. Open it to finish setting up your account, then sign in.',
  'register.done.resend': 'Resend the link',
  'register.done.resent': 'If that address still needs verifying, a new link is on its way.',
  'auth.backToLogin': 'Back to sign in',

  // Verify email
  'verify.title': 'Verify your email',
  'verify.verifying': 'Verifying your email…',
  'verify.success.title': 'Email verified',
  'verify.success.body': 'Your email is verified. You can sign in now.',
  'verify.invalid.title': 'This link didn’t work',
  'verify.invalid.body':
    'The verification link is invalid or has expired. Enter your email to get a new one.',
  'verify.needEmail': 'Enter your email and we’ll send a new verification link.',
  'verify.resend.submit': 'Send verification link',
  'verify.resend.sent': 'If that address needs verifying, a new link is on its way.',

  // Forgot password
  'forgot.title': 'Reset your password',
  'forgot.subtitle': 'Enter your email and we’ll send a reset link.',
  'forgot.submit': 'Send reset link',
  'forgot.done.title': 'Check your email',
  'forgot.done.body':
    'If an account exists for {email}, a password reset link is on its way.',

  // Reset password
  'reset.title': 'Choose a new password',
  'reset.subtitle': 'Enter a new password for your account.',
  'reset.submit': 'Update password',
  'reset.submitting': 'Updating…',
  'reset.success.title': 'Password updated',
  'reset.success.body': 'Your password is updated. Sign in with your new password.',
  'reset.noToken.title': 'This reset link is invalid',
  'reset.noToken.body': 'Request a new password reset link to continue.',
  'reset.requestNew': 'Request a new link',

  // Brand Kit
  'brandKit.description':
    'Configure the brand your generated posts are built from. Changes take effect on your next mobile session.',
  'brandKit.saved': 'Saved. This applies on your next mobile session.',
  'brandKit.unsaved': 'Unsaved changes',
  'brandKit.field.name': 'Brand name',
  'brandKit.field.primary': 'Primary colour',
  'brandKit.field.secondary': 'Secondary colour',
  'brandKit.field.tone': 'Tone of voice',
  'brandKit.field.toneHint': 'e.g. warm and concise, playful, formal',
  'brandKit.field.contact': 'Contact info',
  'brandKit.field.hexHint': 'Enter a hex colour like #1a2b3c.',
  'brandKit.logo.label': 'Logo',
  'brandKit.logo.limits': 'JPEG or PNG, up to 10 MB, 200–4096 px on each side.',
  'brandKit.logo.choose': 'Choose file',
  'brandKit.logo.uploading': 'Uploading…',
  'brandKit.logo.uploaded': '{name} — {w}×{h}, uploaded',
  'brandKit.logo.onFile': 'A logo is on file.',
  'brandKit.logo.remove': 'Remove',
  'brandKit.preview.title': 'Brand preview (approximate)',
  'brandKit.preview.localeLabel': 'Preview language',
  'brandKit.preview.placeholderName': 'Your brand',
  'brandKit.preview.safeZone': 'Safe area',
  'brandKit.preview.sampleEn': 'New this week at {brand} — come and see us.',
  'brandKit.preview.sampleAm':
    'በዚህ ሳምንት በ{brand} አዲስ ነገር አለ — ይምጡና ይጎብኙን።',
  'brandKit.preview.cta': 'Visit us',
  'brandKit.preview.toneLabel': 'Tone — {tone}',
  'brandKit.preview.disclaimer':
    'Approximate preview. The final image is composed on the device at export time and may differ.',

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
  'error.quota': 'Your quota is used up. It resets at {time}.',
  'error.quotaNoTime': 'Your quota is used up.',
  'error.server': 'Something went wrong on our end. Please try again.',
} as const;
