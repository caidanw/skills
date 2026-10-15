# Layout

Old-vs-modern patterns from [modern-css.com](https://modern-css.com/), snapshot October 2026. Status is the Baseline tier (Widely / Newly / Limited). Recheck Limited features on caniuse.com or webstatus.dev before relying on them.

## CSS Logical Properties: RTL Layouts Without left and right

`Widely available · since 2021` · [source](https://modern-css.com/direction-aware-layouts-without-left-and-right/)

You used margin-left, padding-right, border-left, then overrode everything for RTL with [dir="rtl"]. Logical properties are direction-aware so one set of rules works for both.

Modern:

```css
.box {
  margin-inline-start: 1rem;
  padding-inline-end: 1rem;
  border-block-start: 1px solid;
}
```

Replaces:

```css
.box {
  margin-left: 1rem;
  padding-right: 1rem;
}

[dir="rtl"] .box {
  margin-left: 0;
  margin-right: 1rem;
}
```

## CSS Scroll Snap: scroll-snap-type and scroll-snap-align

`Widely available · since 2020` · [source](https://modern-css.com/scroll-snapping-without-a-carousel-library/)

Carousels used to mean Slick, Swiper, or custom scroll math. CSS scroll snap gives you card-by-card or full-width snapping with a few properties.

Modern:

```css
.carousel {
  scroll-snap-type: x mandatory;
  overflow-x: auto;
  display: flex;
  gap: 1rem;
}

.carousel > * {
  scroll-snap-align: start;
}
```

Replaces:

```css
// carousel.js + Slick/Swiper
import Swiper from 'swiper';
new Swiper('.carousel', {
  slidesPerView: 1,
  loop: true
});
```

## CSS Sticky Header with position: sticky

`Widely available · since 2019` · [source](https://modern-css.com/sticky-headers-without-javascript-scroll-listeners/)

The old way used JavaScript scroll events and getBoundingClientRect to toggle a class. Sticky positioning does it in one property.

Modern:

```css
.header {
  position: sticky;
  top: 0;
}
```

Replaces:

```css
// JavaScript: scroll listener
window.addEventListener('scroll', () => {
  const rect = header.getBoundingClientRect();
  if (rect.top <= 0)
    header.classList.add('fixed');
  else
    header.classList.remove('fixed');
});

.header.fixed {
  position: fixed;
  top: 0;
}
```

## CSS grid-template-areas: Named Grid Areas

`Widely available · since 2017` · [source](https://modern-css.com/naming-grid-areas-without-line-numbers/)

The old way was floats with clearfix and margin math, or grid with line numbers. Template areas let you name regions like header, sidebar, main, and drop them in place.

Modern:

```css
.layout {
  display: grid;
  grid-template-areas:    "header header"    "sidebar main"    "footer footer";
}

.header {
  grid-area: header;
}

.sidebar {
  grid-area: sidebar;
}
```

Replaces:

```css
.header {
  grid-column: 1 / -1;
}

.sidebar {
  grid-column: 1;
  grid-row: 2;
}

.main {
  grid-column: 2;
  grid-row: 2;
}

.footer {
  grid-column: 1 / -1;
  grid-row: 3;
}
```

## CSS shape-outside: Wrap Text Around Shapes

`Widely available · since 2020` · [source](https://modern-css.com/css-shape-outside/)

A floated circle still wraps like a box. border-radius only changes the paint. Dummy floated spans used to stair-step the text. shape-outside sets the wrap contour, so lines follow the shape.

Modern:

```css
.avatar {
  float: left;
  shape-outside: circle(50%);
  shape-margin: 1rem;
}
/* wrap follows the circle, not the box */
```

Replaces:

```css
.avatar {
  float: left;
  width: 160px;
  height: 160px;
  border-radius: 50%;
}
/* looks round, wrap is still a rectangle */
```

## Center a Div in CSS with place-items: center

`Widely available · since 2020` · [source](https://modern-css.com/centering-elements-without-the-transform-hack/)

The old absolute + transform centering trick took 5 declarations across 2 selectors. Grid does it in 2 properties on the parent.

Modern:

```css
.parent {
  display: grid;
  place-items: center;
}
```

Replaces:

```css
.parent {
  position: relative;
}

.child {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}
```

## Center a Div with Flexbox justify-content and align-items

`Widely available · since 2015` · [source](https://modern-css.com/centering-elements-with-flexbox/)

Flexbox centering uses justify-content and align-items instead of place-items. It's often preferred for dynamic content because flex items don't shrink below their content size when space is tight.

Modern:

```css
.parent {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
}
/* centered on both axes */
```

Replaces:

```css
/* Old approach: absolute positioning + transform */
.parent {
  position: relative;
  height: 100%;
}

.child {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}
/* 5 declarations, 2 selectors, breaks on overflow */
```

## Center with margin: auto in CSS Grid

`Widely available · since 2017` · [source](https://modern-css.com/centering-elements-with-auto-margins/)

In CSS Grid, margin: auto centers items in their grid area by distributing space evenly on both sides. It's less code than place-items when you want horizontal and vertical centering with different semantics.

Modern:

```css
.parent {
  display: grid;
  height: 100%;
}

.child {
  margin: auto;
}
/* margin: auto distributes space evenly */
```

Replaces:

```css
/* Old approach: absolute positioning + transform */
.parent {
  position: relative;
  height: 100%;
}

.child {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}
/* brittle, removes from flow */
```

## Responsive Images in CSS with object-fit: cover

`Widely available · since 2020` · [source](https://modern-css.com/responsive-images-without-background-image-hack/)

Cropped responsive images were done with background-image and background-size: cover on a div. No semantic img element, no alt text, and no native lazy loading. object-fit brings the same cropping behavior to real img elements.

Modern:

```html
<img src="photo.jpg" alt="..." loading="lazy">img {
  object-fit: cover;
  width: 100%;
  height: 200px;
}
```

Replaces:

```html
<!-- div instead of img: no alt, not semantic --><div class="card-image"></div>.card-image {
  background-image: url(photo.jpg);
  background-size: cover;
  background-position: center;
}
```

## CSS gap Property for Flex and Grid Spacing

`Widely available · since 2021` · [source](https://modern-css.com/spacing-elements-without-margin-hacks/)

The old way used margins on children and negative margin on the container, or :last-child to cancel the last margin. Gap handles it on the parent.

Modern:

```css
.grid {
  display: flex;
  gap: 16px;
}
```

Replaces:

```css
.grid {
  display: flex;
}

.grid > * {
  margin-right: 16px;
}

.grid > *:last-child {
  margin-right: 0;
}
```

## CSS Media Query Range Syntax (width < 768px)

`Widely available · since 2023` · [source](https://modern-css.com/media-query-ranges-without-min-max-syntax/)

Defining a range of viewport widths required two separate media features: min-width and max-width. Media Queries Level 4 introduces range syntax using standard comparison operators, making ranges possible in a single expression.

Modern:

```css
@media (600px <= width <= 1200px) {
  .card {
    grid-template-columns: 1fr 1fr;
  }
}
```

Replaces:

```css
@media (min-width: 600px) and (max-width: 1200px) {
  .card {
    grid-template-columns: 1fr 1fr;
  }
}
```

## CSS dvh, svh, lvh: Mobile Viewport Height Fix

`Widely available · since 2022` · [source](https://modern-css.com/mobile-viewport-height-without-100vh-hack/)

100vh on mobile includes the browser address bar and navigation controls even when they are visible, causing full-height elements to overflow. Dynamic viewport units (dvh, svh, lvh) adapt to the actual visible area.

Modern:

```css
.hero {
  height: 100dvh;
}
```

Replaces:

```css
.hero {
  height: 100vh;
}
```

## Name-only @container queries without size conditions

`Widely available · since 2023` · [source](https://modern-css.com/container-queries-without-size-conditions/)

Until recently, @container always needed a size condition. To target a named context without caring about size, you wrote @container sidebar (width > 0). Browsers now accept the name on its own.

Modern:

```css
.sidebar {
  container-name: sidebar;
}

.card {
  display: grid;
}

@container sidebar {
  .card {
    grid-auto-flow: column;
  }
}
/* no dummy size condition */
```

Replaces:

```css
.sidebar {
  container-name: sidebar;
}

.card {
  display: grid;
}
/* size condition required even when you only care about the name */
@container sidebar (width > 0) {
  .card {
    grid-auto-flow: column;
  }
}
```

> Name-only @container queries shipped across all three engines in April 2026 (Chrome 149, Safari 26.4, Firefox 148). The broader @container feature has been Baseline widely available since 2023, so older browsers will simply skip the rule.

## Responsive Components with CSS Container Queries

`Widely available · since 2023` · [source](https://modern-css.com/responsive-components-without-media-queries/)

Media queries respond to the viewport. Components live in containers: sidebars, modals, grids. @container lets them respond to their actual available space.

Modern:

```css
.wrapper {
  container-type: inline-size;
}

.card {
  grid-template-columns: 1fr;
}

@container (width > 400px) {
  .card {
    grid-template-columns: auto 1fr;
  }
}
```

Replaces:

```css
.card {
  display: grid;
  grid-template-columns: 1fr;
}

@media (min-width: 768px) {
  .card {
    grid-template-columns: auto 1fr;
  }
}
```

## CSS aspect-ratio Property (No Padding Hack)

`Widely available · since 2021` · [source](https://modern-css.com/aspect-ratios-without-the-padding-hack/)

The old trick used padding-top: 56.25% and nested absolute positioning. aspect-ratio does it in one declaration.

Modern:

```css
.video-wrapper {
  aspect-ratio: 16 / 9;
}
```

Replaces:

```css
.video-wrapper {
  position: relative;
  padding-top: 56.25%;
}

.video-wrapper > * {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}
```

## CSS inset Shorthand for top, right, bottom, left

`Widely available · since 2021` · [source](https://modern-css.com/positioning-shorthand-without-four-properties/)

The old way was to set top, right, bottom, and left one by one for full-bleed or overlay layouts. inset gives you one property that sets all four.

Modern:

```css
.overlay {
  position: absolute;
  inset: 0;
}
```

Replaces:

```css
.overlay {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
}
```

## CSS scroll-margin: Anchor Offsets

`Widely available · since 2020` · [source](https://modern-css.com/css-scroll-margin/)

Smooth scrolling to an id still parked the heading under a sticky header, so people measured the header in JavaScript and called scrollTo. scroll-margin-block-start tells the browser to stop short of the target.

Modern:

```css
html {
  scroll-behavior: smooth;
}
@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }
}
[id] {
  scroll-margin-block-start: 5rem;
}
/* no header measurement, no click handler */
```

Replaces:

```js
document.querySelectorAll('a[href^="#"]').forEach((link) => {
  link.addEventListener('click', (event) => {
    const id = link.getAttribute('href').slice(1);
    const target = document.getElementById(id);
    if (!target) return;
    event.preventDefault();
    const top = target.getBoundingClientRect().top + window.scrollY - header.offsetHeight;
    window.scrollTo({ top, behavior: 'smooth' });
  });
});
```

## CSS Subgrid: Align Nested Grids Without Duplicating Tracks

`Widely available · since 2023` · [source](https://modern-css.com/aligning-nested-grids-without-duplicating-tracks/)

Inner grids used to repeat the parent's column definitions to align. That was fragile and got out of sync. Subgrid inherits the parent's tracks so everything lines up.

Modern:

```css
.parent {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
}

.child-grid {
  display: grid;
  grid-template-columns: subgrid;
}
```

Replaces:

```css
.parent {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
}

.child-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
}
```

## Scrollbar-Aware 100vw with scrollbar-gutter: stable

`Widely available · since 2017` · [source](https://modern-css.com/full-width-without-horizontal-scrollbar-overflow/)

Using 100vw on a desktop with a classic scrollbar always overflowed the page horizontally. The fix used to be JavaScript that measured the scrollbar and exposed its width as a custom property. CSS now solves this when the root commits to a stable scrollbar gutter.

Modern:

```css
html {  scrollbar-gutter: stable; 
}

.full-bleed {
  width: 100vw;
  margin-inline: calc(50% - 50vw);
}
```

Replaces:

```js
const sbw = window      .innerWidth - document   .documentElement.clientWidth;

document.documentElement     .style.setProperty(           '--scrollbar', sbw + 'px');

window.addEventListener( 'resize', () => {
  const w = window     .innerWidth - document   .documentElement.clientWidth;
  document.documentElement   .style.setProperty(         '--scrollbar', w + 'px');
});
```

## CSS zoom Property vs transform: scale()

`Newly available · since 2024` · [source](https://modern-css.com/scaling-elements-without-transform-hacks/)

transform: scale() shrinks an element visually but keeps its original layout space, requiring negative margins to collapse the gap. zoom scales the element and its layout footprint together. No hacks needed.

Modern:

```css
.thumbnail {
  zoom: 0.5;
}
```

Replaces:

```css
.thumbnail {
  transform: scale(0.5);
  transform-origin: top left;
  margin-bottom: -50%;
  margin-right: -50%;
}
```

## Prevent Scrollbar Layout Shift: scrollbar-gutter: stable

`Newly available · since 2024` · [source](https://modern-css.com/preventing-layout-shift-from-scrollbar/)

When content grows tall enough to scroll, the scrollbar appears and narrows the layout, causing a visible jump. The old fixes were overflow-y: scroll (always shows the bar) or padding-right matching the scrollbar width. scrollbar-gutter: stable reserves the space upfront.

Modern:

```css
body {
  scrollbar-gutter: stable;
}
```

Replaces:

```css
/* Option 1: always show scrollbar (ugly on short pages) */
body {
  overflow-y: scroll;
}
/* Option 2: hardcode scrollbar width (fragile) */
body {
  padding-right: 17px;
}
/* scrollbar width varies by OS and browser */
```

## CSS safe center: Overflow-safe Alignment

`Newly available · since 2024` · [source](https://modern-css.com/css-safe-center/)

A centered nav or chip row that is wider than its container overflows both sides. The start edge sits past the scrollport, so you cannot scroll to it. A media query used to switch to flex-start. justify-content: safe center falls back to start only when centering would overflow.

Modern:

```css
.nav {
  display: flex;
  justify-content: safe center;
}
/* falls back to start when centering would overflow */
```

Replaces:

```css
.nav {
  display: flex;
  justify-content: center;
}
@media (max-width: 600px) {
  .nav {
    justify-content: flex-start;
  }
}
/* drops centering at a guessed breakpoint */
```

## CSS abs() and sign(): Absolute values without JS

`Newly available · since 2025` · [source](https://modern-css.com/css-abs-and-sign/)

Negative custom properties used to need JavaScript Math.abs or a Sass helper before you could use them as lengths. abs() and sign() do that math in CSS, so spacing and offsets stay positive and direction-aware.

Modern:

```css
.panel {
  --offset: -1.5rem;
  margin-inline-start: abs(var(--offset));
  translate: calc(1rem * sign(var(--offset))) 0;
}
/* positive length + direction from one variable */
```

Replaces:

```css
.panel {
  --offset: -1.5rem;
  /* max() fallback for abs, or JS Math.abs before setting the var */
  margin-inline-start: max(var(--offset), -1 * var(--offset));
}
/* JS: el.style.setProperty('--offset', Math.abs(raw) + 'rem'); */
```

## Style Scrollbars in CSS: scrollbar-color, scrollbar-width

`Newly available · since 2025` · [source](https://modern-css.com/scrollbar-styling-without-webkit-pseudo-elements/)

Styling scrollbars required ::-webkit-scrollbar, ::-webkit-scrollbar-track, and ::-webkit-scrollbar-thumb. Non-standard WebKit-only pseudo-elements that Firefox never supported. scrollbar-color and scrollbar-width are the standard two-property replacement.

Modern:

```css
* {
  scrollbar-width: thin;
  scrollbar-color: #888 transparent;
}
```

Replaces:

```css
/* Chrome + Safari only — Firefox ignores all of this */
::-webkit-scrollbar {
  width: 8px;
}

::-webkit-scrollbar-track {
  background: #f1f1f1;
}

::-webkit-scrollbar-thumb {
  background: #888;
}

::-webkit-scrollbar-thumb:hover {
  background: #555;
}
```

## Auto-Resize Textarea in CSS: field-sizing: content

`Newly available · since 2026` · [source](https://modern-css.com/auto-growing-textarea-without-javascript/)

Making a textarea grow as the user types required a JS event listener that reset height to auto then set it to scrollHeight on every keystroke. field-sizing: content makes the field size itself to its content.

Modern:

```css
textarea {
  field-sizing: content;
  min-height: 3lh;
}
```

Replaces:

```css
textarea {
  overflow: hidden;
}
// JS: reset height then set to scrollHeight on every inputel.addEventListener('input', () => {   el.style.height = 'auto';   el.style.height = el.scrollHeight + 'px'; });
```

## CSS shape() Function: Responsive clip-path Shapes

`Newly available · since 2026` · [source](https://modern-css.com/path-shapes-without-svg-clip-paths/)

Creating non-rectangular clip paths used to mean SVG `<clipPath>` elements or path() with fixed pixel coordinates that break as soon as the element resizes. shape() brings path-style drawing to CSS using percentage units and responsive coordinates.

Modern:

```css
.hero {
  clip-path: shape(     from 0% 0%,    line to 100% 0%,    line to 100% 80%,    curve to 0% 80% via 50% 105%,    close   );
}
```

Replaces:

```css
/* path() uses absolute px — not responsive */
.hero {
  clip-path: path(     "M 0 0 L 800 0 L 800 360 /* */
  Q 400 420 0 360 Z" /* */
  );
  /* Breaks on resize */
}
```

## CSS overflow-anchor: Scroll Anchoring

`Newly available · since 2026` · [source](https://modern-css.com/css-overflow-anchor/)

Loading older messages used to mean saving scrollHeight, prepending the nodes, then adding the difference back to scrollTop. overflow-anchor lets the browser hold the words you were reading in place.

Modern:

```css
.log {
  overflow-y: auto;
  overflow-anchor: auto;
}
/* browser holds the visible message when older ones prepend */
```

Replaces:

```js
function prependMessage(log, node) {
  const prev = log.scrollHeight;
  log.prepend(node);
  log.scrollTop += log.scrollHeight - prev;
}
```

> Baseline Newly available since September 2026, when Safari 27 and iOS Safari 27 shipped. Chrome 56, Firefox 66, and Edge 79 already had it. Older Safari still jumps when messages are prepended, so keep the scrollHeight delta behind @supports not (overflow-anchor: auto) if those versions matter.

## CSS display: contents: Grid Layout Without Wrappers

`Limited availability` · [source](https://modern-css.com/grid-layout-without-extra-wrappers/)

Grid and flex layouts only apply to direct children. When markup wraps items in extra elements, the layout breaks. display: contents removes a wrapper from the layout tree so its children behave as if the wrapper was never there.

Modern:

```css
.wrapper {
  display: contents;
}
/* wrapper disappears from layout; children join parent grid */
```

Replaces:

```css
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
}

.wrapper {  display: grid;   grid-template-columns: subgrid;   grid-column: span 3; 
}
/* no native way to flatten — restructure HTML or repeat grid on wrapper */
```

## CSS overscroll-behavior: contain (No JavaScript)

`Limited availability` · [source](https://modern-css.com/preventing-scroll-chaining-without-javascript/)

When a scrollable element inside a modal reached its end, scroll would chain to the page behind it. The fix was a JS wheel event listener calling e.preventDefault(). overscroll-behavior: contain stops that natively.

Modern:

```css
.modal-content {
  overflow-y: auto;
  overscroll-behavior: contain;
}
```

Replaces:

```css
.modal-content {
  overflow-y: auto;
}// JS: prevent scroll chaining on wheel and touch modal.addEventListener('wheel', (e) => {   e.preventDefault(); }, { passive: false }); // also needed for touch: touchmove listener
```

## CSS Hover Tooltips with popover=hint and interestfor

`Limited availability` · [source](https://modern-css.com/hover-tooltips-without-javascript-events/)

Tooltips required JavaScript mouseenter/mouseleave listeners, focus handling, and manual positioning. Now popover=hint with the interestfor attribute gives you declarative, accessible hover UI.

Modern:

```html
<button interestfor="tip">
  Hover me
</button>
<div id="tip" popover=hint>
  Tooltip text
</div>
```

Replaces:

```css
/* JS: manage hover, focus, and position */
btn.addEventListener('mouseenter', () => {
  tip.hidden = false;
  positionTooltip(btn, tip);
}

);
btn.addEventListener('mouseleave', () => {
  tip.hidden = true;
}

);
btn.addEventListener('focus', /* … */
);
btn.addEventListener('blur', /* … */
);
```

## Fill Available Space in CSS with the stretch Keyword

`Limited availability` · [source](https://modern-css.com/filling-available-space-without-calc-workarounds/)

Making an element fill its container while keeping margins meant calc(100% - left - right) or risking overflow with width: 100%. The stretch keyword fills available space while respecting margins automatically.

Modern:

```css
.full {
  width: stretch;
}
```

Replaces:

```css
.full {
  width: 100%;
  width: calc(100% - 40px);
}
```

## CSS Anchor Positioning for Tooltips

`Limited availability` · [source](https://modern-css.com/tooltip-positioning-without-javascript/)

The old way relied on JS libraries like Popper.js or Floating UI to compute tooltip position. CSS anchor positioning ties the tooltip to its trigger with anchor-name and position-anchor.

Modern:

```css
.trigger {
  anchor-name: --tip;
}

.tooltip {
  position-anchor: --tip;
  top: anchor(bottom);
}
```

Replaces:

```css
/* JS: getBoundingClientRect for trigger + tooltip,   compute top/left, handle scroll/resize */
.tooltip {
  position: fixed;
  top: var(--computed-top);
  left: var(--computed-left);
}
```

## Data-Driven CSS Layouts with Typed attr()

`Limited availability` · [source](https://modern-css.com/attr-driven-layouts-without-js-charts/)

Small dashboards often pull in a charting library just to draw a few bars. Typed attr() lets CSS read numbers from data-* attributes and size blocks directly so you can skip the JavaScript chart layer.

Modern:

```css
.bar {
  block-size: 1.5rem;
  background: var(--accent);
  inline-size: attr(data-pct percentage);
}
```

Replaces:

```css
.bar {
  block-size: 1.5rem;
  inline-size: calc(1% * var(--pct));
  background: var(--accent);
}
/* --pct set in JS per element */
bars.forEach(bar => {
  bar.style.setProperty('--pct', bar.dataset.pct);
});
```

> Note: The attr() function can be used with any CSS property, but support for using attr() with typed values on properties other than content is experimental. The pattern on this page should be treated as progressive enhancement.

## CSS-Only Carousel Navigation with scroll-marker

`Limited availability` · [source](https://modern-css.com/carousel-navigation-without-a-javascript-library/)

Carousels used to need libraries like Swiper.js or Slick for navigation buttons and dot indicators. CSS scroll-button and scroll-marker pseudo-elements give you native, accessible carousel UI.

Modern:

```css
.carousel::scroll-button(left) {
  content: "⬅" / "Scroll left";
}

.carousel::scroll-button(right) {
  content: "➡" / "Scroll right";
}

.carousel {
  scroll-marker-group: after;
}

.carousel li::scroll-marker {
  content: '';
  width: 10px;
  height: 10px;
  border-radius: 50%;
}
```

Replaces:

```css
/* JS: Swiper.js carousel with nav + dots */
import Swiper from 'swiper';
new Swiper('.carousel', {
  navigation: {
    nextEl: '.next',    prevEl: '.prev',
  }

  ,  pagination: {
    el: '.dots'
  }

  ,
}

);
/* + custom CSS for buttons, dots, states */
```

## CSS device-posture: Foldable screen layouts

`Limited availability` · [source](https://modern-css.com/css-device-posture/)

Foldable layouts used to mean guessing from UA strings or viewport hacks. The device-posture media feature reports continuous or folded, so you can add a reading gutter only when the screen is actually folded.

Modern:

```css
@media (device-posture: folded) and (orientation: landscape) {
  .list-view {
    margin-inline-end: 60px;
  }
}

@media (device-posture: folded) and (orientation: portrait) {
  .list-view {
    margin-block-end: 60px;
  }
}
/* hinge gutter only when the screen is folded */
```

Replaces:

```css
/* guess foldables from UA or a magic viewport width */
@media (max-width: 840px) {
  .list-view {
    margin-inline-end: 60px;
  }
}
/* JS: if (/Foldable|Duo|Pixel Fold/i.test(navigator.userAgent)) { ... } */
```

> device-posture ships in Chrome and Edge 132+. Firefox and Safari have no support yet. Folded styles are progressive enhancement on top of a layout that already works when the feature is missing.

## CSS corner-shape: Squircle, Scoop, and Notch Corners

`Limited availability` · [source](https://modern-css.com/corner-shapes-beyond-rounded-borders/)

Non-circular corner shapes like squircles, scoops, and notches used to require clip-path polygon hacks or SVG masks. Now corner-shape provides named corner styles natively.

Modern:

```css
.card {
  border-radius: 2em;
  corner-shape: squircle;
}
```

Replaces:

```css
.card {
  clip-path: polygon(     0% 10%,    2% 4%,    4% 2%,    10% 0%,    /* ...16 more points */
  );
}
/* Or use an SVG mask image */
```

> Chrome and Edge 139 ship corner-shape. Firefox and Safari don't. Unsupported browsers ignore the property and keep the border-radius arc.

## CSS reading-flow: Tab order that matches the layout

`Limited availability` · [source](https://modern-css.com/css-reading-flow/)

Flex reverse and grid areas often put focusable items in a different order than the DOM. reading-flow makes tab and speech order follow the visual layout without shuffling markup or abusing tabindex.

Modern:

```css
.nav {
  display: flex;
  flex-direction: row-reverse;
  reading-flow: flex-visual;
  gap: 1rem;
}
/* tab order follows what you see, not DOM reverse */
```

Replaces:

```css
/* visual order via flex reverse, tab order fixed by reshuffling markup */
.nav {
  display: flex;
  gap: 1rem;
}
/* HTML rewritten per breakpoint, or tabindex="1/2/3" on each link */
```

> reading-flow ships in Chrome and Edge 137+. Firefox and Safari have no support yet. Keep DOM source order logical so unsupported browsers still get a usable tab path.

## CSS border-shape: True Non-Rectangular Elements

`Limited availability` · [source](https://modern-css.com/css-border-shape/)

clip-path masks an element into a shape but the underlying box stays rectangular. Shadows, borders, and outlines ignore the mask. border-shape redefines the geometry itself, so every visual property follows the shape.

Modern:

```css
.tooltip {
  border-shape: shape(from 0 0, hline 100%, line to 50% calc(100% + 12px), line to 0 100%, close);
  background: var(--accent);
  padding: 1rem;
}
/* the box itself is the shape, no clip-path needed
```

Replaces:

```css
.tooltip {
  background: var(--accent);
  padding: 1rem;
  clip-path: polygon(0 0, 100% 0, 100% 100%, 50% calc(100% + 12px), 0 100%);
}
/* clip-path masks the visual but the box is still rectangular for layout, shadows, and outlines
```

> border-shape is not yet shipping in any release browser. As of 2026 it is only available in Chrome Canary 146+ behind the chrome://flags/#enable-experimental-web-platform-features flag, and the spec is still a W3C Working Draft. The syntax may change before it stabilizes. Use clip-path with the same coordinates as a fallback for now, and revisit this snippet once the feature reaches Chrome stable.

## CSS Gap Decorations: row-rule and column-rule for Grid and Flex

`Limited availability` · [source](https://modern-css.com/grid-dividers-without-borders-or-pseudo-elements/)

Putting lines between grid or flex items always meant putting borders on the items themselves, then stripping the border off the last column and last row with nth-child selectors. Gap decorations let the container draw the rules instead.

Modern:

```css
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;  column-rule: 1px solid var(--border);   row-rule: 1px solid var(--border); 
}
```

Replaces:

```css
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
}

.grid > * {
  border-inline-end: 1px solid #ddd;
  border-block-end: 1px solid #ddd;
}

.grid > :nth-child(3n) {
  border-inline-end: 0;
}

.grid > :nth-last-child(-n + 3) {
  border-block-end: 0;
}
```

## CSS Grid Lanes: Masonry Layout Without JavaScript

`Limited availability` · [source](https://modern-css.com/css-grid-lanes/)

Uneven cards and images used to mean Masonry.js measuring every item, or CSS columns that read top to bottom. display: grid-lanes packs each item into the shortest lane in CSS.

Modern:

```css
.gallery {
  display: grid;  display: grid-lanes; 
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 16px;
}
/* no Masonry.js, no column-count */
```

Replaces:

```css
import Masonry from 'masonry-layout';
new Masonry('.gallery', {
  itemSelector: '.item',
  columnWidth: 250,
  gutter: 16
});
```

> Only Safari 26.4 and iOS Safari 26.4 ship display: grid-lanes on by default. Chrome, Edge, and Firefox have implementations behind a flag. A display: grid declaration above display: grid-lanes keeps a regular grid in browsers that ignore the new value.

## Two-Axis Sticky: Sticky Row and Column in the Same Table

`Limited availability` · [source](https://modern-css.com/sticky-rows-and-columns-without-javascript/)

Locking both the first column and the header row of a wide table used to require JavaScript scroll syncing or a heavy table library. A change to position: sticky lets it track different scrollers on each axis when the wrapping element only scrolls on one of them.

Modern:

```css
.table-wrap {
  overflow-x: auto;  overflow-y: clip; 
}

th:first-child,
td:first-child {
  position: sticky;
  left: 0;
}

thead th {
  position: sticky;
  top: 0;
}
```

Replaces:

```js
const wrap = document   .querySelector('.table-wrap');
const head = document   .querySelector('thead');

window.addEventListener( 'scroll', () => {
  const r = wrap         .getBoundingClientRect();
  head.style.transform =       `translateY(${
    Math.max(0,            -r.top)}px)`;
});

wrap.addEventListener(   'scroll', () => {
  document.querySelectorAll(    '.first-col')      .forEach(el => {
    el.style.transform =       `translateX(${wrap.scrollLeft}px)`;
  });
});
```
