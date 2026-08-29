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
 * The `: Messages` annotation makes `tsc` fail if this drifts from `en.ts`
 * (missing key, renamed key, extra key). `i18n/__tests__/parity.test.ts` adds
 * a runtime check for empty values and untranslated strings.
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

  'login.title': 'ግባ',
  'login.subtitle': 'ብራንድዎን ለማዋቀር እና እንቅስቃሴን ለመገምገም ይግቡ።',
  'login.email': 'ኢሜይል',
  'login.password': 'የይለፍ ቃል',
  'login.submit': 'ግባ',
  'login.submitting': 'በመግባት ላይ…',

  'placeholder.title': 'በቅርቡ ይመጣል',
  'placeholder.body': 'ይህ ማያ ገጽ ከዚህ በላይ በተደረደረ ቅርንጫፍ ውስጥ ይመጣል።',

  'error.network': 'አገልጋዩ ላይ መድረስ አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።',
  'error.session': 'ክፍለ ጊዜዎ አብቅቷል። እባክዎ እንደገና ይግቡ።',
  'error.forbidden': 'መለያዎ ለዚህ መዳረሻ የለውም።',
  'error.emailNotVerified': 'ከመቀጠልዎ በፊት የኢሜይል አድራሻዎን ያረጋግጡ።',
  'error.accountLocked':
    'ይህ መለያ በተደጋጋሚ የተሳሳተ የመግቢያ ሙከራ ምክንያት ለጊዜው ተቆልፏል።',
  'error.rateLimited': 'በጣም ብዙ ጥያቄዎች። ለአፍታ ቆይተው እንደገና ይሞክሩ።',
  'error.server': 'በእኛ በኩል ስህተት ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።',
};

export default am;
