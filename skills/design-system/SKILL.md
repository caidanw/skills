---
name: design-system
description: >-
  Build design system components and UI that are accessible, themeable, and visually
  consistent. Use when building reusable components (buttons, dialogs, forms, cards), designing
  component APIs, setting up design tokens or scales, or adding theming and dark mode. Covers
  component architecture, token layers, theming, visual rules, and component states.
  Triggers on: "build a component", "design system", "component library", "create a button",
  "build a dialog", "design tokens", "theme", "dark mode", "accessible component".
globs: ["*.tsx", "*.jsx", "*.css", "*.scss"]
---

# Design Systems

Decisions that make a component library consistent: how components are shaped, where values
come from, and how themes switch. Companion skills cover the rest:

- **`web-design-guidelines`**: rule-by-rule UI review (a11y, forms, focus, animation, copy, anti-patterns). Run it on finished UI.
- **`modern-css`**: which native CSS or HTML feature to use (`<dialog>`, `popover`, `light-dark()`, `@starting-style`).
- **`vercel-composition-patterns`**: compound components and context in React.
- **`typescript-best-practices`**: discriminated unions for props.

## 1. Component Architecture

### Native first, then headless, then custom

Use the platform element when it exists (`<button>`, `<dialog>`, `<details>`, `popover`, `<select>` with `appearance: base-select` where supported). Otherwise use headless primitives (Radix, Ark UI, React Aria) for behavior and keyboard support, and put your styling layer on top. Hand-roll interaction logic last.

### Compound components over prop-heavy monoliths

```tsx
// Good — composable, each part customizable
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

// Bad — prop soup
<Dialog trigger="Edit Profile" title="Edit Profile" showClose cancelText="Cancel" onConfirm={save} />
```

### API rules

- **Props for configuration** (`variant`, `size`, `disabled`, `loading`); **children for content**.
- **Union-typed variants, never boolean flags:**

```tsx
type ButtonProps = {
  variant: "primary" | "secondary" | "destructive" | "ghost" | "link"
  size: "sm" | "md" | "lg"
  loading?: boolean
  disabled?: boolean
  children: React.ReactNode
}
// not: { primary?: boolean; danger?: boolean; small?: boolean; large?: boolean }
```

- **Same part names everywhere:** Root, Trigger, Content, Item, Label, Description.
- **Own the source** (shadcn/ui model) rather than fighting a black-box package's API.

## 2. Design Tokens

Two layers. Primitives hold raw values; semantic tokens assign meaning and are what components use. Add a third "component token" layer only for white-label products with per-customer theming.

```css
/* Primitive: raw values, no meaning */
--color-gray-50: oklch(0.985 0 0);
--color-gray-900: oklch(0.145 0 0);
--color-blue-500: oklch(0.55 0.2 250);
--radius-md: 0.5rem;

/* Semantic: meaning, used by components */
--color-background: var(--color-gray-50);
--color-foreground: var(--color-gray-900);
--color-primary: var(--color-blue-500);
--radius-default: var(--radius-md);
```

Use OKLCH for palettes: equal lightness looks equal across hues, it reaches P3 colors, and gradients avoid muddy midpoints.

Every value comes from a constrained scale: spacing on a 4px grid, a modular type scale, 5 shadow levels, 3–4 radii, and a z-index scale. No arbitrary values in components.

Full token system (12-step color scales, spacing, type, shadow, radius, z-index): [references/design-tokens.md](references/design-tokens.md).

## 3. Theming

Semantic tokens switch per theme; components never change. For light/dark, let the browser pick and allow a user override:

```css
:root {
  color-scheme: light dark; /* native controls and scrollbars follow */
  --color-bg: light-dark(oklch(1 0 0), oklch(0.1 0 0));
  --color-surface: light-dark(oklch(0.97 0 0), oklch(0.15 0 0));
  --color-text: light-dark(oklch(0.145 0 0), oklch(0.93 0 0));
  --color-text-muted: light-dark(oklch(0.45 0 0), oklch(0.6 0 0));
  --color-border: light-dark(oklch(0.87 0 0), oklch(0.25 0 0));
}

/* user toggle */
[data-theme="light"] { color-scheme: light; }
[data-theme="dark"] { color-scheme: dark; }
```

`light-dark()` is Newly available; if the project supports older browsers, use a `[data-theme]` block per theme instead.

Dark mode rules:

- Remap, don't invert. No pure black backgrounds; use lightness around 0.1.
- Higher elevation means a lighter surface. Shadows barely show on dark backgrounds, so use surface steps or subtle borders.
- Reduce saturation slightly on colored elements.
- Set `<meta name="theme-color">` to the page background.

## 4. Visual Rules

- **Spacing:** use the scale, never arbitrary pixels.
- **Hierarchy:** size, weight, and color together. Three levels is usually enough: primary, secondary, muted.
- **Separation:** prefer spacing and background contrast over borders. When you use borders, keep them light and consistent.
- **Elevation:** five shadow levels; layered shadows (ambient + direct) read as real.
- **Radius:** 3–4 sizes (`sm`, `md`, `lg`, `full`). Don't mix radii within one component.
- **Text:** body line length 45–75 characters (`max-width: 65ch`), line height ~1.5 for body and 1.2–1.3 for headings, `tabular-nums` for numbers in columns.

## 5. Component States

Every data-driven component ships all of its states, not just the happy path:

- **Loading:** skeleton when the layout is known, spinner when it is not. Feedback within 100ms. Say what is loading ("Saving…").
- **Empty:** what this area is, how to fill it, and a call to action. Never broken UI.
- **Error:** plain language, what happened and how to fix it. Inline for form fields, linked with `aria-describedby`.
- **Disabled vs. read-only:** disabled controls can't take focus, so keyboard users can't reach them to learn why. Prefer read-only, or keep the control enabled and explain on submit.
- **Toasts:** one position app-wide; success auto-dismisses after 3–5s, errors persist until dismissed; announce with `aria-live`, don't move focus.

## 6. Accessibility Baseline

Accessibility is part of the component contract, not a later pass:

- Semantic HTML first; ARIA only where HTML has no element for it.
- Keyboard behavior follows the WAI-ARIA Authoring Practices pattern for that widget.
- Visible `:focus-visible` styles on everything interactive.
- Contrast: 4.5:1 for body text, 3:1 for large text and UI parts. Never color alone for state.
- Respect `prefers-reduced-motion`.

Focus management, roving tabindex, type-ahead, live regions, and a testing checklist are in [references/accessibility-patterns.md](references/accessibility-patterns.md). Per-component structure, ARIA, and keyboard maps are in [references/component-recipes.md](references/component-recipes.md).
