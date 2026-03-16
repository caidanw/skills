# Accessibility Patterns

Deep reference for building accessible components. The SKILL.md covers the principles — this file covers the implementation patterns. Source of truth: [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/patterns/).

## Focus Management

### :focus-visible Over :focus

`:focus` shows on mouse click — jarring for most users. `:focus-visible` only shows for keyboard navigation:

```css
/* Remove default, replace with focus-visible */
button:focus {
  outline: none;
}

button:focus-visible {
  outline: 2px solid var(--color-focus-ring);
  outline-offset: 2px;
}

/* Group focus for compound controls */
.input-group:focus-within {
  outline: 2px solid var(--color-focus-ring);
  outline-offset: 2px;
}
```

**Never** remove `:focus` styles without providing `:focus-visible` replacements.

### Focus Trapping

For modals, dialogs, and drawers. Tab must cycle within the container only:

```tsx
function useFocusTrap(containerRef: React.RefObject<HTMLElement>, active: boolean) {
  useEffect(() => {
    if (!active || !containerRef.current) return

    const container = containerRef.current
    const focusable = container.querySelectorAll<HTMLElement>(
      'a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])'
    )

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key !== "Tab") return
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault()
        last.focus()
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault()
        first.focus()
      }
    }

    first?.focus()
    container.addEventListener("keydown", handleKeyDown)
    return () => container.removeEventListener("keydown", handleKeyDown)
  }, [active, containerRef])
}
```

### Focus Restoration

When closing overlays, return focus to the element that triggered them:

```tsx
function useRestoreFocus(isOpen: boolean) {
  const triggerRef = useRef<HTMLElement | null>(null)

  useEffect(() => {
    if (isOpen) {
      triggerRef.current = document.activeElement as HTMLElement
    } else {
      triggerRef.current?.focus()
    }
  }, [isOpen])
}
```

### Skip Links

First focusable element on the page. Visually hidden until focused:

```html
<a href="#main-content" class="skip-link">Skip to main content</a>

<style>
.skip-link {
  position: absolute;
  top: -100%;
  left: 0;
  z-index: var(--z-tooltip);
  padding: var(--space-2) var(--space-4);
  background: var(--color-bg);
  color: var(--color-text);
}

.skip-link:focus {
  top: 0;
}
</style>
```

## Keyboard Navigation Patterns

### Arrow Key Navigation

For lists of options (tabs, menus, radio groups). Only the active item is in the tab order:

```tsx
function useArrowNavigation(items: HTMLElement[], orientation: "horizontal" | "vertical") {
  const [activeIndex, setActiveIndex] = useState(0)

  function handleKeyDown(e: React.KeyboardEvent) {
    const prev = orientation === "horizontal" ? "ArrowLeft" : "ArrowUp"
    const next = orientation === "horizontal" ? "ArrowRight" : "ArrowDown"

    switch (e.key) {
      case next:
        e.preventDefault()
        setActiveIndex(i => (i + 1) % items.length)
        break
      case prev:
        e.preventDefault()
        setActiveIndex(i => (i - 1 + items.length) % items.length)
        break
      case "Home":
        e.preventDefault()
        setActiveIndex(0)
        break
      case "End":
        e.preventDefault()
        setActiveIndex(items.length - 1)
        break
    }
  }

  // Active item: tabindex="0". Others: tabindex="-1".
  // Focus follows activeIndex.
}
```

**Use arrow keys for:** tabs, menus, radio groups, tree views, listboxes.
**Use Tab for:** moving between unrelated controls (form fields, toolbar groups).

### Type-Ahead

For listboxes and menus. Typing characters jumps to matching items:

```tsx
function useTypeAhead(items: { label: string }[], onMatch: (index: number) => void) {
  const buffer = useRef("")
  const timeout = useRef<ReturnType<typeof setTimeout>>()

  function handleKeyPress(key: string) {
    clearTimeout(timeout.current)
    buffer.current += key.toLowerCase()

    const match = items.findIndex(item =>
      item.label.toLowerCase().startsWith(buffer.current)
    )
    if (match !== -1) onMatch(match)

    timeout.current = setTimeout(() => { buffer.current = "" }, 500)
  }
}
```

## Screen Reader Patterns

### Live Regions

For dynamic content updates (toasts, form validation, status changes):

```html
<!-- Polite: announced after current speech finishes -->
<div aria-live="polite" aria-atomic="true">
  3 items in cart
</div>

<!-- Assertive: interrupts current speech (use sparingly) -->
<div role="alert">
  Payment failed. Please check your card details.
</div>

<!-- Status: for advisory information -->
<div role="status">
  Saving...
</div>
```

**Rules:**
- `aria-live="polite"` for non-urgent updates (cart count, search results)
- `role="alert"` for errors and urgent messages (implicit `aria-live="assertive"`)
- `role="status"` for loading states and progress (implicit `aria-live="polite"`)
- `aria-atomic="true"` announces the entire region, not just the change
- The live region element must exist in the DOM *before* content is added to it

### Visually Hidden Content

For screen-reader-only text (skip links, additional context):

```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
```

Use for: icon button labels, additional table context, form field descriptions that are visually obvious but not programmatically.

## Color and Contrast

### WCAG AA Requirements

| Element | Minimum Ratio |
|---------|---------------|
| Normal text (< 18pt) | 4.5:1 |
| Large text (>= 18pt or >= 14pt bold) | 3:1 |
| UI components and graphical objects | 3:1 |
| Decorative elements | No requirement |

### Checking Contrast

```ts
// Relative luminance (simplified for sRGB)
function luminance(r: number, g: number, b: number): number {
  const [rs, gs, bs] = [r, g, b].map(c => {
    c = c / 255
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
  })
  return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs
}

function contrastRatio(l1: number, l2: number): number {
  const lighter = Math.max(l1, l2)
  const darker = Math.min(l1, l2)
  return (lighter + 0.05) / (darker + 0.05)
}
```

**Tools:** Chrome DevTools contrast checker, [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/), axe DevTools.

### Don't Rely on Color Alone

Always pair color with another visual indicator:

```html
<!-- Bad: color is the only indicator -->
<span class="text-red">Invalid email</span>

<!-- Good: color + icon + association -->
<p id="email-error" role="alert" class="text-red">
  <svg aria-hidden="true"><!-- warning icon --></svg>
  Invalid email address
</p>
<input aria-describedby="email-error" aria-invalid="true" />
```

## Motion and Animation

### Respecting prefers-reduced-motion

```css
/* Approach 1: Opt-out (animations on by default, disable for preference) */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

/* Approach 2: Opt-in (no animation by default, enable for no-preference) */
.animated {
  /* no animation by default */
}

@media (prefers-reduced-motion: no-preference) {
  .animated {
    transition: transform 300ms ease, opacity 300ms ease;
  }
}
```

**Functional vs. decorative animations:**
- **Functional** (keep even with reduced motion): loading spinners, progress bars, collapse/expand state changes
- **Decorative** (remove with reduced motion): parallax, hover effects, page transitions, background animations

### React Hook

```tsx
function usePrefersReducedMotion(): boolean {
  const [prefersReduced, setPrefersReduced] = useState(true) // SSR-safe default

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)")
    setPrefersReduced(mq.matches)
    const handler = (e: MediaQueryListEvent) => setPrefersReduced(e.matches)
    mq.addEventListener("change", handler)
    return () => mq.removeEventListener("change", handler)
  }, [])

  return prefersReduced
}
```

## Common AI-Generated Accessibility Mistakes

10 mistakes AI agents make most frequently. Check for these in every component:

1. **`<div onClick>` instead of `<button>`** — divs have no keyboard support, no role, no focus
2. **Missing `aria-label` on icon-only buttons** — screen readers announce nothing
3. **`outline: none` without `:focus-visible` replacement** — keyboard users lose all focus indication
4. **Color as sole state indicator** — "red means error" doesn't work for color-blind users
5. **Missing form `<label>`** — inputs without labels are invisible to screen readers
6. **`tabindex > 0`** — creates unpredictable tab order. Use 0 or -1 only
7. **Not restoring focus after closing modals** — keyboard users are stranded in empty space
8. **Missing `aria-expanded` on disclosure widgets** — screen readers can't tell if a section is open
9. **Animating `width`/`height` directly** — causes layout shift and jank. Use `transform`
10. **No `prefers-reduced-motion` handling** — vestibular disorders make animations painful

## Testing Checklist

### Automated (catches ~57% of WCAG issues)

- [ ] Run axe-core or Lighthouse on every component
- [ ] Zero `axe` violations in Storybook addon
- [ ] No `eslint-plugin-jsx-a11y` warnings

### Keyboard (manual)

- [ ] Tab through entire page — every interactive element reachable
- [ ] Focus ring visible on every focused element
- [ ] Modals trap focus, restore on close
- [ ] ESC closes overlays
- [ ] Arrow keys work in tabs, menus, listboxes

### Screen Reader (manual — VoiceOver on macOS, NVDA on Windows)

- [ ] All images have meaningful `alt` text (or `alt=""` if decorative)
- [ ] Form fields announce their label
- [ ] Errors announce when they appear (live region)
- [ ] Dynamic content updates are announced
- [ ] Headings create logical document outline

### Visual

- [ ] All text meets WCAG AA contrast (4.5:1 normal, 3:1 large)
- [ ] UI components meet 3:1 contrast
- [ ] No information conveyed by color alone
- [ ] Zoom to 200% — nothing breaks or overlaps

## Sources

- [WAI-ARIA APG](https://www.w3.org/WAI/ARIA/apg/patterns/) — Canonical component patterns
- [WCAG 2.2 Understanding](https://www.w3.org/WAI/WCAG22/Understanding/) — Detailed success criteria
- [Inclusive Components](https://inclusive-components.design) — Heydon Pickering
- [Radix UI Accessibility](https://www.radix-ui.com/primitives/docs/overview/accessibility) — Reference implementation
- [web.dev Accessibility](https://web.dev/accessibility) — Google's accessibility guides
- [Josh Comeau: prefers-reduced-motion](https://www.joshwcomeau.com/react/prefers-reduced-motion/) — Motion patterns
