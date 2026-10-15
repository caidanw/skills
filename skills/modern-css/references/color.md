# Color

Old-vs-modern patterns from [modern-css.com](https://modern-css.com/), snapshot October 2026. Status is the Baseline tier (Widely / Newly / Limited). Recheck Limited features on caniuse.com or webstatus.dev before relying on them.

## CSS Wide-Gamut Color: display-p3 and rec2020

`Widely available · since 2023` · [source](https://modern-css.com/vivid-colors-beyond-srgb/)

The old way was hex, rgb(), or hsl(), all stuck in sRGB. On P3 or other wide-gamut screens, those colors look flat. oklch and color(display-p3 ...) unlock the extra range.

Modern:

```css
.hero {
  color: oklch(0.7 0.25 29);
}
/* Or: color(display-p3 1 0.2 0.1) for P3. */
```

Replaces:

```css
.hero {
  color: #c85032;
}
/* Hex, rgb(), hsl() are sRGB. Limited on wide-gamut screens. */
```

## CSS color-mix() Function (No Sass Required)

`Widely available · since 2023` · [source](https://modern-css.com/mixing-colors-without-a-preprocessor/)

Blending two colors used to require Sass, Less, or a JS utility. color-mix() does it in plain CSS, and it supports perceptually uniform color spaces like oklch.

Modern:

```css
.card {
  background: color-mix(     in oklch, #3b82f6 60%, #ec4899   );
}
```

Replaces:

```css
// _variables.scss
$blue: #3b82f6;
$pink: #ec4899;
$blend: mix($blue, $pink, 60%);
```

## OKLCH Color in CSS: Perceptually Uniform Colors

`Widely available · since 2023` · [source](https://modern-css.com/perceptually-uniform-colors-with-oklch/)

HSL looks like it should be perceptually uniform, but it isn't. Yellow at hsl(60 100% 50%) appears far brighter than blue at hsl(240 100% 50%) at the same lightness. oklch uses a model where L actually means the same perceived brightness across all hues.

Modern:

```css
/* oklch: L is perceptually uniform across hues */
--brand:       oklch(0.55 0.2 264);
--brand-light: oklch(0.75 0.2 264);
--brand-dark:  oklch(0.35 0.2 264);
/* only L changes */
```

Replaces:

```css
/* HSL: same L value, different perceived brightness */
--yellow: hsl(60 100% 50%);
/* blinding */
--blue:   hsl(240 100% 50%);
/* dark */
/* manually tweak each shade to look balanced */
--brand-light: hsl(246 87% 68%);
```

## Frosted Glass Effect in CSS with backdrop-filter

`Newly available · since 2024` · [source](https://modern-css.com/frosted-glass-effect-without-opacity-hacks/)

Frosted glass used to require a blurred copy of the background behind the element: a pseudo-element with the same background image, a filter: blur, and z-index stacking. backdrop-filter applies effects directly to whatever is rendered behind the element.

Modern:

```css
.glass {
  backdrop-filter: blur(12px) saturate(1.5);
  background: rgba(255,255,255,.1);
}
```

Replaces:

```css
.card::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: url(bg.jpg);
  background-size: cover;
  filter: blur(12px);
  z-index: -1;
}
```

## CSS Relative Color Syntax: Lighten, Darken Without Sass

`Newly available · since 2024` · [source](https://modern-css.com/color-variants-without-sass-functions/)

The old way used Sass functions like lighten(), darken(), and saturate() at compile time. Relative color syntax derives variants from a variable at runtime with oklch(from var(--x) ...).

Modern:

```css
.btn {
  background:    oklch(from var(--brand) calc(l + 0.2) c h);
}
```

Replaces:

```css
/* Sass: @use 'sass:color'; */
/* Sass: color.adjust($brand, $lightness: 20%) */
.btn {
  background: lighten(var(--brand), 20%);
}
```

## Dark Mode Colors in CSS with light-dark()

`Newly available · since 2024` · [source](https://modern-css.com/dark-mode-colors-without-duplicating-values/)

You defined every variable in :root and again inside @media (prefers-color-scheme: dark). light-dark() holds both values in one place so you do not repeat yourself.

Modern:

```css
:root {
  color-scheme: light dark;
  color: light-dark(#111, #eee);
}
```

Replaces:

```css
:root {
  --text: #111;
  --bg: #fff;
}

@media (prefers-color-scheme: dark) {
  :root {
    --text: #eee;
    --bg: #222;
  }
}
```

## CSS contrast-color() for Readable Text

`Newly available · since 2026` · [source](https://modern-css.com/readable-text-without-manual-contrast-checks/)

Picking readable text used to mean hardcoding color: white or color: black for each background. contrast-color() does the math automatically, returning whichever meets WCAG AA contrast against the given color.

Modern:

```css
.badge {
  background: var(--bg);
  color: contrast-color(var(--bg));
}
```

Replaces:

```css
/* Hardcode a text color per background */
.badge-blue {
  background: #1e40af;
  color: white;
}

.badge-yellow {
  background: #fde047;
  color: black;
}
/* Repeat for every color variant */
```

## CSS accent-color for Checkboxes, Radios, and Range Inputs

`Limited availability` · [source](https://modern-css.com/styling-form-controls-without-rebuilding-them/)

The old way was appearance: none plus dozens of lines to rebuild the control. accent-color changes the native control color in one property.

Modern:

```css
input[type="checkbox"],input[type="radio"] {
  accent-color: #7c3aed;
}
```

Replaces:

```css
input[type="checkbox"] {
  appearance: none;
  width: 1.25rem;
  height: 1.25rem;
  border: 2px solid ...;
  background: ...;
  border-radius: ...;
}
```
