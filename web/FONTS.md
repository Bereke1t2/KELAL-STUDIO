# Bundled fonts

The portal self-hosts its two typefaces so an Amharic glyph is **never**
system-font-dependent — a missing glyph rendering as a box (tofu) is prohibited
(PRD §6.7, the product's highest-rated risk). This mirrors `mobile/`, which
bundles `NotoSansEthiopic-Regular.ttf`.

| File | Family | Weight | Coverage |
|---|---|---|---|
| `noto-sans-latin-400.woff2` | Noto Sans | 400 only | Latin + Latin Extended, punctuation, currency |
| `noto-sans-ethiopic-400.woff2` | Noto Sans Ethiopic | 400 only | Ethiopic, Supplement, Extended, Extended-A |

Weight 400 is the **only** weight, by design — the type system builds hierarchy
from size, spacing, and colour, never weight (`mobile/lib/core/theme/app_typography.dart`).

## Sources

- **Noto Sans** — Noto Project, version 2.015, SIL OFL 1.1. Instanced to
  `wght=400` from the variable font `NotoSans[wght].ttf`.
- **Noto Sans Ethiopic** — Noto Project, version 2.102, SIL OFL 1.1. Subset from
  the exact static file `mobile/assets/fonts/NotoSansEthiopic-Regular.ttf` so the
  web and mobile renderers agree glyph-for-glyph.

License text for both is in `OFL.txt` (ships with the fonts, as OFL requires).

## Regenerating

```sh
# Latin: pin the variable font to a single weight, then subset.
python3 -m fontTools.varLib.instancer "NotoSans[wght].ttf" wght=400 \
  -o notosans-400.ttf --update-name-table

pyftsubset notosans-400.ttf \
  --unicodes='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0300-0304,U+0308,U+0329,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD,U+0100-017F,U+0180-024F,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20BF,U+2113,U+2C60-2C7F,U+A720-A7FF' \
  --layout-features='kern,liga,clig,calt,mark,mkmk,ccmp,locl' \
  --flavor=woff2 --desubroutinize --name-IDs='*' \
  --output-file=noto-sans-latin-400.woff2

# Ethiopic: already single-weight; subset the mobile file directly.
pyftsubset NotoSansEthiopic-Regular.ttf \
  --unicodes='U+0020,U+00A0,U+200B,U+2010,U+2013,U+2014,U+2018,U+2019,U+201C,U+201D,U+2026,U+1200-137F,U+1380-139F,U+2D80-2DDF,U+AB00-AB2F' \
  --layout-features='kern,liga,clig,calt,mark,mkmk,ccmp,locl' \
  --flavor=woff2 --desubroutinize --name-IDs='*' \
  --output-file=noto-sans-ethiopic-400.woff2
```

The `unicode-range` in `src/styles/fonts.css` must stay in sync with the
`--unicodes` above.
