# Design Token System

Token system implementation referenced in SKILL.md. Two layers: primitive (raw values) and semantic (assigned meaning). Use semantic tokens directly in components — a third "component token" layer is rarely needed and adds indirection without value. All examples use plain CSS custom properties — adapt to Tailwind `@theme`, StyleX variables, or Panda tokens as needed.

## Color Tokens

### Primitive: 12-Step Color Scale (Per Hue)

Each step has a specific UI purpose (following the Radix Colors model):

| Step | Purpose | Example Use |
|------|---------|-------------|
| 1 | App background | Page background |
| 2 | Subtle background | Sidebar, card |
| 3 | UI element background | Button default |
| 4 | Hovered UI element | Button hover |
| 5 | Active/selected element | Button active, selected row |
| 6 | Subtle borders | Separator, divider |
| 7 | UI element border | Input border, focus ring |
| 8 | Hovered border | Input hover border |
| 9 | Solid background | Primary button fill, badge |
| 10 | Hovered solid | Primary button hover |
| 11 | Low-contrast text | Secondary text, labels |
| 12 | High-contrast text | Headings, body text |

```css
:root {
  /* Gray scale (neutral) */
  --gray-1: oklch(0.985 0 0);
  --gray-2: oklch(0.97 0 0);
  --gray-3: oklch(0.94 0 0);
  --gray-4: oklch(0.91 0 0);
  --gray-5: oklch(0.87 0 0);
  --gray-6: oklch(0.83 0 0);
  --gray-7: oklch(0.77 0 0);
  --gray-8: oklch(0.65 0 0);
  --gray-9: oklch(0.55 0 0);
  --gray-10: oklch(0.50 0 0);
  --gray-11: oklch(0.40 0 0);
  --gray-12: oklch(0.145 0 0);

  /* Blue scale (primary) */
  --blue-1: oklch(0.985 0.02 250);
  --blue-2: oklch(0.965 0.03 250);
  --blue-3: oklch(0.93 0.06 250);
  --blue-4: oklch(0.88 0.08 250);
  --blue-5: oklch(0.83 0.10 250);
  --blue-6: oklch(0.77 0.12 250);
  --blue-7: oklch(0.70 0.14 250);
  --blue-8: oklch(0.62 0.17 250);
  --blue-9: oklch(0.55 0.20 250);
  --blue-10: oklch(0.50 0.20 250);
  --blue-11: oklch(0.42 0.17 250);
  --blue-12: oklch(0.25 0.10 250);

  /* Red scale (destructive) */
  --red-9: oklch(0.55 0.22 25);
  --red-10: oklch(0.50 0.22 25);
  --red-11: oklch(0.42 0.18 25);
  /* ... same 12-step pattern */
}
```

### Semantic: Purpose-Based Tokens

```css
:root {
  /* Backgrounds */
  --color-bg: var(--gray-1);
  --color-bg-subtle: var(--gray-2);
  --color-bg-muted: var(--gray-3);

  /* Foreground / text */
  --color-text: var(--gray-12);
  --color-text-muted: var(--gray-11);
  --color-text-subtle: var(--gray-9);

  /* Borders */
  --color-border: var(--gray-6);
  --color-border-strong: var(--gray-8);

  /* Primary */
  --color-primary: var(--blue-9);
  --color-primary-hover: var(--blue-10);
  --color-primary-text: oklch(1 0 0);

  /* Destructive */
  --color-destructive: var(--red-9);
  --color-destructive-hover: var(--red-10);
  --color-destructive-text: oklch(1 0 0);

  /* Focus */
  --color-focus-ring: var(--blue-7);
}
```

### Dark Mode Mapping

Don't invert — remap. Higher steps (9-12) in light mode often map to lower steps (1-4) in dark mode:

```css
.dark {
  --color-bg: oklch(0.10 0 0);
  --color-bg-subtle: oklch(0.13 0 0);
  --color-bg-muted: oklch(0.17 0 0);

  --color-text: oklch(0.93 0 0);
  --color-text-muted: oklch(0.65 0 0);
  --color-text-subtle: oklch(0.50 0 0);

  --color-border: oklch(0.25 0 0);
  --color-border-strong: oklch(0.35 0 0);

  /* Primary stays vibrant, slight desaturation */
  --color-primary: oklch(0.60 0.18 250);
  --color-primary-hover: oklch(0.65 0.18 250);
  --color-primary-text: oklch(0.10 0 0);

  --color-focus-ring: oklch(0.60 0.15 250);
}
```

## Spacing Scale

4px-based geometric scale. Use t-shirt sizes in code for readability:

```css
:root {
  --space-0: 0;
  --space-px: 1px;
  --space-0-5: 0.125rem;  /* 2px */
  --space-1: 0.25rem;     /* 4px */
  --space-1-5: 0.375rem;  /* 6px */
  --space-2: 0.5rem;      /* 8px */
  --space-3: 0.75rem;     /* 12px */
  --space-4: 1rem;        /* 16px */
  --space-5: 1.25rem;     /* 20px */
  --space-6: 1.5rem;      /* 24px */
  --space-8: 2rem;        /* 32px */
  --space-10: 2.5rem;     /* 40px */
  --space-12: 3rem;       /* 48px */
  --space-16: 4rem;       /* 64px */
  --space-20: 5rem;       /* 80px */
  --space-24: 6rem;       /* 96px */
}
```

## Typography Scale

Modular scale (1.25 ratio — Major Third) with fluid sizing:

```css
:root {
  --text-xs: clamp(0.75rem, 0.7rem + 0.25vw, 0.8rem);
  --text-sm: clamp(0.8125rem, 0.75rem + 0.3vw, 0.875rem);
  --text-base: clamp(0.875rem, 0.8rem + 0.4vw, 1rem);
  --text-lg: clamp(1rem, 0.9rem + 0.5vw, 1.125rem);
  --text-xl: clamp(1.125rem, 1rem + 0.6vw, 1.25rem);
  --text-2xl: clamp(1.25rem, 1rem + 1.2vw, 1.5rem);
  --text-3xl: clamp(1.5rem, 1.1rem + 2vw, 1.875rem);
  --text-4xl: clamp(1.875rem, 1.2rem + 3vw, 2.25rem);

  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;

  --tracking-tight: -0.025em;
  --tracking-normal: 0;
  --tracking-wide: 0.025em;

  --font-sans: system-ui, -apple-system, sans-serif;
  --font-mono: ui-monospace, "Cascadia Code", "Fira Code", monospace;
}
```

## Shadow / Elevation Scale

Layered shadows (ambient + directional) for realism. 5 levels:

```css
:root {
  --shadow-xs: 0 1px 2px 0 oklch(0 0 0 / 0.05);
  --shadow-sm: 0 1px 3px 0 oklch(0 0 0 / 0.1),
               0 1px 2px -1px oklch(0 0 0 / 0.1);
  --shadow-md: 0 4px 6px -1px oklch(0 0 0 / 0.1),
               0 2px 4px -2px oklch(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px oklch(0 0 0 / 0.1),
               0 4px 6px -4px oklch(0 0 0 / 0.1);
  --shadow-xl: 0 20px 25px -5px oklch(0 0 0 / 0.1),
               0 8px 10px -6px oklch(0 0 0 / 0.1);
}
```

In dark mode, shadows are invisible on dark backgrounds. Use border or lighter surfaces instead:

```css
.dark {
  --shadow-xs: none;
  --shadow-sm: 0 0 0 1px oklch(1 0 0 / 0.06);
  --shadow-md: 0 0 0 1px oklch(1 0 0 / 0.08);
  /* Or skip shadows entirely and use surface color for elevation */
}
```

## Border Radius Scale

```css
:root {
  --radius-sm: 0.25rem;   /* 4px — small elements (badges, tags) */
  --radius-md: 0.5rem;    /* 8px — default (buttons, inputs, cards) */
  --radius-lg: 0.75rem;   /* 12px — large containers (modals, panels) */
  --radius-xl: 1rem;      /* 16px — prominent elements */
  --radius-full: 9999px;  /* pills, avatars */
}
```

## Z-Index Scale

Named layers prevent z-index wars:

```css
:root {
  --z-base: 0;
  --z-dropdown: 50;
  --z-sticky: 100;
  --z-overlay: 200;
  --z-modal: 300;
  --z-popover: 400;
  --z-toast: 500;
  --z-tooltip: 600;
}
```

## Sources

- [Radix Colors](https://www.radix-ui.com/colors) — 12-step color scale system
- [shadcn/ui theming](https://ui.shadcn.com/docs/theming) — OKLCH-based CSS variable theming
- [Tailwind v4 @theme](https://tailwindcss.com/blog/tailwindcss-v4) — CSS-first token configuration
- [W3C Design Tokens](https://www.w3.org/community/design-tokens) — Emerging token standard
- [Refactoring UI](https://www.refactoringui.com) — Visual design constraints
