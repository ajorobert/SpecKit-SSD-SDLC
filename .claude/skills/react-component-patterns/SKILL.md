---
name: react-component-patterns
description: "Load when: designing or reviewing React component structure, decomposition, TypeScript prop interfaces, custom hooks, form handling with react-hook-form + Zod. Applies to customer portal and admin SPA."
---

# React Component Patterns

## Purpose
Production patterns for React component design — decomposition, TypeScript interfaces, custom hooks, data colocation, and form handling. Applies to both the Next.js customer portal and the React admin SPA. Ensures consistency, testability, and maintainability across all frontend surfaces.

## Core Rules

### Component Decomposition
* **Single responsibility**: one component = one visual concern or one interaction. Split when a component does more than one thing or exceeds ~150 lines.
* **Modular files**: each component in its own file. Avoid barrel exports from `components/ui/index.ts` — import directly from source files.
* **No god components**: a component should not own layout, fetch data, handle form state, and render results all at once. Extract each concern.
* **Co-location**: keep component-specific styles (if not Tailwind), tests, and types close to the component file. Move to shared only when reused in 3+ places.

```
features/listings/
├── components/
│   ├── ListingCard.tsx        # Presentational
│   ├── ListingCard.test.tsx
│   ├── ListingFilters.tsx     # Controlled filter form
│   └── ListingStatusBadge.tsx # Pure display
├── hooks/
│   ├── useListingFilters.ts   # Filter state logic
│   └── useListingMap.ts       # Map interaction logic
└── types.ts
```

### TypeScript Prop Interfaces
* Every component has an explicit `Readonly` TypeScript interface named `{ComponentName}Props`.
* No `any`. No `object`. No raw `{}`. Every prop typed.
* Optional props have `?` — required props do not. Default values via destructuring, not `defaultProps`.
* Use `React.ReactNode` for children, not `JSX.Element` (too narrow) or `any`.
* Extend HTML element types for wrapper components: `interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>`.
* Export prop interfaces for complex components — consumers may need them for composition.

```tsx
interface ListingCardProps {
  readonly listing: ListingSummary;
  readonly onSave?: (id: string) => void;
  readonly className?: string;
}

export function ListingCard({ listing, onSave, className }: ListingCardProps) { ... }
```

### Custom Hooks — Logic Extraction
* Extract event handlers, state management, and side effects from components into custom hooks in a `hooks/` directory.
* Hook naming: `use{Concern}` — descriptive of what it manages, not where it is used.
* A hook should return a stable interface: an object with named values and callbacks.
* Hooks must not render JSX. Components must not contain complex business logic.
* Avoid hook overuse: if a hook is only used in one component, consider whether it should be inlined or whether the component should be simplified.

```tsx
// hooks/useListingFilters.ts
export function useListingFilters(initialFilters: ListingFilters) {
  const [filters, setFilters] = useState(initialFilters);

  const updateFilter = useCallback(<K extends keyof ListingFilters>(
    key: K, value: ListingFilters[K]
  ) => setFilters(prev => ({ ...prev, [key]: value })), []);

  const resetFilters = useCallback(() => setFilters(initialFilters), [initialFilters]);

  return { filters, updateFilter, resetFilters };
}
```

### Data Separation
* Static content, label strings, and mock data belong in `src/data/` files — not inlined in components.
* API response types in `types.ts` per feature. Never use `any` for API response shapes.
* Derived/computed values from props: `useMemo` only when computation is non-trivial and proven expensive. Do not pre-optimise.

### Forms (react-hook-form + Zod)
* All forms use `react-hook-form` + `zod` schema validation. Never build custom form state with `useState`.
* Zod schema defines the form shape — TypeScript types inferred from schema (`z.infer<typeof schema>`).
* `useForm` with `zodResolver` — validation runs on submit and on field change after first submit attempt.
* Form structure with shadcn/ui:
  ```tsx
  <Form {...form}>
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <FormField control={form.control} name="title" render={({ field }) => (
        <FormItem>
          <FormLabel>Title</FormLabel>
          <FormControl><Input {...field} /></FormControl>
          <FormMessage />   {/* auto-renders validation error */}
        </FormItem>
      )} />
      <Button type="submit" disabled={form.formState.isSubmitting}>Save</Button>
    </form>
  </Form>
  ```
* Server-side validation errors: set field errors via `form.setError('fieldName', { message: '...' })` after API call.
* Pending state: use `form.formState.isSubmitting` to disable submit button — never manage pending state separately.

### Presentational vs Container Split
* **Presentational**: receives all data via props. No fetching, no direct store access. Easily testable.
* **Container / feature component**: fetches data (via TanStack Query hook or loader), accesses Zustand store, passes data to presentational children.
* Rule: if a component is tested, it should be presentational (data injected as props). Containers are integration-tested.

### Controlled vs Uncontrolled
* Use **controlled** components (value + onChange) for any input that participates in form state or requires cross-component coordination.
* Use **uncontrolled** (refs) only for non-form interactions (focus management, scroll, third-party library integration).
* Never mix controlled and uncontrolled on the same input — React will warn, and behaviour is unpredictable.

### Composition over Configuration
* Prefer composable APIs over prop-driven conditional rendering.
* If a component has more than 2 boolean `show*` / `hide*` / `with*` props, refactor to a compound component or slot pattern.
* Use `children` or named slot props (`headerSlot`, `footerSlot`) for layout flexibility.
* Use `asChild` (Radix/shadcn pattern) to render a component's behaviour on a custom element.

## Patterns / Examples

### Presentational component with full typing
```tsx
// features/listings/components/ListingStatusBadge.tsx
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

type ListingStatus = 'active' | 'pending' | 'inactive' | 'archived';

interface ListingStatusBadgeProps {
  readonly status: ListingStatus;
  readonly className?: string;
}

const variantMap: Record<ListingStatus, 'default' | 'secondary' | 'outline' | 'destructive'> = {
  active:   'default',
  pending:  'secondary',
  inactive: 'outline',
  archived: 'destructive',
};

export function ListingStatusBadge({ status, className }: ListingStatusBadgeProps) {
  return (
    <Badge variant={variantMap[status]} className={cn('capitalize', className)}>
      {status}
    </Badge>
  );
}
```

### Form with Zod validation
```tsx
const createListingSchema = z.object({
  title:       z.string().min(5, 'Title must be at least 5 characters').max(120),
  price:       z.number().positive('Price must be greater than 0'),
  description: z.string().optional(),
});

type CreateListingForm = z.infer<typeof createListingSchema>;

export function CreateListingForm({ onSuccess }: { onSuccess: () => void }) {
  const form = useForm<CreateListingForm>({
    resolver: zodResolver(createListingSchema),
    defaultValues: { title: '', price: 0, description: '' },
  });
  const mutation = useCreateListing();

  async function onSubmit(data: CreateListingForm) {
    const result = await mutation.mutateAsync(data);
    if (result.success) onSuccess();
    else form.setError('title', { message: result.error });
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField control={form.control} name="title" render={({ field }) => (
          <FormItem>
            <FormLabel>Title</FormLabel>
            <FormControl><Input placeholder="Listing title" {...field} /></FormControl>
            <FormMessage />
          </FormItem>
        )} />
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Saving…' : 'Create Listing'}
        </Button>
      </form>
    </Form>
  );
}
```

## When to Use
* Any React component design decision (customer portal or admin SPA)
* Form implementation with validation
* Custom hook extraction
* Reviewing component structure, decomposition, or TypeScript props
* Implementing new components or feature modules

## When NOT to Use
* React Native components (see `react-native-patterns`)
* Styling decisions (see `frontend-design-system`)
* State management architecture (see `zustand-state-management`)
