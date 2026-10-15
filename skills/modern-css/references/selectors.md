# Selectors

Old-vs-modern patterns from [modern-css.com](https://modern-css.com/), snapshot October 2026. Status is the Baseline tier (Widely / Newly / Limited). Recheck Limited features on caniuse.com or webstatus.dev before relying on them.

## CSS Floating Labels with :placeholder-shown

`Widely available · since 2020` · [source](https://modern-css.com/floating-labels-without-javascript/)

Floating labels used to need JavaScript. Listen for input events, toggle a .filled class, style from that class. :placeholder-shown tracks empty state for you. Flip it with :not() and the label floats once there is content.

Modern:

```css
input:not(:placeholder-shown) + label,
input:focus + label {
  translate: 0 -1.4rem;
  font-size: .75rem;
}
/* no .filled class, no JS */
```

Replaces:

```css
/* .filled class toggled by JS on every keystroke */
.field.filled label,
.field input:focus + label {
  translate: 0 -1.4rem;
  font-size: .75rem;
}// JS: toggle .filled on input input.addEventListener('input', () => {   input.closest('.field').classList.toggle('filled', input.value.length > 0); });
```

## Group CSS Selectors with :is() and :where()

`Widely available · since 2021` · [source](https://modern-css.com/grouping-selectors-without-repetition/)

Repeating .card h1, .card h2, .card h3 is verbose. :is(h1, h2, h3, h4) under .card does the same in one rule.

Modern:

```css
.card :is(h1, h2, h3, h4) {
  margin-bottom: 0.5em;
}
```

Replaces:

```css
.card h1, .card h2, .card h3, .card h4 {
  margin-bottom: 0.5em;
}// Same prefix repeated for every selector
```

## Low-Specificity CSS Reset with :where()

`Widely available · since 2021` · [source](https://modern-css.com/low-specificity-resets-without-complicated-selectors/)

Resets used verbose low-specificity tricks, or you fought them later with higher specificity. :where() has zero specificity so it never wins over your component styles.

Modern:

```css
:where(ul, ol) {
  margin: 0;
  padding-inline-start: 1.5rem;
}
/* Specificity 0. .list { padding: 0 } wins. */
```

Replaces:

```css
ul, ol {
  margin: 0;
  padding-left: 1.5rem;
}
/* Specificity (0,0,2). Component .list { padding: 0 } loses. */
```

## CSS :has() Selector: Select Parent by Child

`Widely available · since 2023` · [source](https://modern-css.com/selecting-parent-elements-without-javascript/)

Selecting a parent based on its children used to require JavaScript. :has() handles it in pure CSS, no event listeners needed.

Modern:

```css
.form-group:has(input:invalid) {
  border-color: red;
  background: #fff0f0;
}
```

Replaces:

```css
// Watch for changes, find parent
document.querySelectorAll('input')
  .forEach(input => {
    input.addEventListener('invalid', () => {
      input.closest('.form-group')
        .classList.add('has-error');
    });
  });
```

## CSS Focus Styles with :focus-visible

`Widely available · since 2022` · [source](https://modern-css.com/focus-styles-without-annoying-mouse-users/)

:focus shows an outline on every click, which looks wrong for mouse users. :focus-visible shows it only when the browser expects keyboard focus.

Modern:

```css
button:focus-visible {
  outline: 2px solid var(--focus-color);
}
```

Replaces:

```css
button:focus {
  outline: 2px solid blue;
}// Outline appears on mouse click. Often removed with outline: none.
```

## CSS :nth-child(n of selector): Target Nth Matching Element

`Widely available · since 2023` · [source](https://modern-css.com/nth-child-without-counting-siblings/)

:nth-child() counts all siblings by default, so mixed content breaks the expected pattern. The of selector syntax limits the count to only matching elements, giving reliable nth patterns regardless of what else is in the container.

Modern:

```css
.item:nth-child(2n of .featured) {
  background: var(--accent);
}
/* counts only .featured items; other siblings don't affect the pattern */
```

Replaces:

```css
.item:nth-child(2n) {  background: var(--accent); 
}
/* counts ALL siblings — breaks when non-.featured items are mixed in */
// JS: items.forEach((el, i) => { if (el.classList.contains('featured') && i % 2 === 0) el.classList.add('nth-even') });
```

## CSS Custom Highlight API: ::highlight() Pseudo-Element

`Newly available · since 2025` · [source](https://modern-css.com/text-highlighting-without-dom-manipulation/)

Highlighting arbitrary text used to mean mutating the DOM: wrapping ranges in `<mark>` elements via innerHTML.replace() or surroundContents(). The CSS Custom Highlight API lets you style ranges directly in CSS with no DOM changes.

Modern:

```css
/* CSS */
::highlight(search) {
  background: yellow;
}
/* JS — no DOM changes */
const range = new Range();
range.setStart(node, startOffset);
range.setEnd(node, endOffset);
CSS.highlights.set(   'search', new Highlight(range));
```

Replaces:

```js
function highlight(el, term) {
  el.innerHTML = el.innerHTML    .replace(       new RegExp(term, 'gi'),       '<mark>$&</mark>'     );
}
```

## CSS @container style(): Variant Styles Without JavaScript

`Newly available · since 2026` · [source](https://modern-css.com/container-style-queries/)

Variant styling used to mean JavaScript reading a data attribute, then adding a class like .card--primary so CSS could match it. @container style() lets the CSS respond to a custom property directly, no script involved.

Modern:

```css
@property --variant {
  syntax: "<custom-ident>";
  initial-value: default;
  inherits: true;
}

.card-wrap {
  container-name: card;
}

@container card style(--variant: primary) {
  .card {
    background: oklch(0.55 0.2 260);
    color: #fff;
  }
}

@container card style(--variant: danger) {
  .card {
    background: oklch(0.55 0.2 30);
    color: #fff;
  }
}
/* no JS, no class toggling */
```

Replaces:

```css
.card--primary {
  background: oklch(0.55 0.2 260);
  color: #fff;
}

.card--danger {
  background: oklch(0.55 0.2 30);
  color: #fff;
}
// JS: el.querySelectorAll('.card').forEach(c => c.classList.add('card--' + el.dataset.variant));
```

> Style queries for custom properties became Baseline Newly Available in May 2026 when Firefox 151 shipped. Chrome and Edge have supported them since version 111 (March 2023), Safari since version 18 (September 2024). This snippet uses custom property queries only. Style queries on regular CSS properties (like font-weight or color) are not yet supported in any browser.

## CSS Form Validation Styles with :user-invalid

`Newly available · since 2023` · [source](https://modern-css.com/form-validation-styles-without-javascript/)

:invalid fires as soon as the page loads, marking empty required fields as errors before anyone types. The workaround was JS adding a .touched class after blur. :user-invalid only activates after the user has interacted with the field.

Modern:

```css
input:user-invalid {
  border-color: red;
}

input:user-valid {
  border-color: green;
}
/* no JS, no .touched class */
```

Replaces:

```css
/* only style after .touched class is added by JS */
input.touched:invalid {
  border-color: red;
}

input.touched:valid {
  border-color: green;
}// JS: add .touched class on blur input.addEventListener('blur', () => {   input.classList.add('touched'); });
```

## CSS Scroll Spy with :target-current (No IntersectionObserver)

`Limited availability` · [source](https://modern-css.com/scroll-spy-without-intersection-observer/)

Highlighting navigation links based on scroll position used to require JavaScript IntersectionObserver or scroll event listeners. Now CSS can track which section is in view with scroll-target-group and the :target-current pseudo-class.

Modern:

```css
.scroller {
  overflow-y: auto;
}

nav a:target-current {
  color: var(--accent);
}
```

Replaces:

```css
/* JS IntersectionObserver approach */
const observer = new IntersectionObserver(   (entries) => {
  entries.forEach(entry => {
    const link = document         .querySelector(`a[href="#        ${entry.target.id}"]`);       link.classList.toggle(         'active',        entry.isIntersecting);
  });
}, {
  threshold: 0.5
});
document.querySelectorAll('section')   .forEach(s =>    observer.observe(s));
```

## CSS :playing, :paused, :muted Pseudo-Classes for Media

`Limited availability` · [source](https://modern-css.com/video-player-states-without-javascript-events/)

Reflecting a video's state in the UI used to mean wiring up play, pause, and waiting event listeners, then toggling class names on a wrapper element. Media pseudo-classes let CSS read the state directly.

Modern:

```css
video:paused + .controls .play-icon { display: block; }
video:playing + .controls .pause-icon { display: block; }
video:buffering + .controls .spinner { display: block; }
video:muted + .controls .muted-badge { display: block; }

.player:has(video:playing) {
  outline: 2px solid currentColor;
}
```

Replaces:

```js
const video = document.querySelector('video');
const wrap = video.closest('.player');

video.addEventListener('play', () => wrap.classList.add('is-playing'));
video.addEventListener('pause', () => wrap.classList.remove('is-playing'));
video.addEventListener('waiting', () => wrap.classList.add('is-buffering'));
video.addEventListener('playing', () => wrap.classList.remove('is-buffering'));
video.addEventListener('volumechange', () => {
  wrap.classList.toggle('is-muted', video.muted);
});
```

> Only Safari 15.4+ and Firefox 150+ support these pseudo-classes today. Chromium is expected to ship them as part of Interop 2026. Keep a JavaScript class-toggle fallback as your primary path until then.
