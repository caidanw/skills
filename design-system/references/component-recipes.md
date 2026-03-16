# Component Recipes

12 component recipes covering the most common UI needs. Each recipe includes: semantic HTML structure, required ARIA attributes, keyboard interactions, TypeScript props, and essential styling notes. All examples are CSS-agnostic — adapt to your styling approach.

## 1. Button

```tsx
type ButtonProps = {
  variant: "primary" | "secondary" | "destructive" | "ghost" | "link"
  size: "sm" | "md" | "lg"
  loading?: boolean
  disabled?: boolean
  children: React.ReactNode
} & React.ButtonHTMLAttributes<HTMLButtonElement>
```

**HTML:** `<button>`. Never `<div onClick>`.

**ARIA:**
- Icon-only buttons: `aria-label="Close"` (required)
- Loading state: `aria-busy="true"`, `aria-disabled="true"`, show spinner

**Keyboard:** Enter and Space activate. Already handled by `<button>`.

**Styling notes:**
- Disabled: reduce opacity, `pointer-events: none`, `cursor: not-allowed`
- Loading: show inline spinner, keep button width stable, disable interaction
- Focus: visible ring via `:focus-visible`

## 2. Dialog / Modal

```tsx
type DialogProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  children: React.ReactNode
}
```

**HTML:** `<dialog>` (native) or `role="dialog"` on a `<div>`.

**ARIA:**
- `aria-modal="true"` on the dialog container
- `aria-labelledby` pointing to the title element
- `aria-describedby` (optional) pointing to description

**Keyboard:**
- ESC closes the dialog
- Tab/Shift+Tab cycles within (focus trap)
- Focus moves to first focusable element on open (or close/cancel button for destructive actions)

**Focus management:**
1. On open: move focus into dialog
2. Trap: Tab cycles only within dialog
3. On close: restore focus to the trigger element

**Styling notes:**
- Render into a portal (outside component tree)
- Overlay: semi-transparent background, prevent body scroll
- Animate entry with opacity + `transform: scale(0.95)` → `scale(1)`

## 3. Select / Dropdown

```tsx
type SelectProps<T extends string> = {
  value: T
  onValueChange: (value: T) => void
  placeholder?: string
  children: React.ReactNode  /* SelectItem components */
}

type SelectItemProps = {
  value: string
  children: React.ReactNode
  disabled?: boolean
}
```

**ARIA (listbox pattern):**
- Trigger: `role="combobox"`, `aria-expanded`, `aria-controls`
- Popup: `role="listbox"`
- Items: `role="option"`, `aria-selected`
- `aria-activedescendant` for virtual focus (highlighted item)

**Keyboard:**
- Down Arrow / Up Arrow: navigate options
- Enter / Space: select highlighted option
- ESC: close popup
- Type-ahead: jump to matching option by typing characters
- Home / End: jump to first / last option

**Styling notes:**
- Render popup in a portal for overflow handling
- Position with collision detection (flip if near viewport edge)
- Highlight active item distinctly from selected item

## 4. Tabs

```tsx
type TabsProps = {
  defaultValue: string
  children: React.ReactNode  /* TabsList + TabsContent */
}
```

**HTML structure:**
```html
<div role="tablist" aria-label="Section name">
  <button role="tab" aria-selected="true" aria-controls="panel-1" id="tab-1">Tab 1</button>
  <button role="tab" aria-selected="false" aria-controls="panel-2" id="tab-2" tabindex="-1">Tab 2</button>
</div>
<div role="tabpanel" id="panel-1" aria-labelledby="tab-1" tabindex="0">Content 1</div>
<div role="tabpanel" id="panel-2" aria-labelledby="tab-2" tabindex="0" hidden>Content 2</div>
```

**Keyboard:**
- Left/Right Arrow: navigate between tabs (horizontal)
- Home/End: first/last tab
- **Automatic activation**: tab activates on focus (preferred unless panels are expensive to load)
- Only the active tab is in the tab sequence (`tabindex="0"`); inactive tabs get `tabindex="-1"`

## 5. Accordion

```tsx
type AccordionProps = {
  type: "single" | "multiple"
  defaultValue?: string | string[]
  children: React.ReactNode  /* AccordionItem components */
}

type AccordionItemProps = {
  value: string
  children: React.ReactNode  /* Trigger + Content */
}
```

**HTML:** Use heading elements (`<h3>`) wrapping the trigger button for proper document outline.

**ARIA:**
- Trigger: `aria-expanded="true|false"`, `aria-controls` pointing to content
- Content: `role="region"`, `aria-labelledby` pointing to trigger

**Keyboard:** Enter/Space toggles the section.

**Styling notes:**
- Animate content height with `grid-template-rows: 0fr` → `1fr` (avoids animating `height`)
- Content inner wrapper needs `overflow: hidden`

## 6. Toast / Notification

```tsx
type ToastProps = {
  variant: "default" | "success" | "error" | "warning"
  title: string
  description?: string
  action?: { label: string; onClick: () => void }
  duration?: number  /* ms, default 5000. 0 = persistent */
}
```

**ARIA:**
- Container: `aria-live="polite"` for non-urgent, `role="alert"` for errors
- `aria-atomic="true"` to announce entire message
- Do NOT move focus to the toast

**Keyboard:** Toast action button must be focusable. Dismiss button must be reachable.

**Behavior:**
- Auto-dismiss: 3-5s for success/info, persistent for errors
- Stacking: newest on top, limit to 3-5 visible
- Pause timer on hover (user is reading)
- Position: consistent throughout app

## 7. Form (Input + Label + Error)

```tsx
type InputProps = {
  label: string
  error?: string
  description?: string
  required?: boolean
} & React.InputHTMLAttributes<HTMLInputElement>
```

**HTML structure:**
```html
<div>
  <label for="email">Email <span aria-hidden="true">*</span></label>
  <p id="email-desc">We'll send a confirmation to this address.</p>
  <input
    id="email"
    type="email"
    name="email"
    autocomplete="email"
    required
    aria-required="true"
    aria-describedby="email-desc email-error"
    aria-invalid="true"  /* only when error exists */
  />
  <p id="email-error" role="alert">Please enter a valid email address.</p>
</div>
```

**Rules:**
- Labels above inputs, always visible (not placeholder-as-label)
- Use correct `type` and `inputmode` (`email`, `tel`, `url`, `number`)
- Use `autocomplete` for common fields (name, email, address, cc-number)
- Validate on blur, not on every keystroke
- On submit error: focus the first invalid field
- Never clear user input on error
- Never block paste

## 8. Card

```tsx
type CardProps = {
  children: React.ReactNode
  asLink?: { href: string }  /* makes entire card clickable */
}
```

**HTML:**
```html
<!-- Static card -->
<article>
  <img src="..." alt="..." width="400" height="300" />
  <h3>Title</h3>
  <p>Description</p>
</article>

<!-- Clickable card — stretch the link, not wrap in <a> -->
<article class="card">
  <img src="..." alt="..." width="400" height="300" />
  <h3><a href="/item/1" class="card-link">Title</a></h3>
  <p>Description</p>
</article>
```

**Clickable card technique** — stretch the link to cover the card without wrapping everything in `<a>`:
```css
.card { position: relative; }
.card-link::after {
  content: "";
  position: absolute;
  inset: 0;
}
```

**Styling notes:**
- Images: set `width`, `height`, and `aspect-ratio` to prevent CLS
- Below-fold cards: `loading="lazy"` on images

## 9. Badge / Tag

```tsx
type BadgeProps = {
  variant: "default" | "secondary" | "outline" | "success" | "warning" | "error"
  size?: "sm" | "md"
  children: React.ReactNode
  onDismiss?: () => void  /* makes it dismissible */
}
```

**ARIA:**
- Dismiss button: `aria-label="Remove tag: ${children}"`
- Don't rely on color alone — include text or icons for status

**Styling notes:**
- Inline-flex with pill shape (`border-radius: var(--radius-full)`)
- Truncate long text with `max-width` and `text-overflow: ellipsis`
- Status badges: use background color + text, not color alone

## 10. Tooltip

```tsx
type TooltipProps = {
  content: string
  children: React.ReactElement  /* the trigger element */
  side?: "top" | "right" | "bottom" | "left"
  delayDuration?: number  /* ms, default 400 */
}
```

**ARIA:**
- Trigger: `aria-describedby` pointing to tooltip
- Tooltip: `role="tooltip"`, `id` matching `aria-describedby`

**Behavior:**
- Show on hover (300-500ms delay) AND keyboard focus
- Hide delay: 100-200ms (allows moving mouse to tooltip)
- Tooltip content must be hoverable (for screen magnifier users)
- ESC dismisses tooltip

**Styling notes:**
- Render in portal for overflow handling
- Collision detection (flip if near viewport edge)
- Arrow pointing to trigger element
- Animate with opacity + slight translate

## 11. Avatar

```tsx
type AvatarProps = {
  src?: string
  alt: string
  fallback: string  /* initials, e.g. "JD" */
  size?: "sm" | "md" | "lg"
}
```

**Fallback chain:** Image → Initials → Generic icon.

**HTML:**
```html
<span class="avatar">
  <img src="..." alt="Jane Doe" />
  <!-- fallback shown when image fails -->
  <span class="avatar-fallback" aria-hidden="true">JD</span>
</span>
```

**Styling notes:**
- Circular: `border-radius: var(--radius-full)`, `overflow: hidden`
- Image: `object-fit: cover` to prevent distortion
- Fallback background: generate from name hash for consistent color per user
- Group: stack with negative margin, latest on top with `z-index`

## 12. Skeleton

```tsx
type SkeletonProps = {
  className?: string  /* controls size/shape via CSS */
}
```

**Purpose:** Placeholder that shows layout shape while content loads. Reduces perceived loading time vs. a spinner.

**HTML:**
```html
<div class="skeleton" aria-hidden="true" />
<!-- Or for a text block: -->
<div class="skeleton skeleton-text" aria-hidden="true" />
```

**Styling:**
```css
.skeleton {
  background: var(--color-bg-muted);
  border-radius: var(--radius-md);
  animation: skeleton-pulse 2s ease-in-out infinite;
}

@keyframes skeleton-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

@media (prefers-reduced-motion: reduce) {
  .skeleton { animation: none; opacity: 0.7; }
}
```

**Rules:**
- Match the shape of the content it replaces (height, width, border-radius)
- Use `aria-hidden="true"` — skeletons are visual-only
- Preserve `aspect-ratio` for images/media
- Group skeletons to show layout structure, not individual fields

## Sources

- [WAI-ARIA APG Patterns](https://www.w3.org/WAI/ARIA/apg/patterns/) — Canonical accessibility patterns
- [Radix UI Primitives](https://www.radix-ui.com/primitives) — Reference implementations
- [shadcn/ui](https://ui.shadcn.com) — Component API conventions
- [Inclusive Components](https://inclusive-components.design) — Heydon Pickering
