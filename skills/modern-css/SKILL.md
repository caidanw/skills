---
name: modern-css
description: >
  Write modern CSS using native features instead of legacy hacks, workarounds, and JavaScript.
  Covers layout, selectors, color, typography, animation, HTML-native UI, and workflow with 118
  old-vs-modern patterns from modern-css.com. Use when writing, reviewing, or refactoring CSS, or
  when replacing JavaScript UI behavior with native CSS or HTML. Prefers Baseline features and asks
  before using ones with limited browser support.
---

# Modern CSS

Reach for the native CSS or HTML feature first. Most old hacks (transform centering, padding-top
aspect ratios, JS scroll listeners, Sass color math, modal and carousel libraries) now have native
replacements.

Source: [modern-css.com](https://modern-css.com/), snapshot October 2026. Each reference entry has the
modern code, the legacy code it replaces, a support note when one matters, and a link to the live demo.

## Support policy

Status uses [Baseline](https://web.dev/baseline) tiers:

1. **Widely**: works in every major browser for 2.5+ years. Use without asking. When you touch legacy
   code a Widely feature replaces, suggest the swap.
2. **Newly**: works in the latest version of every major browser. Use it and say it is new. If the
   project supports older browsers, add a fallback or gate it with `@supports`.
3. **Limited**: missing from at least one major engine. Ask before using it, or ship it as progressive
   enhancement with a working fallback.

The project's own support policy (browserslist, docs) overrides these tiers. Tiers move every few
months; check caniuse.com or webstatus.dev before relying on a Newly or Limited feature.

```css
/* fallback for every browser */
.tooltip { position: absolute; top: 100%; }

/* upgrade where supported */
@supports (anchor-name: --tip) {
  .trigger { anchor-name: --tip; }
  .tooltip { position: fixed; position-anchor: --tip; top: anchor(bottom); }
}
```

## Principles

1. **Native over JavaScript.** If CSS or HTML can do it (`<dialog>`, `popover`, `<details>`, scroll
   snap, `:has()`, scroll-driven animations), don't write JS for it.
2. **Logical over physical properties.** `margin-inline-start` over `margin-left`, so layouts work in
   any writing direction.
3. **Intrinsic over fixed breakpoints.** `clamp()`, `min()`, `max()`, container queries, and flex/grid
   auto-sizing let content drive layout.
4. **Custom properties over preprocessor variables.** They cascade and update at runtime.
5. **Cascade layers over specificity hacks.** Order the cascade with `@layer`, not `!important`.
6. **Progressive enhancement.** Gate Newly and Limited features behind `@supports` with a fallback.

## Index

Find the technique below, then read its entry in the linked reference file.

### Layout — [references/layout.md](references/layout.md)

| Technique | Status |
| --- | --- |
| CSS Logical Properties: RTL Layouts Without left and right | Widely |
| CSS Scroll Snap: scroll-snap-type and scroll-snap-align | Widely |
| CSS Sticky Header with position: sticky | Widely |
| CSS grid-template-areas: Named Grid Areas | Widely |
| CSS shape-outside: Wrap Text Around Shapes | Widely |
| Center a Div in CSS with place-items: center | Widely |
| Center a Div with Flexbox justify-content and align-items | Widely |
| Center with margin: auto in CSS Grid | Widely |
| Responsive Images in CSS with object-fit: cover | Widely |
| CSS gap Property for Flex and Grid Spacing | Widely |
| CSS Media Query Range Syntax (width < 768px) | Widely |
| CSS dvh, svh, lvh: Mobile Viewport Height Fix | Widely |
| Name-only @container queries without size conditions | Widely |
| Responsive Components with CSS Container Queries | Widely |
| CSS aspect-ratio Property (No Padding Hack) | Widely |
| CSS inset Shorthand for top, right, bottom, left | Widely |
| CSS scroll-margin: Anchor Offsets | Widely |
| CSS Subgrid: Align Nested Grids Without Duplicating Tracks | Widely |
| Scrollbar-Aware 100vw with scrollbar-gutter: stable | Widely |
| CSS zoom Property vs transform: scale() | Newly |
| Prevent Scrollbar Layout Shift: scrollbar-gutter: stable | Newly |
| CSS safe center: Overflow-safe Alignment | Newly |
| CSS abs() and sign(): Absolute values without JS | Newly |
| Style Scrollbars in CSS: scrollbar-color, scrollbar-width | Newly |
| Auto-Resize Textarea in CSS: field-sizing: content | Newly |
| CSS shape() Function: Responsive clip-path Shapes | Newly |
| CSS overflow-anchor: Scroll Anchoring | Newly |
| CSS display: contents: Grid Layout Without Wrappers | Limited |
| CSS overscroll-behavior: contain (No JavaScript) | Limited |
| CSS Hover Tooltips with popover=hint and interestfor | Limited |
| Fill Available Space in CSS with the stretch Keyword | Limited |
| CSS Anchor Positioning for Tooltips | Limited |
| Data-Driven CSS Layouts with Typed attr() | Limited |
| CSS-Only Carousel Navigation with scroll-marker | Limited |
| CSS device-posture: Foldable screen layouts | Limited |
| CSS corner-shape: Squircle, Scoop, and Notch Corners | Limited |
| CSS reading-flow: Tab order that matches the layout | Limited |
| CSS border-shape: True Non-Rectangular Elements | Limited |
| CSS Gap Decorations: row-rule and column-rule for Grid and Flex | Limited |
| CSS Grid Lanes: Masonry Layout Without JavaScript | Limited |
| Two-Axis Sticky: Sticky Row and Column in the Same Table | Limited |

### Selectors — [references/selectors.md](references/selectors.md)

| Technique | Status |
| --- | --- |
| CSS Floating Labels with :placeholder-shown | Widely |
| Group CSS Selectors with :is() and :where() | Widely |
| Low-Specificity CSS Reset with :where() | Widely |
| CSS :has() Selector: Select Parent by Child | Widely |
| CSS Focus Styles with :focus-visible | Widely |
| CSS :nth-child(n of selector): Target Nth Matching Element | Widely |
| CSS Custom Highlight API: ::highlight() Pseudo-Element | Newly |
| CSS @container style(): Variant Styles Without JavaScript | Newly |
| CSS Form Validation Styles with :user-invalid | Newly |
| CSS Scroll Spy with :target-current (No IntersectionObserver) | Limited |
| CSS :playing, :paused, :muted Pseudo-Classes for Media | Limited |

### Color — [references/color.md](references/color.md)

| Technique | Status |
| --- | --- |
| CSS Wide-Gamut Color: display-p3 and rec2020 | Widely |
| CSS color-mix() Function (No Sass Required) | Widely |
| OKLCH Color in CSS: Perceptually Uniform Colors | Widely |
| Frosted Glass Effect in CSS with backdrop-filter | Newly |
| CSS Relative Color Syntax: Lighten, Darken Without Sass | Newly |
| Dark Mode Colors in CSS with light-dark() | Newly |
| CSS contrast-color() for Readable Text | Newly |
| CSS accent-color for Checkboxes, Radios, and Range Inputs | Limited |

### Typography — [references/typography.md](references/typography.md)

| Technique | Status |
| --- | --- |
| Variable Fonts in CSS: One File, All Weights | Widely |
| Fluid Typography in CSS with clamp() | Widely |
| font-display: swap in CSS (Prevent Invisible Text) | Widely |
| CSS font-palette: Color fonts without extra files | Widely |
| CSS Type Scale with pow() | Widely |
| Balance Headlines in CSS with text-wrap: balance | Newly |
| Truncate Text to N Lines in CSS with line-clamp | Limited |
| CSS Drop Caps with the initial-letter Property | Limited |
| CSS text-wrap-style: pretty for Long-Form Paragraphs | Limited |
| CSS text-box-trim and text-box-edge for cap-height centering | Limited |
| Vertically Center Text in CSS with text-box-trim | Limited |
| CSS text-spacing-trim: Clean CJK and Quote Punctuation | Limited |
| Automatic CSS Type Scale with sibling-index() and pow() | Limited |

### Animation — [references/animation.md](references/animation.md)

| Technique | Status |
| --- | --- |
| CSS Motion Path Animation with offset-path | Widely |
| CSS prefers-reduced-motion Media Query | Widely |
| CSS Individual Transform Properties: translate, rotate, scale | Widely |
| Custom CSS Easing with linear() Timing Function | Widely |
| Responsive CSS clip-path with the shape() Function | Newly |
| CSS View Transitions API (No Framework) | Newly |
| Animate display: none in CSS (No JavaScript) | Newly |
| CSS Entry Animations with @starting-style | Newly |
| Animate `<details>` with ::details-content and interpolate-size | Newly |
| Staggered CSS Animations with sibling-index() | Newly |
| Scroll-Driven Animations in CSS with scroll-timeline | Limited |
| Animate height: auto in CSS with interpolate-size | Limited |
| CSS calc-size(): Math on auto and fit-content | Limited |
| CSS animation-trigger Property: Scroll-Triggered Animations | Limited |
| Element-Scoped View Transitions: Element.startViewTransition() | Limited |
| CSS Auto-Hiding Header with scroll-state(scrolled) | Limited |
| CSS scroll-state() Container Queries: :stuck and :snapped | Limited |
| CSS random() Function for Per-Element Random Values | Limited |

### HTML-native UI — [references/html.md](references/html.md)

| Technique | Status |
| --- | --- |
| CSS Accordion with details and summary (No JavaScript) | Widely |
| CSS Modal Dialog with the Native dialog Element | Widely |
| HTML inputmode and enterkeyhint for Mobile Keyboards | Widely |
| Lazy Load Images in HTML with loading="lazy" | Widely |
| HTML output Element for Live Form Output | Widely |
| CSS-Only Dropdown Menu with the Popover API | Newly |
| CSS Exclusive Accordion with the details name Attribute | Newly |
| CSS Modal Controls with commandfor and command Attributes | Newly |
| Customizable CSS Select with appearance: base-select | Limited |
| HTML datalist: Native Autocomplete (No JavaScript) | Limited |
| CSS Dialog Light Dismiss with closedby Attribute | Limited |

### Workflow, architecture, accessibility — [references/workflow.md](references/workflow.md)

| Technique | Status |
| --- | --- |
| CSS isolation: Prevent z-index Overflow | Widely |
| CSS Custom Properties for Theme Variables | Widely |
| CSS Feature Detection with @supports (No Modernizr) | Widely |
| Larger Touch Targets in CSS Without Changing Element Size | Widely |
| Control CSS Specificity with @layer (No !important) | Widely |
| Organizing CSS with cascade layers | Widely |
| CSS Dark Mode with color-scheme: light dark | Widely |
| CSS forced-colors media query for Windows High Contrast | Widely |
| Native CSS Nesting (No Sass or Less) | Widely |
| CSS Lazy Rendering with content-visibility: auto | Newly |
| CSS @property for Typed Custom Properties | Newly |
| CSS @scope: Scoped Styles Without BEM | Newly |
| CSS attr() with Type: Typed HTML Attribute Values | Limited |
| CSS Range Style Queries: style(--progress > 50%) | Limited |
| CSS @function for Reusable Logic (No Sass Mixins) | Limited |
| CSS if() Function for Inline Conditional Styles | Limited |
