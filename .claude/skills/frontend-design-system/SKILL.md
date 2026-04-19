---
name: frontend-design-system
description: "Load when: implementing or reviewing UI styling, Tailwind v4 configuration, shadcn/ui component usage, dark mode, layout systems, or design tokens."
---

# Frontend Design System (Tailwind v4 + shadcn/ui)

## Purpose
Production styling system for all web frontends (customer portal and admin SPA). Tailwind CSS v4 with CSS-first configuration, HSL design tokens, shadcn/ui component library, CVA-based variants, dark mode, and responsive layout patterns. Covers the single source of truth for colours, spacing, typography, and component structure.

## Core Rules

### Tailwind v4 — CSS-First Configuration
* No `tailwind.config.ts`. All configuration lives in `src/global.css` (or `app/globals.css` for Next.js).
* Import Tailwind: `@import "tailwindcss"` — replaces `@tailwind base/components/utilities`.
* Use `@tailwindcss/vite` plugin (Vite/admin) or built-in Next.js integration — not PostCSS for web projects.
* Delete any existing `tailwind.config.ts` after migration. Its presence conflicts with v4.

### Design Tokens (HSL — single theme light/dark)
Four-step pattern — mandatory order:

```css
/* Step 1: Define CSS variables at root (HSL values without hsl() wrapper) */
:root {
  --background:        0 0% 100%;
  --foreground:        240 10% 3.9%;
  --primary:           240 5.9% 10%;
  --primary-foreground:0 0% 98%;
  --secondary:         240 4.8% 95.9%;
  --secondary-foreground: 240 5.9% 10%;
  --muted:             240 4.8% 95.9%;
  --muted-foreground:  240 3.8% 46.1%;
  --accent:            240 4.8% 95.9%;
  --accent-foreground: 240 5.9% 10%;
  --destructive:       0 84.2% 60.2%;
  --border:            240 5.9% 90%;
  --input:             240 5.9% 90%;
  --ring:              240 5.9% 10%;
  --radius:            0.5rem;
}

/* Step 2: Dark mode variable overrides */
.dark {
  --background:        240 10% 3.9%;
  --foreground:        0 0% 98%;
  --primary:           0 0% 98%;
  --primary-foreground:240 5.9% 10%;
  /* ... other dark overrides */
}

/* Step 3: Map to Tailwind utilities with @theme inline */
@theme inline {
  --color-background:        hsl(var(--background));
  --color-foreground:        hsl(var(--foreground));
  --color-primary:           hsl(var(--primary));
  --color-primary-foreground:hsl(var(--primary-foreground));
  --color-secondary:         hsl(var(--secondary));
  --color-muted:             hsl(var(--muted));
  --color-muted-foreground:  hsl(var(--muted-foreground));
  --color-accent:            hsl(var(--accent));
  --color-destructive:       hsl(var(--destructive));
  --color-border:            hsl(var(--border));
  --color-input:             hsl(var(--input));
  --color-ring:              hsl(var(--ring));
  --radius-DEFAULT:          var(--radius);
}

/* Step 4: Base styles using variables directly */
@layer base {
  * { @apply border-border; }
  body { @apply bg-background text-foreground; }
}
```

* Use `@theme inline` for single light/dark theme. Use `@theme` (without `inline`) only for multi-theme systems where CSS variables must remain reactive.
* Never double-wrap: `hsl(hsl(var(--color)))` is an error.
* Never use arbitrary Tailwind values (`bg-[#aabbcc]`) for brand colours — always use token aliases.

### Dark Mode
* Toggle dark mode via `.dark` class on `<html>`. Never use `media` strategy in production — class strategy allows user override.
* Next.js: use `next-themes` with `attribute="class"`. Admin SPA: toggle class on `document.documentElement`.
* All components use semantic token classes (`bg-background`, `text-muted-foreground`) — never raw colour classes (`bg-white`, `text-gray-500`).
* Test both modes as part of every component review.

### shadcn/ui Component Rules
* `npx shadcn@latest add <component>` — components land in `components/ui/`. You own the code.
* Never override component colours via `className` on the component root — use CSS variable overrides instead.
* Replace `space-x-*` / `space-y-*` with `flex gap-*` — more predictable behaviour.
* Use `size-*` when width and height are equal: `size-10` not `w-10 h-10`.
* Use `cn()` (`clsx` + `tailwind-merge`) for all conditional class composition.
* Semantic colours always: `bg-background`, `text-foreground`, `text-muted-foreground`, `bg-primary`, `text-primary-foreground`. Never raw colours on UI components.
* Never manually set `z-index` on overlay components (Dialog, Sheet, Drawer, DropdownMenu) — shadcn handles stacking internally.
* `Avatar` always needs `AvatarFallback`. `Dialog`/`Sheet`/`Drawer` always need `Title` for accessibility.
* `Card` full structure: `Card > CardHeader > CardTitle + CardDescription > CardContent > CardFooter`.
* Forms: `Form > FormField > FormItem > FormLabel + FormControl + FormMessage`. Never skip levels.
* Validation: `data-invalid` on `Field`, `aria-invalid` on the input control.

### Component Variants (CVA)
* Use `cva` (class-variance-authority) for components with multiple visual states.
* Define variants as full Tailwind class strings — not token references inside `cva`.

```tsx
const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default:     'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-white hover:bg-destructive/90',
        outline:     'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        ghost:       'hover:bg-accent hover:text-accent-foreground',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm:      'h-9 px-3',
        lg:      'h-11 px-8',
        icon:    'size-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  }
);
```

### Layout System
* Mobile-first responsive design. Base styles target mobile; add `sm:`, `md:`, `lg:`, `xl:` for larger breakpoints.
* Grid: `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4` for card grids. Use `auto-fill` for unknown item counts.
* Flexbox: `flex items-center gap-2` for horizontal groups. Avoid `space-x-*` (use `gap-*`).
* Prevent text overflow in flex children: always add `min-w-0` to flex children that contain truncated text.
* Full-bleed sections (break out of container): negative margin `-mx-4 px-4` or container-relative.
* Sticky header: `sticky top-0 z-50 bg-background/80 backdrop-blur-sm`.
* Container queries: use `@container` for components that adapt to their container, not viewport.
* Sidebar layout: CSS Grid with `grid-cols-[240px_1fr]` — not absolute positioning.

### Typography
* Font loading: `next/font` for Next.js (zero layout shift, self-hosted). Vite: preload via `<link rel="preload">`.
* Text scale: use Tailwind's type scale (`text-sm`, `text-base`, `text-lg`, `text-xl`, `text-2xl`). Do not introduce arbitrary sizes.
* Fluid type: `text-[clamp(1rem,5vw,1.5rem)]` only for display headings — not body text.
* Line length: `max-w-prose` for readable text blocks (65ch).

### Animations & Transitions
* CSS transitions for hover/focus states: `transition-colors`, `transition-opacity`, `transition-transform`. Duration: 150ms for micro-interactions, 200ms–300ms for layout transitions.
* Respect reduced motion: `motion-safe:` and `motion-reduce:` variants. Always pair animated elements with a `motion-reduce:` that removes or freezes the animation.
* Page-level transitions: Tailwind `transition-*` + CSS `@starting-style` for enter animations. No JS-driven animations for simple enter/exit.
* Heavy animations: Framer Motion only if explicitly required by design spec — not by default.

## Patterns / Examples

### Custom-themed shadcn card
```tsx
// components/listing-card.tsx
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

interface ListingCardProps {
  listing: ListingSummary;
  className?: string;
}

export function ListingCard({ listing, className }: ListingCardProps) {
  return (
    <Card className={cn('hover:shadow-md transition-shadow', className)}>
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="text-base leading-snug line-clamp-2">
            {listing.title}
          </CardTitle>
          <Badge variant={listing.status === 'active' ? 'default' : 'secondary'}>
            {listing.status}
          </Badge>
        </div>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-bold text-primary">{listing.formattedPrice}</p>
        <p className="text-sm text-muted-foreground mt-1">{listing.location}</p>
      </CardContent>
    </Card>
  );
}
```

### Responsive grid layout
```tsx
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
  {listings.map(l => <ListingCard key={l.id} listing={l} />)}
</div>
```

### Dark mode toggle (Next.js)
```tsx
'use client';
import { useTheme } from 'next-themes';
import { Button } from '@/components/ui/button';
import { Sun, Moon } from 'lucide-react';

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  return (
    <Button variant="ghost" size="icon"
      onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
      aria-label="Toggle theme">
      <Sun className="size-4 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
      <Moon className="absolute size-4 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
    </Button>
  );
}
```

## When to Use
* Any web frontend styling decision (customer portal or admin SPA)
* Adding or customising shadcn/ui components
* Defining colour tokens, typography, or layout patterns
* Dark mode implementation
* Implementing or reviewing UI styling, theming, or component variants

## When NOT to Use
* React Native mobile styling (see `react-native-patterns` — NativeWind has different constraints)
* Backend styling or email templates
