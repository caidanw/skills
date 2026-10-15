# HTML-native UI

Old-vs-modern patterns from [modern-css.com](https://modern-css.com/), snapshot October 2026. Status is the Baseline tier (Widely / Newly / Limited). Recheck Limited features on caniuse.com or webstatus.dev before relying on them.

## CSS Accordion with details and summary (No JavaScript)

`Widely available · since 2020` · [source](https://modern-css.com/accordion-without-javascript/)

Accordions used to need JavaScript to toggle visibility, update aria-expanded, and manage keyboard events. The details and summary elements handle all of that natively.

Modern:

```html
<!-- No JS, no aria wiring -->
<details>
  <summary>What is CSS?</summary>
  <p>CSS is a stylesheet language.</p>
</details>
```

Replaces:

```html
<!-- HTML: custom markup -->
<button aria-expanded="false" aria-controls="panel">
  What is CSS?
</button>
<div id="panel" hidden>
  <p>CSS is a stylesheet language.</p>
</div>
```

## CSS Modal Dialog with the Native dialog Element

`Widely available · since 2022` · [source](https://modern-css.com/modal-dialogs-without-a-javascript-library/)

The old way was a custom overlay plus JavaScript for open/close, ESC key, click-outside, focus trap, and z-index. The dialog element and showModal() handle all of that.

Modern:

```css
dialog {
  padding: 1rem;
}

dialog::backdrop {
  background: rgb(0 0 0 / .5);
}
/* JS: dialog.showModal(); dialog.close(); */
```

Replaces:

```css
.overlay {
  position: fixed;
  inset: 0;
  background: rgb(0 0 0 / .5);
}
/* JS: addEventListener click, keydown ESC, focus trap,   aria-hidden, body scroll lock, z-index stacking */
```

## HTML inputmode and enterkeyhint for Mobile Keyboards

`Widely available · since 2021` · [source](https://modern-css.com/mobile-keyboard-hints-without-javascript/)

Mobile users got stuck with the default text keyboard on every input, or developers shipped JS workarounds to detect device type. inputmode and enterkeyhint let HTML request the right keyboard directly.

Modern:

```html
<!-- Numeric pad, no type=tel hack -->
<input type="text" inputmode="numeric" />

<!-- Search keyboard with Search return key -->
<input type="search" inputmode="search" enterkeyhint="search" />
```

Replaces:

```css
/* Hack: use type=tel to get numeric keyboard */
<input type="tel" pattern="[0-9]*" />/* No way to control the return key label */
if (/Mobi/.test(navigator.userAgent)) {
  submitBtn.textContent = 'Search';
}
```

## Lazy Load Images in HTML with loading="lazy"

`Widely available · since 2023` · [source](https://modern-css.com/lazy-load-images-without-javascript/)

Lazy loading images used to mean writing an IntersectionObserver, swapping src attributes, and handling edge cases per browser. One attribute does it all now.

Modern:

```html
<!-- Above the fold: no lazy -->
<img src="hero.jpg" alt="Hero" />

<!-- Below the fold: lazy load -->
<img src="product.jpg" alt="Product" loading="lazy" />
```

Replaces:

```html
<!-- HTML: data-src instead of src --><img data-src="photo.jpg" class="lazy" /> const observer = new IntersectionObserver(([entry]) => {
  if (entry.isIntersecting) {
    entry.target.src = entry.target.dataset.src;     observer.unobserve(entry.target);
  }
});
document.querySelectorAll('.lazy').forEach(img => observer.observe(img));
```

## HTML output Element for Live Form Output

`Widely available` · [source](https://modern-css.com/live-form-output-without-javascript-dom-writes/)

Showing a live result from a form used to mean wiring up input listeners that wrote to a div on every change. The output element connects directly to form inputs with no JavaScript.

Modern:

```html
<input type="range" id="volume" name="volume" /><output for="volume">50</output>
```

Replaces:

```html
<input type="range" id="volume" /><div id="display"></div> const input = document.getElementById('volume');
const display = document.getElementById('display');
input.addEventListener('input', () => {
  display.textContent = input.value;
});
```

## CSS-Only Dropdown Menu with the Popover API

`Newly available · since 2025` · [source](https://modern-css.com/dropdown-menus-without-javascript-toggles/)

The old way used JS for toggle, click-outside, and ESC, plus manual aria. The popover attribute and popovertarget give you a built-in dismissible popover with no toggle code.

Modern:

```css
/* <button popovertarget="menu"> ... <div popover> */
#menu[popover] {
  position: absolute;
  margin: 0.25rem 0;
}
/* Toggle, light dismiss, ESC: built in. */
```

Replaces:

```css
.menu {
  display: none;
}

.menu.open {
  display: block;
}
/* JS: toggle class, document click-outside,   keydown ESC, aria-expanded, aria-hidden */
```

## CSS Exclusive Accordion with the details name Attribute

`Newly available · since 2024` · [source](https://modern-css.com/exclusive-accordions-without-javascript/)

Making only one accordion panel open at a time required JavaScript to listen for toggle events and close all other open details elements. The name attribute on details elements creates a mutually exclusive group. The browser handles closing others automatically.

Modern:

```html
<details name="faq">
  <summary>Question 1</summary>
  <p>Answer 1</p>
</details>
<details name="faq">
  <summary>Question 2</summary>
  <p>Answer 2</p>
</details>
```

Replaces:

```css
// Close all on toggle, reopen the clicked one
document.querySelectorAll('details')
  .forEach(d => {
    d.addEventListener('toggle', () => {
      if (d.open)
        others.forEach(o => o.open = false);
    });
  });
```

## CSS Modal Controls with commandfor and command Attributes

`Newly available · since 2025` · [source](https://modern-css.com/modal-controls-without-onclick-handlers/)

Opening a dialog modally required onclick handlers calling showModal(). Invoker Commands let buttons perform actions on other elements declaratively with commandfor and command attributes.

Modern:

```html
<button commandfor="dlg" command="show-modal">
  Open Dialog
</button>
<dialog id="dlg">...</dialog>
```

Replaces:

```html
<!-- Inline onclick or JS event listener -->
<button onclick="
  document.querySelector('#dlg')
  .showModal()">
  Open Dialog
</button>
<dialog id="dlg">...</dialog>
```

## Customizable CSS Select with appearance: base-select

`Limited availability` · [source](https://modern-css.com/customizable-selects-without-a-javascript-library/)

Styling selects used to require JavaScript libraries like Select2 or Choices.js that replace the native element entirely. Now appearance: base-select unlocks full CSS customization of the native select.

Modern:

```css
select,select ::picker(select) {
  appearance: base-select;
}

select option:checked {
  background: var(--accent);
}
```

Replaces:

```css
/* JS: replace native select with custom DOM */
import Choices from 'choices.js';
new Choices('#my-select', {
  searchEnabled: false,
}

);
/* Plus ~30 lines of custom CSS for   .choices__inner, .choices__list, etc. */
```

## HTML datalist: Native Autocomplete (No JavaScript)

`Limited availability` · [source](https://modern-css.com/native-autocomplete-without-javascript/)

Building autocomplete used to mean pulling in a library like Typeahead or Awesomplete and wiring up event listeners. The datalist element gives browsers native autocomplete with zero JavaScript.

Modern:

```html
<input list="countries" id="country" name="country" />
<datalist id="countries">
  <option value="United States" />
  <option value="Canada" />
  <option value="Mexico" />
</datalist>
```

Replaces:

```css
/* Add autocomplete library (Awesomplete, Typeahead, etc.) */
import Awesomplete from 'awesomplete';
new Awesomplete(document.querySelector('#country'), {
  list: ['Afghanistan', 'Albania', 'Algeria', ...]
});
/* Plus custom CSS for the dropdown */
```

## CSS Dialog Light Dismiss with closedby Attribute

`Limited availability` · [source](https://modern-css.com/dialog-light-dismiss-without-click-outside-listeners/)

Closing a dialog when the user clicks outside required a JavaScript click listener on the backdrop. The closedby attribute gives dialogs popover-style light dismiss behavior natively.

Modern:

```html
<dialog closedby="any">  Click outside or press ESC to close</dialog>
```

Replaces:

```css
/* JS: detect click outside dialog bounds */
dialog.addEventListener('click', (e) => {
  const rect = dialog.getBoundingClientRect();   if (e.clientX < rect.left ||      e.clientX > rect.right ||      e.clientY < rect.top ||      e.clientY > rect.bottom) {
    dialog.close();
  }
});
```
