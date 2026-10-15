# Typography

Old-vs-modern patterns from [modern-css.com](https://modern-css.com/), snapshot October 2026. Status is the Baseline tier (Widely / Newly / Limited). Recheck Limited features on caniuse.com or webstatus.dev before relying on them.

## Variable Fonts in CSS: One File, All Weights

`Widely available · since 2018` · [source](https://modern-css.com/multiple-font-weights-without-multiple-files/)

You loaded a separate font file for each weight (400, 500, 600, 700), so 4 or more HTTP requests. One variable font file covers the full range with font-weight: 100 900.

Modern:

```css
@font-face {
  font-family: "MyVar";
  src: url("MyVar.woff2");
  font-weight: 100 900;
}
```

Replaces:

```css
@font-face {
  font-family: "MyFont";
  src: url("MyFont-Regular.woff2");
  font-weight: 400;
}

@font-face {
  font-weight: 700;
  ...
}

@font-face {
  font-weight: 600;
  ...
}
```

## Fluid Typography in CSS with clamp()

`Widely available · since 2020` · [source](https://modern-css.com/fluid-typography-without-media-queries/)

The old way used several media queries with different font-sizes. clamp() scales smoothly between a min and max.

Modern:

```css
h1 {
  font-size: clamp(1rem, 2.5vw, 2rem);
}
```

Replaces:

```css
h1 {
  font-size: 1rem;
}

@media (min-width: 600px) {
  h1 {
    font-size: 1.5rem;
  }
}

@media (min-width: 900px) {
  h1 {
    font-size: 2rem;
  }
}
```

## font-display: swap in CSS (Prevent Invisible Text)

`Widely available · since 2020` · [source](https://modern-css.com/font-loading-without-invisible-text/)

Custom fonts used to cause a flash of invisible text (FOIT) while they downloaded. font-display: swap shows the fallback right away, then swaps when the font is ready.

Modern:

```css
@font-face {
  font-family: "MyFont";
  src: url("MyFont.woff2");
  font-display: swap;
}
```

Replaces:

```css
@font-face {
  font-family: "MyFont";
  src: url("MyFont.woff2");
}
```

## CSS font-palette: Color fonts without extra files

`Widely available · since 2022` · [source](https://modern-css.com/css-font-palette/)

Color fonts used to mean shipping several font files or baking colors into the glyphs. font-palette and @font-palette-values switch palettes inside one font, including custom overrides for light and dark themes.

Modern:

```css
@font-palette-values --brand {
  font-family: "Nabla";
  base-palette: 2;
  override-colors: 0 #38bdf8, 1 #0f172a;
}

.logo {
  font-family: "Nabla", fantasy;
  font-palette: --brand;
}
/* one color font, custom palette, no second file */
```

Replaces:

```css
/* separate font files per theme */
@font-face {
  font-family: "BrandBlue";
  src: url("brand-blue.woff2") format("woff2");
}
@font-face {
  font-family: "BrandGrey";
  src: url("brand-grey.woff2") format("woff2");
}

.logo { font-family: "BrandBlue", fantasy; }
@media (prefers-color-scheme: dark) {
  .logo { font-family: "BrandGrey", fantasy; }
}
```

## CSS Type Scale with pow()

`Widely available · since 2023` · [source](https://modern-css.com/css-type-scale-with-pow/)

The old way required Sass or JavaScript to compute exponential type scales. pow() does the math at runtime in the browser so you control the base and ratio with custom properties.

Modern:

```css
:root {
  --scale-base: 1rem;
  --scale-ratio: 1.25;
}

h1 { font-size: calc(var(--scale-base) * pow(var(--scale-ratio), 4)); }
h2 { font-size: calc(var(--scale-base) * pow(var(--scale-ratio), 3)); }
h3 { font-size: calc(var(--scale-base) * pow(var(--scale-ratio), 2)); }
h4 { font-size: calc(var(--scale-base) * pow(var(--scale-ratio), 1)); }
h5 { font-size: calc(var(--scale-base) * pow(var(--scale-ratio), 0)); }
```

Replaces:

```css
// Sass — computed at build time, ratio is baked in
@use "sass:math";

$base: 1rem;
$ratio: 1.25;

h1 { font-size: $base * math.pow($ratio, 4); } // 2.441rem
h2 { font-size: $base * math.pow($ratio, 3); } // 1.953rem
h3 { font-size: $base * math.pow($ratio, 2); } // 1.563rem
h4 { font-size: $base * math.pow($ratio, 1); } // 1.25rem
h5 { font-size: $base * math.pow($ratio, 0); } // 1rem
```

> pow() is Baseline 2023 (Newly available). Supported in Chrome 120+, Firefox 118+, Safari 15.4+, Edge 120+. Consider providing hardcoded fallback sizes for older browsers.

## Balance Headlines in CSS with text-wrap: balance

`Newly available · since 2024` · [source](https://modern-css.com/balanced-headlines-without-manual-line-breaks/)

You used to add br tags by hand or pull in Balance-Text.js. Now one property evens out lines so headlines don't end with a single word.

Modern:

```css
h1, h2 {
  text-wrap: balance;
  max-width: 40ch;
}
```

Replaces:

```css
/* HTML: manual <br> or wrapper for JS */
h1 {
  text-align: center;
  max-width: 40ch;
  /* Balance-Text.js: script + init */
  /* or insert <br> in CMS/HTML */
}
```

## Truncate Text to N Lines in CSS with line-clamp

`Limited availability` · [source](https://modern-css.com/multiline-text-truncation-without-javascript/)

The old way was JS that counted characters or words and appended "...", or the -webkit-line-clamp plus -webkit-box-orient combo. line-clamp is now in the spec and gives you clean multiline truncation.

Modern:

```css
.card-title {
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
  line-clamp: 3;
  overflow: hidden;
}
/* Standard; -webkit- prefix still needed. */
```

Replaces:

```css
/* JS: slice text, append '...'. */
/* or measure via getComputedStyle. Breaks on resize. */
.card-title {
  overflow: hidden;
  text-overflow: ellipsis;
}
/* Older: -webkit-line-clamp + -webkit-box-orient */
```

## CSS Drop Caps with the initial-letter Property

`Limited availability` · [source](https://modern-css.com/drop-caps-without-float-hacks/)

The old way used float, a large font-size, and manual line-height and margin, and it broke across browsers. initial-letter gives you a real drop cap in one property.

Modern:

```css
.drop-cap::first-letter {
  -webkit-initial-letter: 3;
  initial-letter: 3;
}
/* Standard; -webkit- prefix needed for Safari. */
```

Replaces:

```css
.drop-cap::first-letter {
  float: left;
  font-size: 3em;
  line-height: 1;
  margin-right: 8px;
}
```

## CSS text-wrap-style: pretty for Long-Form Paragraphs

`Limited availability` · [source](https://modern-css.com/pretty-paragraph-wrapping-without-orphan-words/)

Long paragraphs often end with one short word on the last line. The old fix was a non-breaking space hand-placed in the copy. text-wrap-style: pretty tells the browser to avoid orphans across the whole paragraph.

Modern:

```css
article p {
  text-wrap: pretty;
}
/* no orphan words on the last line
```

Replaces:

```css
article p {
  text-wrap: wrap;
}
/* default browser line-breaking, single-word last lines stay
```

> The text-wrap-style property is Baseline Newly Available since 2024, but the pretty value specifically has not shipped in Firefox yet. Chrome and Edge support it from version 130, Safari from 17.5 (with a refined algorithm in 26). Firefox falls back to default wrapping with no layout breakage, so treat pretty as progressive enhancement.

## CSS text-box-trim and text-box-edge for cap-height centering

`Limited availability` · [source](https://modern-css.com/centering-button-text-without-line-height-tweaks/)

Most fonts add invisible space above the cap line and below the baseline. That half-leading is why button text always feels one pixel off. text-box-trim removes it so text aligns to its actual letterforms.

Modern:

```css
.btn {
  text-box-trim: trim-both;
  text-box-edge: cap alphabetic;
  padding: 12px 20px;
}
/* the button measures from the cap line, not the metric box */
```

Replaces:

```css
/* per-font line-height tuning to fake a centered look */
.btn {
  line-height: 1.15;
  padding: 13px 20px 11px;
}
```

> Firefox has the implementation but keeps it disabled by default through at least 149. Chrome 133, Safari 18.2, and Edge 133 ship it on. Pair with normal padding so Firefox simply renders with the usual half-leading and the button still looks fine.

## Vertically Center Text in CSS with text-box-trim

`Limited availability` · [source](https://modern-css.com/vertical-text-centering-without-padding-hacks/)

Text always looked optically off-center because font metrics include extra space for ascenders and descenders. The text-box property trims that invisible space for true visual centering.

Modern:

```css
.btn {
  padding: 10px 20px;
  text-box: trim-both cap alphabetic;
}
```

Replaces:

```css
.btn {
  display: inline-flex;
  align-items: center;
  padding: 10px 20px;
  padding-top: 8px;
}
```

## CSS text-spacing-trim: Clean CJK and Quote Punctuation

`Limited availability` · [source](https://modern-css.com/cjk-and-quote-spacing-without-manual-kerning/)

Full-width punctuation in CJK and quoted text ships with extra space baked into the glyph. The old fix used negative margins and text-indent per element. text-spacing-trim hands that decision to the font.

Modern:

```css
.prose {  text-spacing-trim: trim-start; 
}
```

Replaces:

```css
.prose p:first-letter {
  margin-inline-start: -.25em;
}

.prose p {
  text-indent: -.25em;
  padding-inline-start: .25em;
}

.prose q::before {
  margin-inline-start: -.2em;
}

.prose q::after {
  margin-inline-end: -.2em;
}
```

## Automatic CSS Type Scale with sibling-index() and pow()

`Limited availability` · [source](https://modern-css.com/automatic-type-scale-without-manual-sizes/)

Heading hierarchies often ship as hardcoded font-size ladders. This experimental pattern derives sizes from the document outline with :heading(), sibling-index(), and pow() so the scale adjusts itself.

Modern:

```css
/* Experimental: requires :heading(), sibling-index(), and pow() support */
:heading {
  font-weight: 600;
  font-size:    calc(1rem * pow(1.2, 5 - sibling-index()));
}
/* Fallback: keep a simple manual ladder for all other browsers */
h1 {
  font-size: 2.5rem;
}

h2 {
  font-size: 2rem;
}

h3 {
  font-size: 1.5rem;
}
```

Replaces:

```css
h1 {
  font-size: 2.5rem;
}

h2 {
  font-size: 2rem;
}

h3 {
  font-size: 1.5rem;
}

h4 {
  font-size: 1.25rem;
}

h5 {
  font-size: 1.1rem;
}

h6 {
  font-size: 1rem;
}
```

> Note: The :heading() selector and sibling-index() function are experimental and do not have Baseline support yet. Treat this outline-driven type scale as progressive enhancement only and keep a simple font-size ladder as the primary path.
