---
unit: {unit-id}
intent: {intent-id}
status: draft | approved
surface: portal | admin | mobile | multi
stories-covered: []
created: {date}
updated: {date}
---

# UI Model: {unit-name}

## Target Surface
<!-- Which frontend(s) this unit renders on, and the framework for each.
     Example:
     - Customer portal (Next.js App Router) — primary
     - Admin SPA (React + Vite + Tanstack Router) — read-only moderation view -->

## Route & Page Tree
<!-- The route/segment structure for the surface. Show layouts, route groups,
     loading.tsx / error.tsx / not-found.tsx boundaries (portal) or route objects (SPA) / screens (mobile).
     Example:
     app/(marketing)/listings/
       ├── page.tsx          # search/browse — Server, ISR 60s
       ├── loading.tsx       # grid skeleton
       ├── error.tsx         # search error fallback
       └── [id]/page.tsx     # detail — Server, SSR, SEO -->

## Component Architecture
<!-- Decompose each page into components. One row per component.
     render boundary: server | client (portal) — or container | presentational (SPA/mobile).
     scope: shared (reused 3+ places) | unit-local.
     Format:
     | Component | Boundary | Responsibility | Scope |
     |---|---|---|---|
     | ListingGrid | server | render listing cards from props | unit-local |
     | FilterBar | client | controlled filter form, updates URL params | unit-local |
     | MapView | client | geo map interaction | shared |
     REQUIRED: every component declares boundary + single responsibility. -->

## State Architecture
<!-- Classify every piece of state into exactly ONE home, with rationale.
     server cache: server-owned data (Next.js cache tags / TanStack Query).
     global store (Zustand): cross-component UI state only — never server snapshots.
     local: single-component concern.
     Format:
     | State | Home | Rationale |
     |---|---|---|
     | listing results | server cache (tag: listing) | server-owned, revalidate on mutation |
     | active filters | URL params + local | shareable, drives server refetch |
     | theme (dark/light) | global store | cross-component UI preference |
     REQUIRED: server-owned data must NOT appear under global store. -->

## Data Consumption Contracts
<!-- TypeScript interfaces that map consumed API responses to frontend types.
     Reference the endpoint from contracts/api-spec.json — do NOT restate endpoint ownership.
     Declare fetch strategy per route: Static (force-cache) | ISR (revalidate) | Dynamic (no-store) | client-fetch.
     Example:
     - GET /api/v1/listings/{id}  →  ISR 60s, tags: ['listing', `listing-${id}`]
       interface ListingDetailDto { id: string; title: string; price: number; location: GeoPoint; }
     REQUIRED: every field consumed must exist in api-spec.json. Missing fields → Open Questions. -->

## Design System Usage
<!-- shadcn/ui components used, custom components required (with reason), feature-specific token notes.
     Reuse existing tokens — do not introduce a new visual style.
     Example:
     - shadcn: Card, Badge, Dialog, Form, Input, Button
     - custom: ListingMapPin (no shadcn equivalent — wraps map marker)
     - tokens: reuse existing; no new colours -->

## Performance Strategy
<!-- SSR/ISR/Static per route, bundle split points, image strategy, Core Web Vitals targets.
     Example:
     - Detail page: SSR for SEO; MapView dynamic-imported (heavy, client-only)
     - Images: next/image, R2 public bucket, priority on hero + first card row
     - Target: LCP < 2.5s, CLS < 0.1 on listing grid -->

## Accessibility Requirements
<!-- WCAG 2.2 AA targets, keyboard navigation paths, focus management, ARIA decisions.
     Example:
     - FilterBar: full keyboard operable; focus returns to trigger on close
     - MapView: provide non-map list alternative for screen-reader users
     - All interactive elements: visible focus ring, min 44x44 touch target -->

## Error & Loading States
<!-- Per async surface: loading UI, empty state, error fallback.
     Example:
     - Listing grid: skeleton (loading) / "No results — adjust filters" (empty) / retry banner (error)
     - Detail page: notFound() on 404; error.tsx boundary on fetch failure -->

## Stories Coverage
<!-- Every story delivered by this unit, mapped to its frontend surface.
     Format: - [{story-id}] {title}: {route/component path, or "no UI — backend only"}
     Example:
     - [INV-001-LST-001] Browse listings: /listings page + ListingGrid, FilterBar
     - [INV-001-LST-002] Listing detail: /listings/[id] page + ListingHeader, MapView -->

## Open Questions
<!-- Unresolved UI decisions, and any endpoints/fields needed but absent from the contract.
     Missing-contract items must name the endpoint and be flagged for sk.design --contracts. -->
