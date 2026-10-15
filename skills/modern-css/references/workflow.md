# Workflow, architecture, accessibility

Old-vs-modern patterns from [modern-css.com](https://modern-css.com/), snapshot October 2026. Status is the Baseline tier (Widely / Newly / Limited). Recheck Limited features on caniuse.com or webstatus.dev before relying on them.

## CSS isolation: Prevent z-index Overflow

`Widely available · since 2015` · [source](https://modern-css.com/z-index-isolation/)

Child elements with z-index normally overflow and overlap elements outside their container, like fixed headers or floating sidebars. The isolation property creates a new stacking context, keeping z-index values contained within the element and its descendants.

Modern:

```css
.card-container {
  isolation: isolate;
}

.card {
  z-index: 100;
}
/* z-index contained within .card-container */
```

Replaces:

```css
/* Without isolation, z-index escapes the container */
.card-container {
  position: relative;
  z-index: 1;
  /* Still doesn't fully contain child z-index values */
}

.card {
  z-index: 100;
  /* Can still overlap fixed/floating elements outside */
}
/* Or: restructure HTML to move overlapping content */
/* Or: manage z-index globally across entire page (brittle, scales poorly) */
```

## CSS Custom Properties for Theme Variables

`Widely available · since 2017` · [source](https://modern-css.com/theme-variables-without-a-preprocessor/)

Sass and LESS variables compile to static values. Custom properties live in the browser and can change at runtime.

Modern:

```css
:root {
  --primary: #7c3aed;
  --spacing: 16px;
}

.btn {
  background: var(--primary);
}
```

Replaces:

```css
// Sass/LESS: compile-time only
$primary: #7c3aed;
$spacing: 16px;
.btn {
  background: $primary;
  padding: $spacing;
}
```

## CSS Feature Detection with @supports (No Modernizr)

`Widely available · since 2020` · [source](https://modern-css.com/css-feature-detection-without-javascript/)

Detecting CSS feature support required JavaScript: either Modernizr, inline CSS.supports() checks, or testing computed styles. @supports lets CSS apply styles conditionally based on whether the browser supports a given property and value.

Modern:

```css
@supports (display: grid) {
  .layout {
    display: grid;
  }
}
```

Replaces:

```css
// JS: detect support, add class
if (CSS.supports('container-type', 'inline-size')) {
  document.documentElement.classList.add('has-container-queries');
}
```

## Larger Touch Targets in CSS Without Changing Element Size

`Widely available · since 2020` · [source](https://modern-css.com/larger-touch-targets-without-changing-element-size/)

The old fix was adding padding that bloated the visual size. A pseudo-element expands the hit area invisibly, only on touch devices.

Modern:

```css
.button {
  position: relative;
}

@media (pointer: coarse) {
  .button::after {
    content: '';
    position: absolute;
    inset: -8px;
  }
}
```

Replaces:

```css
.button {
  min-width: 44px;
  min-height: 44px;
  padding: 12px 20px;
}// Padding forces the visual size to grow, disrupting surrounding layout.
```

## Control CSS Specificity with @layer (No !important)

`Widely available · since 2022` · [source](https://modern-css.com/controlling-specificity-without-important/)

The old way was stacking more specific selectors or throwing !important. @layer lets you decide order without fighting specificity.

Modern:

```css
@layer base, components, utilities;
@layer utilities {
  .mt-4 {
    margin-top: 1rem;
  }
}
```

Replaces:

```css
.card .title {
  font-size: 1rem;
}

.page .card .title {
  font-size: 1.25rem;
}

.page .card .title.special {
  color: red !important;
}// More selectors or !important to win
```

## Organizing CSS with cascade layers

`Widely available · since 2022` · [source](https://modern-css.com/organizing-css-with-cascade-layers/)

Old approach: stack selectors, raise specificity, throw !important. Cascade layers let you declare a priority order once, then write clean CSS.

Modern:

```css
@layer reset, base, components, utilities;

@layer reset {
  * { margin: 0; padding: 0; }
}

@layer base {
  body {
    font-family: sans-serif;
  }
}

@layer components {
  .card {
    padding: 1rem;
    background: white;
    border: 1px solid #ccc;
  }

  .card h2 {
    margin-top: 0;
    color: #333;
  }

  .card.highlight {
    background: yellow;
  }

  .card.highlight h2 {
    color: red;
  }
}

@layer utilities {
  .mt-4 { margin-top: 1rem; }
  .mt-2 { margin-top: 0.5rem; }
}
/* layers handle priority, no !important needed */
```

Replaces:

```css
/* Base styles */
body {
  margin: 0;
  font-family: sans-serif;
}
/* Components - start simple */
.card {
  padding: 1rem;
  background: white;
  border: 1px solid #ccc;
}

.card h2 {
  margin-top: 0;
  color: #333;
}

.card.highlight {
  background: yellow;
}

.card.highlight h2 {
  color: red;
}
/* Utilities - need more specificity or !important to override components */
.mt-4 {
  margin-top: 1rem !important;
}

.mt-2 {
  margin-top: 0.5rem !important;
}
/* If utilities still don't win, add more specificity */
.sidebar .card .mt-4 {
  margin-top: 0.5rem !important;
}
/* specificity wars: stacking selectors, fighting !important */
```

## CSS Dark Mode with color-scheme: light dark

`Widely available · since 2022` · [source](https://modern-css.com/dark-mode-defaults-without-extra-css/)

You used to restyle every form control, scrollbar, and background for dark mode. color-scheme tells the browser to use its built-in light or dark styling for those parts.

Modern:

```css
:root {
  color-scheme: light dark;
}
```

Replaces:

```css
@media (prefers-color-scheme: dark) {
  input, select, textarea, button {
    background: #333;
    color: #eee;
  }

  ::-webkit-scrollbar {
    ...
  }
}
```

## CSS forced-colors media query for Windows High Contrast

`Widely available · since 2022` · [source](https://modern-css.com/high-contrast-support-without-broken-ui/)

Windows High Contrast and similar forced-color modes ignore most of your CSS. Custom backgrounds vanish, drop shadows disappear, and decorative borders get stripped. forced-colors lets you opt back in with system colors that the OS guarantees will be readable.

Modern:

```css
.btn {
  background: var(--accent);
  color: white;
  border: 1px solid transparent;
}

@media (forced-colors: active) {
  .btn {
    background: ButtonFace;
    color: ButtonText;
    border: 1px solid ButtonText;
    forced-color-adjust: none;
  }
}
/* High Contrast users see a real button instead of a coloured rectangle */
```

Replaces:

```css
/* no forced-colors handling: in High Contrast mode the background is stripped
   and the transparent border becomes invisible. The button disappears. */
.btn {
  background: var(--accent);
  color: white;
  border: 1px solid transparent;
}
```

## Native CSS Nesting (No Sass or Less)

`Widely available · since 2023` · [source](https://modern-css.com/nesting-selectors-without-sass-or-less/)

Selector nesting was the #1 reason people reached for Sass. It's now built into CSS and part of Baseline 2023. Same & syntax, zero build tools.

Modern:

```css
/* nav.css, plain CSS, no compiler */
.nav {
  display: flex;
  gap: 8px;
  & a {
    color: #888;
    text-decoration: none;
    &:hover {
      color: white;
    }
  }
}
```

Replaces:

```css
// nav.scss, requires Sass compiler
.nav {
  display: flex;
  gap: 8px;
  & a {
    color: blue;
  }
}
```

## CSS Lazy Rendering with content-visibility: auto

`Newly available · since 2025` · [source](https://modern-css.com/lazy-rendering-without-intersection-observer/)

The old way used JavaScript's IntersectionObserver to detect when elements entered the viewport, then loaded or rendered them. Now CSS handles it with content-visibility: auto.

Modern:

```css
.section {
  content-visibility: auto;
  contain-intrinsic-size: auto 500px;
}
```

Replaces:

```css
// JavaScript
const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        renderContent(entry.target);
      }
    });
  }
);
```

## CSS @property for Typed Custom Properties

`Newly available · since 2024` · [source](https://modern-css.com/typed-custom-properties-without-javascript/)

Custom properties were strings. You couldn't animate them or get browser validation. @property gives you a type, so the browser can interpolate and validate.

Modern:

```css
@property --hue {
  syntax: "<angle>";
  inherits: false;
  initial-value: 0deg;
}

.wheel {
  background: hsl(var(--hue), 80%, 50%);
  transition: --hue .3s;
}
```

Replaces:

```css
:root {
  --hue: 0;
}

.wheel {
  background: hsl(var(--hue), 80%, 50%);
  transition: --hue .3s;
  /* ignored, not interpolable */
}
```

## CSS @scope: Scoped Styles Without BEM

`Newly available · since 2026` · [source](https://modern-css.com/scoped-styles-without-bem-naming/)

To avoid leaks you used BEM, CSS Modules, or styled-components. @scope limits selectors to a root and optional boundary so you can use short names safely.

Modern:

```css
@scope (.card) {
  .title {
    font-size: 1.25rem;
    margin-bottom: 0.5rem;
  }

  .body {
    color: #444;
  }
}
/* HTML: class="card", class="title" */
```

Replaces:

```css
.card__title {
  font-size: 1.25rem;
  margin-bottom: 0.5rem;
}

.card__body {
  color: #444;
}
/* HTML: class="card__title" */
```

> Baseline Newly available since 2026 (Chrome 143, Firefox 146, Safari 26.4, Edge 143). Browsers that don't understand @scope drop the whole block, so .title and .body inside it never apply. Those rules have to live outside the at-rule if those versions still matter.

## CSS attr() with Type: Typed HTML Attribute Values

`Limited availability` · [source](https://modern-css.com/typed-attribute-values-without-javascript/)

Reading data attributes for styling used to require JavaScript to parse dataset values and set inline styles or custom properties. Advanced attr() lets CSS read HTML attributes directly as typed values: numbers, colors, lengths, and more.

Modern:

```css
.bar {
  width: attr(     data-pct type(<percentage>)   );
}
```

Replaces:

```css
/* JS: read data attr and set style */
document.querySelectorAll('.bar')   .forEach(el => {
  const pct = el.dataset.pct;     el.style.width = pct + '%';     el.style.setProperty(       '--pct', pct     );
});
```

## CSS Range Style Queries: style(--progress > 50%)

`Limited availability` · [source](https://modern-css.com/range-style-queries-without-multiple-blocks/)

Testing custom property ranges used to require multiple @container style() blocks or JavaScript comparisons. Range style queries let you write numeric comparisons directly: style(--progress > 50%).

Modern:

```css
@container style(
--progress > 75% /* */
) {
  .bar {
    background: var(--green);
  }
}
```

Replaces:

```css
/* Multiple discrete checks */
@container style(--progress: 0%) {
  .bar {
    background: red;
  }
}

@container style(--progress: 25%) {
  .bar {
    background: orange;
  }
}

@container style(--progress: 50%) {
  .bar {
    background: yellow;
  }
}
/* ... repeat for every threshold */
/* Or use JavaScript to set classes */
/* based on the numeric value */
```

## CSS @function for Reusable Logic (No Sass Mixins)

`Limited availability` · [source](https://modern-css.com/reusable-css-logic-without-sass-mixins/)

Reusable calculations and logic in stylesheets used to require Sass or other preprocessors. Native CSS @function lets you define custom functions that return computed values, right in your stylesheet.

Modern:

```css
@function --fluid( /* */
  --min <length>, /* */
  --max <length> /* */
) returns <length> {
  result: clamp(
    var(--min),
    50vi,
    var(--max)
  );
}
```

Replaces:

```css
// Sass / SCSS
@function fluid($min, $max) {
  @return clamp(
    $min,
    calc($min + ($max - $min) * ((100vw - 320px) / 960)),
    $max
  );
}
```

> Chrome and Edge 139+ support @function. Firefox and Safari have not shipped it yet. Use a Sass or PostCSS fallback for wider coverage, or progressively enhance with @supports.

## CSS if() Function for Inline Conditional Styles

`Limited availability` · [source](https://modern-css.com/inline-conditional-styles-without-javascript/)

Conditional styling used to require JavaScript to toggle classes based on state. CSS if() lets you write inline conditions that respond to custom property values, media features, and container queries.

Modern:

```css
.btn {
  background: if(     style(--variant: primary):      blue;
  else: gray   );
}
```

Replaces:

```css
/* Multiple class variants */
.btn {
  background: gray;
}

.btn.primary {
  background: blue;
}

.btn.danger {
  background: red;
}
/* Plus JS to manage state */
el.classList.toggle(   'primary',  isPrimary );
/* Duplicated rules per variant */
```
