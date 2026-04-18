---
name: react-admin-patterns
description: "Load when: implementing or reviewing the admin SPA (React + Vite + Tanstack Router). Production React patterns, bundle optimisation, parallel data fetching, re-render control, error boundaries, view transitions. Loaded by: sk.implement (frontend/admin), sk.plan, sk.review (frontend)."
---

# React Admin SPA Patterns (Vite + Tanstack Router)

## Purpose
Production patterns for the internal admin SPA built with React, Vite, and Tanstack Router. Covers project structure, routing conventions, data fetching without waterfalls, bundle optimisation, re-render control, error boundaries, and view transitions for navigation. Keycloak auth integrated via OIDC.

## Core Rules

### Project Structure
```
src/
├── routes/              # Tanstack Router route files
│   ├── __root.tsx       # Root layout, auth guard, global error boundary
│   ├── index.tsx        # Dashboard
│   ├── listings/
│   │   ├── index.tsx    # Listings list
│   │   └── $id.tsx      # Listing detail (dynamic segment)
│   └── users/
├── features/            # Feature-scoped modules
│   └── listings/
│       ├── api.ts       # TanStack Query hooks for this feature
│       ├── components/  # Feature-specific components
│       └── types.ts
├── components/          # Shared UI components (shadcn/ui wrappers, layouts)
├── lib/
│   ├── api-client.ts    # Axios/fetch instance with Keycloak token injection
│   └── query-client.ts  # TanStack Query client config
├── stores/              # Zustand stores (global state only)
└── hooks/               # Shared custom hooks
```

### Routing (Tanstack Router)
* Use **file-based routing** — one file per route segment in `src/routes/`.
* `loader` functions for route-level data fetching — runs before render, integrates with TanStack Query.
* `errorComponent` per route — scoped error boundaries that do not crash the whole SPA.
* `pendingComponent` for route-level loading state — shown while `loader` is running.
* Auth guard in `__root.tsx` `beforeLoad`: redirect to Keycloak login if session is absent.
* Nested layouts via nested route files. Never duplicate layout code across routes.
* Use `useNavigate` and `Link` from Tanstack Router — never `window.location`.

### Data Fetching (TanStack Query)
* TanStack Query is the data fetching layer — not `useEffect` + `useState` + `fetch`.
* Define query keys as typed constants in `features/{feature}/api.ts`.
* Prefetch in route `loader` via `queryClient.ensureQueryData` — data is ready before the component mounts, eliminating loading spinners on navigation.
* Parallel queries: `useQueries` for independent data requirements — never sequential awaits.
* Mutations: `useMutation` with `onSuccess` callbacks that invalidate relevant query keys.
* Stale time: 60 seconds for listing data; 5 minutes for reference data (categories, statuses).
* Never use `isLoading` + conditional render in leaf components — data is guaranteed by route loader.

### Eliminating Waterfalls
* **Critical**: waterfall = Component A mounts → fetches → renders → Component B mounts → fetches. Eliminate at the route loader level.
* Route loader: `Promise.all` for all data the route needs — single parallel fetch round trip.
* Never fetch in `useEffect`. Never fetch inside child components that depend on parent data.
* Exception: infinite scroll / pagination — triggered by user action, not on mount.

### Re-render Optimisation
* Memoisation: use `memo`, `useMemo`, `useCallback` only where profiling shows a real problem. Do not pre-optimise.
* Zustand selectors: use `useShallow` for object selectors — prevents re-render when reference changes but value is equal.
* List rendering: always provide stable, unique `key` props. Never use array index as key for lists that reorder or filter.
* Avoid creating new object/array literals in JSX or render functions — they break `memo` equality checks.
* Expensive computations: `useMemo` with accurate dependency array. If deps are unstable, the memo is useless.

### Bundle Optimisation
* Dynamic imports for heavy features: `const ChartComponent = lazy(() => import('./ChartComponent'))`.
* Avoid barrel file imports (`import { x, y } from '@/components'`) — import directly from source files to enable tree-shaking.
* Vite code-splitting: Tanstack Router automatically code-splits per route. No manual configuration needed.
* Third-party libraries: prefer modular imports. `import { debounce } from 'lodash-es'` not `import _ from 'lodash'`.
* Analyse bundle: `vite-bundle-visualizer` on CI — alert if main chunk exceeds 250KB gzipped.

### Error Boundaries
* Every route has an `errorComponent` — never let unhandled errors crash the full SPA.
* Error components show: friendly message, error code (not stack trace), retry button, navigation to dashboard.
* Network errors (API down, 503): show retry with exponential backoff indicator.
* Auth errors (401): redirect to Keycloak login. Do not show error page.
* Validation/business errors (400, 409): show inline in the form, not as error boundary.

### Keycloak Auth (OIDC in SPA)
* Use `keycloak-js` SDK with silent SSO (`checkLoginIframe: false` for iframe-blocked environments).
* Token refresh: auto-refresh via Keycloak's `onTokenExpired` callback before API calls fail.
* Inject bearer token in the API client as an Axios request interceptor — not in individual call sites.
* Logout: call `keycloak.logout()` — clears local state and Keycloak session.
* Never store the access token in `localStorage`. Use in-memory only (Keycloak JS SDK handles this).
* Role-based UI: read roles from `keycloak.tokenParsed.realm_access.roles`. Hide/show UI elements based on roles — but always enforce on backend too.

### View Transitions (Admin Navigation)
* Use the browser's native View Transition API for route navigation to communicate spatial relationships.
* Apply for: navigating deeper (list → detail), navigating back (detail → list), panel slides.
* Use `startViewTransition` in Tanstack Router's `onNavigate` callback — not ad-hoc per component.
* Always include `@media (prefers-reduced-motion: reduce)` CSS to disable transitions for accessibility.
* Keep transitions under 300ms. Use `cross-fade` for lateral navigation; directional slide for depth.
* Do not animate for background data refreshes — only for user-initiated navigation.

## Patterns / Examples

### Route with loader (prefetch + parallel)
```tsx
// src/routes/listings/$id.tsx
import { createFileRoute } from '@tanstack/react-router';
import { listingQueryOptions, listingActivityQueryOptions } from '@/features/listings/api';

export const Route = createFileRoute('/listings/$id')({
  loader: async ({ params, context: { queryClient } }) => {
    await Promise.all([
      queryClient.ensureQueryData(listingQueryOptions(params.id)),
      queryClient.ensureQueryData(listingActivityQueryOptions(params.id)),
    ]);
  },
  errorComponent: ListingErrorBoundary,
  pendingComponent: ListingDetailSkeleton,
  component: ListingDetailPage,
});

function ListingDetailPage() {
  const { id } = Route.useParams();
  // Data guaranteed by loader — no loading state needed
  const { data: listing } = useQuery(listingQueryOptions(id));
  const { data: activity } = useQuery(listingActivityQueryOptions(id));
  return <>{/* render */}</>;
}
```

### API client with token injection
```ts
// src/lib/api-client.ts
import axios from 'axios';
import { keycloak } from './keycloak';

export const apiClient = axios.create({ baseURL: import.meta.env.VITE_BFF_URL });

apiClient.interceptors.request.use(async config => {
  await keycloak.updateToken(30); // refresh if expiring within 30s
  config.headers.Authorization = `Bearer ${keycloak.token}`;
  return config;
});

apiClient.interceptors.response.use(
  res => res,
  err => {
    if (err.response?.status === 401) keycloak.login();
    return Promise.reject(err);
  }
);
```

### TanStack Query feature API
```ts
// src/features/listings/api.ts
import { queryOptions, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/lib/api-client';

export const listingQueryOptions = (id: string) =>
  queryOptions({
    queryKey: ['listings', id],
    queryFn: () => apiClient.get<ListingDetailDto>(`/api/v1/listings/${id}`).then(r => r.data),
    staleTime: 60_000,
  });

export function useDeactivateListing() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => apiClient.patch(`/api/v1/listings/${id}/deactivate`),
    onSuccess: (_, id) => qc.invalidateQueries({ queryKey: ['listings', id] }),
  });
}
```

## When to Use
* Any admin SPA page or component
* Tanstack Router route definitions, loaders, error boundaries
* TanStack Query hooks for admin data fetching
* Keycloak auth integration in the SPA
* Bundle or re-render optimisation in admin views

## When NOT to Use
* Customer portal (Next.js App Router — see `nextjs-patterns`)
* Mobile app (Expo — see `react-native-patterns`)
* Backend implementation
