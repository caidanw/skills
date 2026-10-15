# Animation

Old-vs-modern patterns from [modern-css.com](https://modern-css.com/), snapshot October 2026. Status is the Baseline tier (Widely / Newly / Limited). Recheck Limited features on caniuse.com or webstatus.dev before relying on them.

## CSS Motion Path Animation with offset-path

`Widely available · since 2022` · [source](https://modern-css.com/motion-path-animation-without-javascript/)

Animating an element along a curve used to mean GSAP's motionPath plugin or manually calculating x/y coordinates in a JS loop. CSS offset-path lets you define the path, then animate offset-distance from 0% to 100%.

Modern:

```css
@keyframes along-path {
  from {
    offset-distance: 0%;
  }

  to {
    offset-distance: 100%;
  }
}

.ball {
  offset-path: path("M 0 0 C 150 -100 300 100 450 0");
  offset-distance: 0%;
  offset-rotate: auto;
  animation: along-path 2s linear infinite;
}
```

Replaces:

```html
<!-- SVG in HTML -->
<svg><path id="track" d="M 0 0 C 150 -100 300 100 450 0"/></svg>
<div class="ball"></div>

// gsap + motionPath plugin required
gsap.to('.ball', {
  duration: 2,
  ease: 'none',
  motionPath: { path: '#track', autoRotate: true }
});
```

## CSS prefers-reduced-motion Media Query

`Widely available · since 2020` · [source](https://modern-css.com/reduced-motion-without-javascript-detection/)

Respecting a user's reduced motion preference required JavaScript to check window.matchMedia and conditionally skip animations. The prefers-reduced-motion media query lets CSS respond directly to the OS accessibility setting.

Modern:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
  }
}
```

Replaces:

```css
// JS: check OS preference, disable animations manually
const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
if (mq.matches) {
  document.querySelectorAll('.animated').forEach(
    el => el.style.animation = 'none'
  );
}
```

## CSS Individual Transform Properties: translate, rotate, scale

`Widely available · since 2022` · [source](https://modern-css.com/independent-transforms-without-the-shorthand/)

transform was one shorthand. To change only rotation you had to repeat translate and scale. Now translate, rotate, and scale are separate properties you can animate on their own.

Modern:

```css
.icon {
  translate: 10px 0;
  rotate: 45deg;
  scale: 1.2;
}

.icon:hover {
  rotate: 90deg;
}
```

Replaces:

```css
.icon {
  transform: translateX(10px) rotate(45deg) scale(1.2);
}

.icon:hover {
  transform: translateX(10px) rotate(90deg) scale(1.2);
```

## Custom CSS Easing with linear() Timing Function

`Widely available · since 2023` · [source](https://modern-css.com/custom-easing-without-cubic-bezier-guessing/)

Creating non-standard easing like bounce or spring required either a cubic-bezier approximation (which can only produce curves, not bounces) or a JavaScript animation library. linear() defines an easing function by interpolating between a list of keyframe values.

Modern:

```css
.el {
  transition: transform 0.6s    linear(0, 1.2 60%, 0.9, 1.05, 1);
}
```

Replaces:

```css
// JS animation library for bounce/spring easing
anime({
  targets: el,
  translateX: 300,
  easing: 'spring(1, 80, 10, 0)'
});
```

## Responsive CSS clip-path with the shape() Function

`Newly available · since 2026` · [source](https://modern-css.com/responsive-clip-paths-without-svg/)

Complex clip paths used to require SVG path() definitions with fixed coordinates that don't scale responsively. The CSS shape() function uses responsive units like percentages and viewport units for truly flexible shapes.

Modern:

```css
.shape {
  clip-path: shape(     from 0% 100%,    line to 50% 0%,    line to 100% 100%  );
}
```

Replaces:

```css
.shape {
  clip-path: path(     'M0 200 L100 0 L200 200 Z'  );
}
```

## CSS View Transitions API (No Framework)

`Newly available · since 2025` · [source](https://modern-css.com/page-transitions-without-a-framework/)

Page transitions used to need Barba.js or React Transition Group. The View Transitions API gives you cross-fades and shared-element motion with one JS call and CSS.

Modern:

```css
// JS: wrap DOM update
document.startViewTransition(() => {
  document.body.innerHTML = newContent;
});

.hero {
  view-transition-name: hero;
}

/* Optional: ::view-transition-old/new(hero) */
```

Replaces:

```css
// barba.js or custom router transitions
import Barba from '@barba/core';
Barba.init({
  transitions: [{
    leave: ({ current }) => gsap.to(current.container, { opacity: 0 }),
    enter: ({ next }) => gsap.from(next.container, { opacity: 0 })
  }]
});
```

## Animate display: none in CSS (No JavaScript)

`Newly available · since 2024` · [source](https://modern-css.com/animating-display-none-without-workarounds/)

You couldn't transition display. Workarounds were JS that set display: none after transition end, or visibility plus opacity and pointer-events. Now discrete properties can participate.

Modern:

```css
.panel {
  transition: opacity .2s, overlay .2s allow-discrete;
  transition-behavior: allow-discrete;
}

.panel.hidden {
  opacity: 0;
  display: none;
}
```

Replaces:

```css
.panel {
  transition: opacity .2s;
}
.panel.hidden {
  opacity: 0;
  visibility: hidden;
}
// JS: after transition, set display:none and pointer-eventsel.addEventListener('transitionend', () => {   el.style.display = 'none'; });
```

## CSS Entry Animations with @starting-style

`Newly available · since 2024` · [source](https://modern-css.com/entry-animations-without-javascript-timing/)

Transitions only ran when a value changed. To animate in, you added a class in JS after paint. @starting-style defines the before state so CSS can transition from it.

Modern:

```css
.card {
  transition: opacity .3s, transform .3s;
  @starting-style {
    opacity: 0;
    transform: translateY(10px);
  }
}
```

Replaces:

```css
.card {
  opacity: 0;
  transform: translateY(10px);
}

.card.visible {
  opacity: 1;
  transform: none;
}// JS: must run after paint or transition won't run requestAnimationFrame(() => {   requestAnimationFrame(() => {     el.classList.add('visible');   });});
```

## Animate `<details>` with ::details-content and interpolate-size

`Newly available · since 2025` · [source](https://modern-css.com/animating-details-without-javascript-height/)

`<details>` has always snapped open and closed. Animating it meant reading scrollHeight in JS, setting a max-height, transitioning, and unsetting on close. ::details-content plus interpolate-size animates the real height natively.

Modern:

```css
:root {
  interpolate-size: allow-keywords;
}

details::details-content {
  height: 0;
  overflow: clip;
  transition: height .3s ease, content-visibility .3s ease allow-discrete;
}

details[open]::details-content {
  height: auto;
}
/* native details, animated open and close */
```

Replaces:

```js
const details = document.querySelectorAll('details');
details.forEach((d) => {
  const content = d.querySelector('.content');
  d.addEventListener('toggle', () => {
    if (d.open) {
      const h = content.scrollHeight;
      content.style.height = '0px';
      requestAnimationFrame(() => { content.style.height = h + 'px'; });
    } else {
      content.style.height = content.scrollHeight + 'px';
      requestAnimationFrame(() => { content.style.height = '0px'; });
    }
  });
});
```

## Staggered CSS Animations with sibling-index()

`Newly available · since 2026` · [source](https://modern-css.com/staggered-animations-without-nth-child-hacks/)

Staggered list animations used to require manually setting --index on each :nth-child or counting in JavaScript. The sibling-index() function gives every element automatic awareness of its position.

Modern:

```css
li {
  transition: opacity .25s ease, translate .25s ease;
  transition-delay:    calc(0.1s * (sibling-index() - 1));
}
```

Replaces:

```css
/* Manual index per nth-child */
li:nth-child(1) {
  --i: 0;
}

li:nth-child(2) {
  --i: 1;
}

li:nth-child(3) {
  --i: 2;
}

li:nth-child(4) {
  --i: 3;
}
/* … repeat for every item … */
li {
  transition-delay: calc(0.1s * var(--i));
}
```

## Scroll-Driven Animations in CSS with scroll-timeline

`Limited availability` · [source](https://modern-css.com/scroll-linked-animations-without-a-library/)

Fade-in-on-scroll used to mean IntersectionObserver, GSAP, or AOS.js. CSS can now trigger animations based on scroll position, zero JavaScript, smooth 60fps.

Modern:

```css
@keyframes reveal {
  from {
    opacity: 0;
    translate: 0 40px;
  }

  to {
    opacity: 1;
    translate: 0 0;
  }
}

.reveal {
  animation: reveal linear both;
  animation-timeline: view();
  animation-range: entry 0% entry 100%;
}
```

Replaces:

```css
// scroll-reveal.js
const obs = new IntersectionObserver(
  (entries) => {
    entries.forEach(e => {
      if (e.isIntersecting)
        e.target.classList.add('visible');
    });
  }
);
document.querySelectorAll('.reveal')
  .forEach(el => obs.observe(el));
```

## Animate height: auto in CSS with interpolate-size

`Limited availability` · [source](https://modern-css.com/smooth-height-auto-animations-without-javascript/)

Animating to height: auto required JS to measure scrollHeight, set a fixed pixel height, then snap back to auto. interpolate-size: allow-keywords lets CSS transition directly to and from intrinsic sizes.

Modern:

```css
:root {
  interpolate-size: allow-keywords;
}

.accordion {
  height: 0;
  overflow: hidden;
  transition: height .3s ease;
}

.accordion.open {
  height: auto;
}
```

Replaces:

```css
.accordion {
  overflow: hidden;
}
// JS: measure, set px height, then snap to autofunction open(el) {   el.style.height = el.scrollHeight + 'px';   el.addEventListener('transitionend', () => {     el.style.height = 'auto';   }, { once: true }); }
```

## CSS calc-size(): Math on auto and fit-content

`Limited availability` · [source](https://modern-css.com/css-calc-size/)

calc() cannot use auto or fit-content. calc-size() can, so you can do fit-content * 0.7 or auto + 2rem, and animate to those values without JavaScript height measurement.

Modern:

```css
.drawer {
  height: 2.5rem;
  overflow: hidden;
  transition: height .4s ease;
}

.drawer:hover,
.drawer:focus-within {
  height: calc-size(max-content, size + 1rem);
}
/* intrinsic end state + extra space, no scrollHeight */
```

Replaces:

```js
const drawer = document.querySelector('.drawer');
drawer.addEventListener('mouseenter', () => {
  drawer.style.height = drawer.scrollHeight + 16 + 'px';
});
drawer.addEventListener('mouseleave', () => {
  drawer.style.height = '2.5rem';
});
```

> calc-size() ships in Chrome and Edge 129+. Firefox and Safari have no support yet. Prefer interpolate-size for plain auto animations, and keep a scrollHeight fallback where you need intrinsic math today.

## CSS animation-trigger Property: Scroll-Triggered Animations

`Limited availability` · [source](https://modern-css.com/scroll-triggered-animations-without-intersection-observer/)

Playing an animation once when an element scrolls into view is the classic scrollytelling pattern. It used to require IntersectionObserver plus the Web Animations API. The animation-trigger property does the same job in pure CSS.

Modern:

```css
.reveal {
  animation: fade-up .6s ease-out both;  animation-trigger: --t play-forwards;   timeline-trigger-name: --t;   timeline-trigger-source: view(); 
}

@keyframes fade-up {
  from { opacity: 0; translate: 0 32px; }
  to { opacity: 1; translate: 0 0; }
}
```

Replaces:

```js
const io = new IntersectionObserver(   (entries) => {
  entries.forEach(   (entry) => {
    if (entry.isIntersecting) {
      entry.target.animate(      [
 { opacity: 0,             translate: '0 32px' },
 { opacity: 1,             translate: '0 0' }
      ], { duration: 600,      easing: 'ease-out',           fill: 'both' });
      io.unobserve(    entry.target);
    }
  });
});

document.querySelectorAll(    '.reveal').forEach(  (el) => io.observe(el));
```

## Element-Scoped View Transitions: Element.startViewTransition()

`Limited availability` · [source](https://modern-css.com/morphing-list-items-without-page-rerenders/)

Animating list reorder with the FLIP technique meant measuring every item, applying the change, measuring again, and animating the delta. Element-scoped view transitions run the entire transition on one subtree of the DOM and leave everything else interactive.

Modern:

```css
.grid li {
  view-transition-name: match-element;
}

::view-transition-group(*) {
  animation-duration: .3s;
}
```

Replaces:

```js
function reorder(items) {
  const positions = new Map();
  document.querySelectorAll(    '.grid li').forEach(  el => {
    positions.set(el.id,    el.getBoundingClientRect());
  });

  applyNewOrder(items);

  document.querySelectorAll(    '.grid li').forEach(  el => {
    const before = positions   .get(el.id);
    const after  = el         .getBoundingClientRect();
    const dx = before.left   - after.left;
    const dy = before.top    - after.top;
    el.animate(  [
 { transform: `translate(${dx}px,${dy}px)` },
 { transform: 'translate(0,0)' }
    ], { duration: 300,        easing: 'ease' });
  });
}
```

## CSS Auto-Hiding Header with scroll-state(scrolled)

`Limited availability` · [source](https://modern-css.com/auto-hiding-header-without-scroll-listeners/)

Hiding the header on scroll-down and revealing it on scroll-up used to mean tracking scroll position in JavaScript and comparing it to the previous value. CSS scroll-state() with the scrolled descriptor reports the direction of the most recent scroll natively.

Modern:

```css
html {
  container-type: scroll-state;
}

header {
  position: fixed;
  inset-block-start: 0;
  transition: translate .3s;
}

@container scroll-state(
scrolled: block-end
) {
  header {
    translate: 0 -100%;
  }
}
```

Replaces:

```js
let lastY = window.scrollY;

window.addEventListener(   'scroll', () => {
  const y = window     .scrollY;
  const dir = y > lastY      ? 'down' : 'up';
  document.querySelector(    'header')      .classList.toggle(        'hidden', dir === 'down');
  lastY = y;
});
```

## CSS scroll-state() Container Queries: :stuck and :snapped

`Limited availability` · [source](https://modern-css.com/sticky-snapped-styling-without-javascript/)

Styling elements differently when they become stuck (sticky) or snapped used to require JavaScript scroll event listeners. scroll-state() container queries let CSS respond to scroll-related states directly.

Modern:

```css
.header-wrap {
  container-type: scroll-state;
}

@container scroll-state(
stuck: top
) {
  .header {
    box-shadow: 0 2px 8px #0002;
  }
}
```

Replaces:

```css
/* JS scroll listener approach */
const header = document   .querySelector('.header');
const offset = header   .offsetTop;
window.addEventListener(   'scroll', () => {
  header.classList       .toggle('stuck',      window.scrollY         >= offset);
});
```

## CSS random() Function for Per-Element Random Values

`Limited availability` · [source](https://modern-css.com/random-values-without-javascript/)

Randomising layout details like rotation, size, or delay used to mean Math.random() in JavaScript and inline style attributes. The CSS random() function generates a random value per element directly in CSS.

Modern:

```css
.card {
  rotate: random(-15deg, 15deg);
  animation-delay: random(0s, 1s);
}
```

Replaces:

```css
// JS: randomise per element at runtime
document.querySelectorAll('.card').forEach(el => {
  const r = Math.random() * 30 - 15;
  el.style.setProperty('--rotate', r + 'deg');
  const d = Math.random();
  el.style.setProperty('--delay', d + 's');
});

/* CSS reads the inline vars */
.card {
  rotate: var(--rotate);
  animation-delay: var(--delay);
}
```
