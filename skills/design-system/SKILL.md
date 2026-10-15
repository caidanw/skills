---
name: design-system
description: >-
  Build design system components and UI that are accessible, themeable, and
  visually polished. Use when building buttons, dialogs, forms, cards, or any
  reusable UI components. Covers component API design, design tokens,
  accessibility, theming, visual design rules, and interaction patterns.
  Triggers on: "build a component", "design system", "create a button",
  "build a dialog", "add dark mode", "design tokens", "theme", "accessible
  component", "UI component", "component library".
globs: ["*.tsx", "*.jsx", "*.css", "*.scss"]
---

# Design Systems

Build UI components that are accessible, themeable, composable, and visually polished. This skill covers architecture and patterns. See companion skills for React performance (`vercel-react-best-practices`), composition (`vercel-composition-patterns`), CSS techniques (`modern-css`), and UI code review (`web-design-guidelines`).

## 1. Component Architecture

### Headless + Styled Layers

Separate behavior from appearance. Use headless primitives (Radix, Ark UI, Headless UI) for accessibility and interaction, then add your styling layer on top. This gives you accessible-by-default components you can theme however you want.

### Compound Components Over Prop-Heavy Monoliths

Complex UI should be composed of named parts, not configured with dozens of props:

```tsx
// Good — composable, flexible, clear
<Dialog.Root>
  <Dialog.Trigger asChild>
    <Button>Edit Profile</Button>
  </Dialog.Trigger>
  <Dialog.Content>
    <Dialog.Title>Edit Profile</Dialog.Title>
    <Dialog.Description>Update your information below.</Dialog.Description>
    {/* form content */}
    <Dialog.Close asChild>
      <Button variant="ghost">Cancel</Button>
    </Dialog.Close>
  </Dialog.Content>
</Dialog.Root>

// Bad — prop soup, inflexible, hard to customize
<Dialog
  trigger="Edit Profile"
  title="Edit Profile"
  description="Update your information below."
  showClose
  cancelText="Cancel"
  onConfirm={handleConfirm}
/>
```

### API Design Rules

- **Props for configuration** — variant, size, disabled, loading
- **Children for content** — what goes inside the component
- **Discriminated union props for variants** — never boolean soup

```tsx
// Good — variants as union type
type ButtonProps = {
  variant: "primary" | "secondary" | "destructive" | "ghost" | "link"
  size: "sm" | "md" | "lg"
  children: React.ReactNode
  loading?: boolean
  disabled?: boolean
}

// Bad — boolean flags for everything
type ButtonProps = {
  primary?: boolean
  secondary?: boolean
  danger?: boolean
  small?: boolean
  large?: boolean
}
```

- **Consistent naming** across all components: Root, Trigger, Content, Item, Label, Description
- **Open code over black boxes** — prefer owning the component source (shadcn/ui model) over fighting an npm package's API

## 2. Design Tokens

Structure tokens in two layers. Primitive tokens define raw values. Semantic tokens assign meaning. Use semantic tokens directly in components — don't add a third "component token" layer unless you're building a white-label product with per-customer theming.

```css
/* Layer 1: Primitive — raw values, no meaning */
--color-gray-50: oklch(0.985 0 0);
--color-gray-900: oklch(0.145 0 0);
--color-blue-500: oklch(0.55 0.2 250);
--radius-sm: 0.25rem;
--radius-md: 0.5rem;

/* Layer 2: Semantic — assigned meaning, used directly in components */
--color-background: var(--color-gray-50);
--color-foreground: var(--color-gray-900);
--color-primary: var(--color-blue-500);
--radius-default: var(--radius-md);
```

**Why OKLCH over HSL:** Perceptually uniform (same lightness looks the same across hues), supports P3 wide-gamut displays, produces better gradients without muddy midpoints.

Use a constrained scale for spacing (4px/8px grid), type (modular ratio with `clamp()`), shadows (5 levels), and border-radius (3-4 sizes). Never use arbitrary values — pick from the scale.

For the full token system implementation, see [references/design-tokens.md](references/design-tokens.md).

## 3. Accessibility First

Accessibility is not a feature — it's a baseline. Every interactive component must meet these requirements:

### Keyboard

Every interactive component must be fully operable with keyboard alone. Follow WAI-ARIA Authoring Practices Guide (APG) patterns for keyboard navigation — don't invent your own.

### ARIA

Use semantic HTML first (`<button>`, `<a>`, `<label>`, `<dialog>`, `<table>`). Only add ARIA when HTML semantics aren't sufficient. When you do, follow the APG patterns exactly.

### Focus

- Use `:focus-visible` (not `:focus`) for keyboard-only focus rings
- Trap focus inside modals and dialogs
- Restore focus to the trigger element when overlays close
- Never use `tabindex > 0`

### Color

- 4.5:1 contrast for normal text, 3:1 for large text and UI components (WCAG AA)
- Never rely on color alone — add icons, text, or patterns
- Test with color blindness emulation (Chrome DevTools)

### Motion

- Always respect `prefers-reduced-motion` — disable decorative animations, keep functional ones
- Safe durations: fast 150ms, medium 300ms, slow 500ms

For component-specific accessibility patterns, see [references/accessibility-patterns.md](references/accessibility-patterns.md).

## 4. Visual Design Rules

Good visual design follows consistent, systematic rules — not ad-hoc decisions.

### Spacing

Use the scale. Never use arbitrary pixel values. Components should use the same spacing scale as the rest of the app.

### Typography

- Fluid sizing with `clamp()`: `font-size: clamp(1rem, 0.5rem + 2vw, 1.5rem)`
- Line length: 45-75 characters (`max-width: 65ch`)
- Line height: 1.5 for body, 1.2-1.3 for headings
- `font-variant-numeric: tabular-nums` for number columns
- `text-wrap: balance` on headings to prevent orphans

### Visual Hierarchy

Create hierarchy through size, weight, and color — not font-size alone. Three levels of emphasis is usually enough: primary (bold/large), secondary (normal), tertiary (muted/small).

### Borders and Separation

Fewer borders. Use spacing, contrasting backgrounds, and subtle shadows to separate elements instead. When you do use borders, keep them light and consistent.

### Shadows and Elevation

Define 5 levels: none, sm, md, lg, xl. Use layered shadows (ambient + directional) for realism. In dark mode, use lighter surfaces for higher elevation instead of shadows.

### Border Radius

3-4 sizes: `sm` (0.25rem), `md` (0.5rem), `lg` (0.75rem), `full` (9999px for pills). Keep consistent within a component — don't mix radii.

## 5. Interaction Patterns

### Loading States

- **Skeleton** when you know the layout shape (content loading)
- **Spinner** when you don't know what will appear (action in progress)
- Show feedback within 100ms of user action
- Always show what's loading: "Saving changes..." not just a spinner

### Empty States

Don't render broken UI for empty data. Show: explanation of what this area is, how to populate it, and a CTA to get started.

### Error States

- Plain language, not error codes
- Explain what went wrong AND how to fix it
- Inline errors for forms (next to the field, linked with `aria-describedby`)
- Focus the first error on form submit

### Toasts and Notifications

- Position: consistent throughout app (top-right or bottom-center)
- Duration: 3-5s for success, persistent for errors (with dismiss button)
- Use `aria-live="polite"` or `role="alert"` for screen readers
- Don't move focus to the toast

### Modals and Dialogs

- Focus trap inside the dialog
- ESC key closes it
- Dim overlay behind
- Restore focus to trigger on close
- Confirm before destructive actions

### Forms

- Labels above inputs (not placeholder-as-label)
- Inline validation on blur (not on every keystroke)
- Single-column layout
- Keep user input on error — never clear the form
- Mark required fields, not optional ones

### Animation

- CSS transitions for simple A→B state changes
- JS (Framer Motion, React Spring) for springs and complex sequences
- Animate `transform` and `opacity` only — never `width`, `height`, or `top`/`left`
- Never use `transition: all` — list properties explicitly

## 6. Theming

### CSS Custom Properties for Runtime Switching

Semantic tokens swap between themes. Don't invert colors — map them intentionally:

```css
:root {
  --color-bg: oklch(1 0 0);
  --color-surface: oklch(0.97 0 0);
  --color-text: oklch(0.145 0 0);
  --color-text-muted: oklch(0.45 0 0);
  --color-border: oklch(0.87 0 0);
}

.dark {
  --color-bg: oklch(0.1 0 0);
  --color-surface: oklch(0.15 0 0);
  --color-text: oklch(0.93 0 0);
  --color-text-muted: oklch(0.6 0 0);
  --color-border: oklch(0.25 0 0);
}
```

### Dark Mode Rules

- No pure black (`#000`) backgrounds — use dark gray (oklch lightness ~0.1)
- Reduce saturation slightly on colored elements
- Higher elevation = lighter surface (not darker)
- Shadows don't work on dark backgrounds — use subtle borders or lighter surfaces
- Set `color-scheme: dark` on `<html>` for native form controls and scrollbars
- Set `<meta name="theme-color">` to match page background

## What NOT to Do

- **No `<div onClick>`** — use `<button>` for actions, `<a>` for navigation
- **No `outline: none`** without a `:focus-visible` replacement
- **No `tabindex > 0`** — ever
- **No `transition: all`** — list properties explicitly
- **No animating `width`/`height`** — use `transform: scale()`
- **No hardcoded colors/spacing** — use tokens from the scale
- **No color alone for state** — add icons or text
- **No blocking paste** on inputs (`onPaste` + `preventDefault`)
- **No disabling zoom** (`user-scalable=no`, `maximum-scale=1`)
- **No placeholder-as-label** — always use a real `<label>`
- **No images without dimensions** — set `width`/`height` to prevent CLS

## Companion Skills

- **`vercel-react-best-practices`** — React/Next.js performance (58 rules by priority)
- **`vercel-composition-patterns`** — compound components, state management, React 19 APIs
- **`modern-css`** — modern CSS techniques (64 old-vs-modern comparisons)
- **`web-design-guidelines`** — UI code review checklist (accessibility, forms, animation, performance)
- **`typescript`** — type patterns for component props (discriminated unions, branded types)

For design token implementation, see [references/design-tokens.md](references/design-tokens.md).
For component recipes, see [references/component-recipes.md](references/component-recipes.md).
For accessibility patterns, see [references/accessibility-patterns.md](references/accessibility-patterns.md).
