---
name: accessibility-standards
description: "Load when: implementing or reviewing any frontend UI for accessibility. Two parts — Part A is a cross-cutting a11y core (POUR, target size, contrast, colour-independence, reduced-motion, the blocking-issue-= -not-shippable gate) that applies to ALL surfaces including React Native; Part B is a web-DOM implementation appendix (semantic HTML, ARIA, focus, forms) for web/admin ONLY."
when_to_load:
  - Implementing or reviewing any frontend UI (all surfaces load Part A)
  - Web (customer-portal) or admin (tagin-console) UI — load Part A + Part B
  - React Native (vendor-app) UI — load Part A ONLY; native implementation lives in react-native-patterns §2.11
  - User acceptance testing or quality-gate a11y verification
references:
  - react-native-patterns
---

# Accessibility Standards (WCAG 2.2 AA)

**How to load this skill by surface (see `.specify/memory/projects/{surface}/project.md`):**
- **web / admin (Next.js):** load **Part A + Part B**.
- **mobile (React Native):** load **Part A only**. Part B is DOM/ARIA and does
  **not** apply to React Native — the native implementation of these same
  cross-cutting truths lives in `react-native-patterns §2.11`
  (`accessibilityRole` / `accessibilityLabel`, not DOM `aria-*`).

---

# Part A — Cross-cutting accessibility core (ALL surfaces, incl. React Native)

These are surface-neutral truths. They hold on web, admin, and mobile. React
Native realises them through native APIs (`react-native-patterns §2.11`); web
realises them through the DOM (Part B).

### WCAG 2.2 Compliance Target
* Level AA is the minimum for all production features. Level AAA where feasible
  (especially for core user journeys).
* **POUR principles** — every UI must be:
  * **Perceivable**: all information available to all senses (not colour-only, alt text / accessible labels, captions).
  * **Operable**: all functionality operable without a mouse; no traps; adequate time.
  * **Understandable**: content is readable; inputs are labelled; errors are clear.
  * **Robust**: works with current and future assistive technologies (screen readers on every platform).

### Target size
* Minimum **24×24** CSS px (web) / density-independent px (native) for all
  interactive targets. Preferred: **44×44**.
* Dragging interactions must have a non-drag alternative.

### Colour & contrast
| Text type | AA minimum | AAA |
|---|---|---|
| Normal text (< 18pt / < 14pt bold) | 4.5:1 | 7:1 |
| Large text (≥ 18pt / ≥ 14pt bold) | 3:1 | 4.5:1 |
| UI components and graphical objects | 3:1 | — |

* **Never convey information by colour alone** — always pair colour with text,
  icon, or pattern. Error states = colour + icon + message text (three channels).
* Verify token combinations in both light and dark themes.

### Motion
* Respect the user's reduced-motion preference on every surface
  (`prefers-reduced-motion` on web; the equivalent OS setting on native). All
  animations must stop or simplify when it is set.

### Content & forms (surface-neutral intent)
* Every input has an associated, programmatically-exposed **label** — never a
  placeholder-only label.
* Required fields are marked by more than colour.
* Error messages are **specific** ("Email must include @", not "Invalid email"),
  associated with their field, and announced to assistive tech.
* Do not force re-entry of information already provided in the session; pre-fill
  where possible.

### The shippability gate
* Accessibility review is part of user acceptance testing. **A story is not
  shippable with blocking a11y issues** — on any surface.
* Testing intent (realised per surface): automated scan (catches ~35%), full
  keyboard/switch traversal, screen-reader pass (NVDA/VoiceOver/TalkBack), and a
  reduced-motion pass.

---

# Part B — Web-DOM implementation appendix (web / admin ONLY)

> **Do NOT apply Part B to React Native.** It is HTML/DOM/ARIA-specific. For
> native, `react-native-patterns §2.11` implements Part A's core using native
> accessibility APIs. Loading Part B on mobile is a defect (cross-stack
> hallucination risk — e.g. applying DOM `aria-*` to native components).

Production accessibility for the web frontends (customer portal + admin console).
Enforces WCAG 2.2 AA in the DOM.

### Semantic HTML — First Defence
* Use the correct HTML element for the job: `<button>` for actions, `<a>` for navigation, `<nav>`, `<main>`, `<header>`, `<footer>`, `<section>`, `<article>` for landmarks.
* Heading hierarchy: one `<h1>` per page; `<h2>–<h6>` follow logical document order. Never skip levels (h1 → h3).
* Lists: `<ul>/<ol>` for groups of related items. Never fake lists with `<div>` + CSS.
* Tables: `<thead>`, `<tbody>`, `<th scope="col|row">` for data tables. Do not use tables for layout.
* Never use `<div>` or `<span>` where a semantic element exists. Divs are for grouping with no semantic meaning.

### Keyboard Navigation — All Functionality Must Be Keyboard-Accessible
* Tab order follows visual reading order. Never use `tabindex > 0` — it disrupts natural tab flow.
* `tabindex="0"`: add to non-focusable elements that need programmatic focus. `tabindex="-1"`: for elements that receive programmatic focus only.
* Every interactive element must be reachable and operable by keyboard alone.
* Keyboard shortcuts for key UI patterns:
  * `Tab`/`Shift+Tab`: move between interactive elements.
  * `Enter`/`Space`: activate buttons and links.
  * `Arrow keys`: navigate within menus, tabs, radio groups, listboxes.
  * `Escape`: close dialogs, dropdowns, tooltips.
* **No keyboard traps**: users must always be able to move focus away from any component. Exception: modal dialogs — focus is intentionally trapped inside and released on close.

### Focus Management
* Never remove focus outlines: `outline: none` is forbidden. Provide a custom `:focus-visible` style instead.
* Minimum focus indicator: 2px solid with 3:1 contrast ratio between indicator colour and background.
* When opening a modal/dialog: move focus to the modal (first focusable element or the dialog element itself).
* When closing a modal: return focus to the trigger element that opened it.
* Route navigation (SPA/App Router): move focus to the page `<h1>` or a skip-to-content landmark after navigation.
* Skip links: `<a href="#main-content" class="sr-only focus:not-sr-only">Skip to main content</a>` — first focusable element on every page.

### ARIA — Use Sparingly, Correctly
* First rule of ARIA: use the native HTML element if one exists. ARIA is for cases where HTML semantics are insufficient.
* Required attributes:
  * `aria-label`: names an element when visible text label is absent (icon buttons, search inputs).
  * `aria-labelledby`: references a visible heading/label by ID.
  * `aria-describedby`: links additional descriptive text (hint text, error messages).
  * `aria-live="polite"`: announces dynamic content updates (toast notifications, status messages). `assertive` only for critical alerts.
  * `aria-hidden="true"`: removes decorative elements from the accessibility tree (icons inside labelled buttons).
  * `aria-expanded`, `aria-haspopup`, `aria-controls`: for disclosure widgets (dropdown, accordion).
  * `aria-current="page"`: for active navigation links.
  * `aria-invalid="true"` + `aria-describedby` pointing to error message: for invalid form fields.
* Never use `role="presentation"` or `aria-hidden` on focusable elements.
* Never add ARIA roles that duplicate the element's native semantics (`role="button"` on `<button>`).

### Colour Contrast (DOM specifics)
* Verify contrast ratios for all shadcn/ui token combinations in both light and dark mode.
* Use browser DevTools or axe-core to check programmatically — do not rely on visual judgement.
* (Ratios themselves are in Part A.)

### WCAG 2.2 Additions (DOM specifics)
* **Focus not obscured**: focused element must not be fully hidden by sticky headers, cookie banners, or other fixed elements. Use `scroll-margin-top` to account for sticky headers.
* **Accessible authentication**: support paste on all password fields. Provide alternatives to cognitive tests (puzzles, image CAPTCHAs).
* **Consistent help**: if help/support UI appears on multiple pages, it must appear in the same location each time.
* (Target size, dragging alternatives, and redundant entry are in Part A.)

### Form Accessibility (DOM)
* Every input has a visible `<label>` associated via `for`/`id` or wrapping. No placeholder-only labels.
* Required fields: `required` attribute + visual indicator. Never rely only on colour to mark required.
* Error messages:
  * Appear below the relevant input.
  * Described via `aria-describedby` on the input pointing to the error element's ID.
  * `aria-invalid="true"` set on the input when invalid.
  * Error text is specific: "Email must include @" not "Invalid email".
* Form submission errors: focus moves to the error summary at the top of the form, or to the first errored field.
* Success messages: announced via `aria-live="polite"` region.

### Images & Media (DOM)
* Informative images: descriptive `alt` attribute (describes what the image conveys, not what it looks like).
* Decorative images: `alt=""` (empty string). Never omit `alt` entirely.
* Icon buttons: `aria-label` on the button element. `aria-hidden="true"` on the icon itself.
* Complex images (charts, diagrams): `alt` with brief description + long description via `aria-describedby` or adjacent text.
* Video: captions required for all spoken content. Transcript for all audio-only content.

### Testing Methodology (web)
* **Automated** (catches ~35% of issues): axe-core (via `@axe-core/react` in dev, Playwright axe in CI), Lighthouse accessibility audit.
* **Keyboard** (manual): navigate the entire feature using Tab, Shift+Tab, Arrow keys, Enter, Escape only. Every interaction must complete.
* **Screen reader** (manual): NVDA + Chrome (Windows), VoiceOver + Safari (macOS/iOS). Verify all content is announced correctly.
* **Zoom**: test at 200% and 400% browser zoom — no horizontal scrolling, no overlapping content.
* **Reduced motion**: test with `prefers-reduced-motion: reduce` media query active. All animations must stop or simplify.

## Patterns / Examples (web / admin)

### Icon button (correct)
```tsx
<Button variant="ghost" size="icon" aria-label="Save listing">
  <Heart className="size-4" aria-hidden="true" />
</Button>
```

### Form field with error
```tsx
<FormField control={form.control} name="email" render={({ field, fieldState }) => (
  <FormItem>
    <FormLabel>Email address <span aria-hidden="true">*</span></FormLabel>
    <FormControl>
      <Input
        type="email"
        aria-required="true"
        aria-invalid={fieldState.invalid}
        aria-describedby={fieldState.invalid ? 'email-error' : undefined}
        {...field}
      />
    </FormControl>
    {fieldState.invalid && (
      <FormMessage id="email-error" role="alert">{fieldState.error?.message}</FormMessage>
    )}
  </FormItem>
)} />
```

### Skip link
```tsx
// root layout
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-background focus:text-foreground focus:rounded-md focus:shadow-lg"
>
  Skip to main content
</a>
<main id="main-content">{children}</main>
```

### Live region for toast announcements
```tsx
// Announce toasts to screen readers
<div aria-live="polite" aria-atomic="true" className="sr-only" id="toast-announcer">
  {latestToastMessage}
</div>
```

### Reduced motion
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

## When to Use
* Implementing any frontend UI — accessibility is not an afterthought (Part A everywhere; Part B on web/admin)
* User acceptance testing — blocking issues prevent ship
* Quality gate verification — accessibility audit is mandatory
* Frontend code review — WCAG 2.2 AA items are on the checklist

## When NOT to Use
* Backend code, API design, or database schema.
* **Part B only:** React Native mobile app — do not apply DOM/ARIA to native. RN
  consumes **Part A** and implements it via `react-native-patterns §2.11`
  (`accessibilityRole` / `accessibilityLabel`).
