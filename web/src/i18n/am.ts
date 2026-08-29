import type { Messages } from './messages';

/**
 * Amharic message catalog.
 *
 * PLACEHOLDER / BEST-EFFORT. Only `app.name` and `app.tagline` are verified
 * (from the Figma design system and the mobile app's `app_am.arb`). Every other
 * value below is a best-effort translation and MUST be reviewed by a native
 * Amharic speaker before public beta — the PRD requires this
 * (`backend/docs/OPEN_QUESTIONS.md`, and mobile follows the same policy).
 *
 * The `: Messages` annotation makes `tsc` fail if this drifts from `en.ts`.
 * `i18n/__tests__/parity.test.ts` adds a runtime check for empty / untranslated
 * values.
 */
const am: Messages = {
  // Verified
  'app.name': 'ቀላል ስቱዲዮ',
  'app.tagline': 'ንግድዎን በመስመር ላይ ያሳድጉ',

  // REVIEW: everything below pending native-speaker review
  'app.portal': 'የአስተዳደር መግቢያ',

  'nav.sections': 'ክፍሎች',
  'nav.brandKit': 'የብራንድ ኪት',
  'nav.usage': 'አጠቃቀም',
  'nav.flags': 'የተጠቆሙ ጥያቄዎች',
  'nav.users': 'የተጠቃሚ ገደቦች',
  'nav.group.brand': 'ብራንድ',
  'nav.group.oversight': 'ክትትል',
  'action.signOut': 'ውጣ',
  'action.save': 'አስቀምጥ',
  'action.saving': 'በማስቀመጥ ላይ…',
  'action.cancel': 'ይቅር',
  'action.retry': 'እንደገና ይሞክሩ',
  'state.loading': 'በመጫን ላይ…',

  'theme.label': 'ገጽታ',
  'theme.light': 'ብሩህ',
  'theme.dark': 'ጨለማ',
  'theme.system': 'የስርዓት',

  'lang.label': 'ቋንቋ',
  'lang.en': 'English',
  'lang.am': 'አማርኛ',

  'field.email': 'ኢሜይል',
  'field.password': 'የይለፍ ቃል',
  'field.newPassword': 'አዲስ የይለፍ ቃል',
  'field.confirmPassword': 'የይለፍ ቃል ያረጋግጡ',
  'field.passwordHint': 'ቢያንስ 8 ቁምፊዎች',
  'field.passwordMismatch': 'የይለፍ ቃላቱ አይዛመዱም።',

  'login.title': 'ግባ',
  'login.subtitle': 'ብራንድዎን ለማዋቀር እና እንቅስቃሴን ለመገምገም ይግቡ።',
  'login.submit': 'ግባ',
  'login.submitting': 'በመግባት ላይ…',
  'login.toRegister': 'እዚህ አዲስ ነዎት? መለያ ይፍጠሩ',
  'login.toForgot': 'የይለፍ ቃልዎን እረሱት?',

  'register.title': 'መለያዎን ይፍጠሩ',
  'register.subtitle': 'ብራንድዎን እና የቡድን እንቅስቃሴን ለማስተዳደር መለያ ያዘጋጁ።',
  'register.submit': 'መለያ ፍጠር',
  'register.submitting': 'መለያ በመፍጠር ላይ…',
  'register.emailExists': 'በዚህ ኢሜይል የተመዘገበ መለያ አለ። ለመግባት ይሞክሩ።',
  'register.done.title': 'ኢሜይልዎን ይመልከቱ',
  'register.done.body':
    'የማረጋገጫ አገናኝ ወደ {email} ልከናል። መለያዎን ማዘጋጀት ለማጠናቀቅ ይክፈቱት፣ ከዚያ ይግቡ።',
  'register.done.resend': 'አገናኙን እንደገና ላክ',
  'register.done.resent': 'ያ አድራሻ ማረጋገጥ የሚያስፈልገው ከሆነ አዲስ አገናኝ በመንገድ ላይ ነው።',
  'auth.backToLogin': 'ወደ መግቢያ ተመለስ',

  'verify.title': 'ኢሜይልዎን ያረጋግጡ',
  'verify.verifying': 'ኢሜይልዎን በማረጋገጥ ላይ…',
  'verify.success.title': 'ኢሜይል ተረጋግጧል',
  'verify.success.body': 'ኢሜይልዎ ተረጋግጧል። አሁን መግባት ይችላሉ።',
  'verify.invalid.title': 'ይህ አገናኝ አልሰራም',
  'verify.invalid.body':
    'የማረጋገጫ አገናኙ ልክ ያልሆነ ወይም ጊዜው ያለፈበት ነው። አዲስ ለማግኘት ኢሜይልዎን ያስገቡ።',
  'verify.needEmail': 'ኢሜይልዎን ያስገቡ፣ አዲስ የማረጋገጫ አገናኝ እንልካለን።',
  'verify.resend.submit': 'የማረጋገጫ አገናኝ ላክ',
  'verify.resend.sent': 'ያ አድራሻ ማረጋገጥ የሚያስፈልገው ከሆነ አዲስ አገናኝ በመንገድ ላይ ነው።',

  'forgot.title': 'የይለፍ ቃልዎን ዳግም ያስጀምሩ',
  'forgot.subtitle': 'ኢሜይልዎን ያስገቡ፣ የዳግም ማስጀመሪያ አገናኝ እንልካለን።',
  'forgot.submit': 'የዳግም ማስጀመሪያ አገናኝ ላክ',
  'forgot.done.title': 'ኢሜይልዎን ይመልከቱ',
  'forgot.done.body':
    'ለ {email} መለያ ካለ፣ የይለፍ ቃል ዳግም ማስጀመሪያ አገናኝ በመንገድ ላይ ነው።',

  'reset.title': 'አዲስ የይለፍ ቃል ይምረጡ',
  'reset.subtitle': 'ለመለያዎ አዲስ የይለፍ ቃል ያስገቡ።',
  'reset.submit': 'የይለፍ ቃል አዘምን',
  'reset.submitting': 'በማዘመን ላይ…',
  'reset.success.title': 'የይለፍ ቃል ተዘምኗል',
  'reset.success.body': 'የይለፍ ቃልዎ ተዘምኗል። በአዲሱ የይለፍ ቃልዎ ይግቡ።',
  'reset.noToken.title': 'ይህ የዳግም ማስጀመሪያ አገናኝ ልክ አይደለም',
  'reset.noToken.body': 'ለመቀጠል አዲስ የይለፍ ቃል ዳግም ማስጀመሪያ አገናኝ ይጠይቁ።',
  'reset.requestNew': 'አዲስ አገናኝ ይጠይቁ',

  'brandKit.description':
    'የሚፈጠሩ ልጥፎችዎ የሚገነቡበትን ብራንድ ያዋቅሩ። ለውጦች በሚቀጥለው የሞባይል ክፍለ ጊዜዎ ተግባራዊ ይሆናሉ።',
  'brandKit.saved': 'ተቀምጧል። ይህ በሚቀጥለው የሞባይል ክፍለ ጊዜዎ ተግባራዊ ይሆናል።',
  'brandKit.unsaved': 'ያልተቀመጡ ለውጦች',
  'brandKit.field.name': 'የብራንድ ስም',
  'brandKit.field.primary': 'ዋና ቀለም',
  'brandKit.field.secondary': 'ሁለተኛ ቀለም',
  'brandKit.field.tone': 'የአነጋገር ቃና',
  'brandKit.field.toneHint': 'ለምሳሌ፦ ሞቅ ያለ እና አጭር፣ ተጫዋች፣ መደበኛ',
  'brandKit.field.contact': 'የመገኛ መረጃ',
  'brandKit.field.hexHint': 'እንደ #1a2b3c ያለ የሄክስ ቀለም ያስገቡ።',
  'brandKit.logo.label': 'አርማ',
  'brandKit.logo.limits': 'JPEG ወይም PNG፣ እስከ 10 ሜባ፣ በእያንዳንዱ ጎን 200–4096 ፒክስል።',
  'brandKit.logo.choose': 'ፋይል ይምረጡ',
  'brandKit.logo.uploading': 'በመስቀል ላይ…',
  'brandKit.logo.uploaded': '{name} — {w}×{h}፣ ተሰቅሏል',
  'brandKit.logo.onFile': 'አርማ ተመዝግቧል።',
  'brandKit.logo.remove': 'አስወግድ',
  'brandKit.preview.title': 'የብራንድ ቅድመ-እይታ (ግምታዊ)',
  'brandKit.preview.localeLabel': 'የቅድመ-እይታ ቋንቋ',
  'brandKit.preview.placeholderName': 'ብራንድዎ',
  'brandKit.preview.safeZone': 'አስተማማኝ ቦታ',
  'brandKit.preview.sampleEn': 'New this week at {brand} — come and see us.',
  'brandKit.preview.sampleAm':
    'በዚህ ሳምንት በ{brand} አዲስ ነገር አለ — ይምጡና ይጎብኙን።',
  'brandKit.preview.cta': 'ይጎብኙን',
  'brandKit.preview.toneLabel': 'ቃና — {tone}',
  'brandKit.preview.disclaimer':
    'ግምታዊ ቅድመ-እይታ። የመጨረሻው ምስል በመሣሪያው ላይ በመላክ ጊዜ ይዘጋጃል እና ሊለያይ ይችላል።',

  'placeholder.title': 'በቅርቡ ይመጣል',
  'placeholder.body': 'ይህ ማያ ገጽ ከዚህ በላይ በተደረደረ ቅርንጫፍ ውስጥ ይመጣል።',

  'error.network': 'አገልጋዩ ላይ መድረስ አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።',
  'error.session': 'ክፍለ ጊዜዎ አብቅቷል። እባክዎ እንደገና ይግቡ።',
  'error.forbidden': 'መለያዎ ለዚህ መዳረሻ የለውም።',
  'error.emailNotVerified': 'ከመቀጠልዎ በፊት የኢሜይል አድራሻዎን ያረጋግጡ።',
  'error.accountLocked':
    'ይህ መለያ በተደጋጋሚ የተሳሳተ የመግቢያ ሙከራ ምክንያት ለጊዜው ተቆልፏል።',
  'error.rateLimited': 'በጣም ብዙ ጥያቄዎች። ለአፍታ ቆይተው እንደገና ይሞክሩ።',
  'error.quota': 'ኮታዎ አልቋል። በ {time} ዳግም ይጀምራል።',
  'error.quotaNoTime': 'ኮታዎ አልቋል።',
  'error.server': 'በእኛ በኩል ስህተት ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።',
};

export default am;
