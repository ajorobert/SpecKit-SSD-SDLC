---
name: nextjs-patterns
description: "Load when: implementing or reviewing the customer portal (Next.js App Router, NextAuth v5, Strapi v2, Cloudflare R2, SSR, SEO, geo search UI). Loaded by: sk.implement (frontend/nextjs), sk.plan, sk.review (frontend)."
---

# Next.js Patterns (App Router, Customer Portal)

## Purpose
Production patterns for the customer-facing portal built with Next.js App Router, NextAuth v5, Strapi v2 CMS, and Cloudflare R2 image delivery. Covers server/client component decisions, SSR, SEO metadata, data fetching caching strategy, geo search UI integration, and CMS content routing.

## Core Rules

### Server vs Client Components
* **Server Components are the default.** Start server-side; add `'use client'` only when the component needs interactivity.
* Use Server Components for: data fetching, layout, static content, SEO-critical markup.
* Use Client Components for: `useState`, `useEffect`, event handlers, browser APIs, map/geo UI.
* Split: Server parent fetches data → passes serialisable props to Client child. Never pass non-serialisable objects (class instances, functions) as props across the boundary.
* Avoid `'use client'` at layout level — it forces the entire subtree to be client-rendered.

| Need | Component Type |
|---|---|
| Listing detail page (SEO) | Server |
| Search results with filters | Server (initial) + Client (filter interactions) |
| Map / geo search UI | Client |
| CMS content page | Server |
| Auth session UI (user avatar, logout) | Client |
| Form submission | Client + Server Action |

### Data Fetching & Caching
* Three strategies — choose per route based on freshness requirement:
  * **Static** (`cache: 'force-cache'`): build-time fetch. Use for CMS pages that change rarely.
  * **ISR** (`next: { revalidate: 60 }`): time-based revalidation. Use for listing pages.
  * **Dynamic** (`cache: 'no-store'`): every request. Use for personalised or real-time data.
* Use `React.cache()` to deduplicate the same fetch across multiple Server Components in one render.
* Never fetch in Client Components — fetch in Server Component, pass as props or use Server Actions.
* Parallel fetch with `Promise.all` for independent data requirements in a single Server Component.
* Tag-based revalidation: `next: { tags: ['listing', listingId] }` → `revalidateTag('listing')` on mutation.

### Server Actions
* Use for form submissions and data mutations. Mark with `'use server'`.
* Validate all inputs server-side with Zod — never trust client-sent data.
* Return typed response objects: `{ success: true, data: T } | { success: false, error: string }`.
* Use `useActionState` (React 19) to manage form state and pending indicators.
* Revalidate affected tags/paths after successful mutation: `revalidatePath('/listings')`.

### Route Organisation
```
app/
├── (marketing)/          # Public pages — no auth
│   ├── page.tsx          # Homepage
│   └── listings/
│       ├── page.tsx      # Listing search/browse
│       └── [id]/page.tsx # Listing detail (SSR, SEO)
├── (portal)/             # Authenticated user area
│   ├── layout.tsx        # Auth guard layout
│   ├── dashboard/page.tsx
│   └── favourites/page.tsx
├── (cms)/                # Strapi-driven content pages
│   └── [...slug]/page.tsx
└── api/
    └── auth/[...nextauth]/route.ts
```
* Route groups `(name)` — organise without affecting URL structure.
* `loading.tsx` — streaming loading UI with Suspense. Required for any route with async data.
* `error.tsx` — error boundary per segment. Always provide user-facing fallback.
* `not-found.tsx` — 404 page with navigation back to search.

### SEO & Metadata
* Use `generateMetadata()` for dynamic per-page metadata. Never use `<Head>` from `next/head`.
* Required metadata: `title` (50–60 chars), `description` (150–160 chars), `openGraph.images`, `canonical`.
* Listing pages: structured data (JSON-LD `ListItem`, `LocalBusiness`) injected via `<script type="application/ld+json">` in the Server Component.
* `robots.txt` and `sitemap.xml` generated via route handlers or `next-sitemap`.
* Language/locale: use `next-intl` or App Router i18n routing for internationalisation.

### Authentication (NextAuth v5)
* Auth config in `auth.ts` at the project root — exported `auth`, `signIn`, `signOut`, `handlers`.
* Keycloak provider (v2) or Firebase provider (v1) configured in `auth.ts`.
* Protect routes in `middleware.ts` using the `auth` export — do not use `getServerSession` in individual pages.
* Access session in Server Components: `const session = await auth()`.
* Access session in Client Components: `useSession()` from `next-auth/react`.
* Never expose access tokens to client components — only expose safe session fields.
* On auth provider switch (v1→v2): update `auth.ts` provider config — no page-level changes needed.

### Strapi v2 CMS Integration
* Strapi runs as a separate service with its own PostgreSQL schema. Schema as JSON on git.
* Fetch CMS content server-side only — never from Client Components.
* Draft/published routing:
  * Published content: fetched without `publicationState` param. Cached with ISR.
  * Draft preview: route via `/api/preview?token=...` → enables draft mode → re-fetches with `publicationState=preview`. Protected by preview token.
* Strapi API client: singleton, injected via server-side only module (never imported in `'use client'`).
* Images from Strapi: URLs point to Cloudflare R2 public bucket. Always use `next/image` with `remotePatterns` configured.

### Cloudflare R2 Image Delivery
* Public R2 bucket for active/published images. CDN-delivered — permanent URLs (versioned by file ID).
* Private R2 bucket for draft/unpublished content. Access via presigned URLs with short TTL.
* All images rendered via `next/image` for automatic optimisation (WebP conversion, responsive srcset, lazy loading).
* Always set `width`, `height` or `fill` on `next/image`. Never omit — causes layout shift.
* `priority` prop on above-the-fold images (hero, listing card grid first row).
* `sizes` prop set correctly for responsive images: `"(max-width: 768px) 100vw, 50vw"`.

### Performance
* Dynamic imports (`next/dynamic`) for heavy Client Components (map, chart, rich text editor).
* `next/font` for font loading — zero layout shift, self-hosted.
* Static assets on CDN — never served from Next.js origin.
* `<Suspense>` boundaries around every independently loadable data section.
* Avoid client-side waterfalls: parallel fetch at the Server Component level, not sequential `useEffect` chains.

## Patterns / Examples

### Server Component: listing detail (SSR + SEO)
```tsx
// app/(marketing)/listings/[id]/page.tsx
export async function generateMetadata({ params }: { params: { id: string } }) {
  const listing = await getListing(params.id);
  return {
    title: `${listing.title} | DirectoryService`,
    description: listing.description.slice(0, 155),
    openGraph: { images: [{ url: listing.heroImageUrl }] },
  };
}

export default async function ListingDetailPage({ params }: { params: { id: string } }) {
  const [listing, reviews] = await Promise.all([
    getListing(params.id),
    getReviews(params.id),
  ]);

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{
        __html: JSON.stringify(buildListingJsonLd(listing))
      }} />
      <ListingHeader listing={listing} />
      <Suspense fallback={<ReviewsSkeleton />}>
        <ReviewsList reviews={reviews} />
      </Suspense>
      <GeoMapClient location={listing.location} /> {/* Client Component */}
    </>
  );
}
```

### Server Action: save listing
```tsx
'use server';
import { z } from 'zod';
import { revalidateTag } from 'next/cache';
import { auth } from '@/auth';

const schema = z.object({ listingId: z.string().uuid() });

export async function saveListingAction(formData: FormData) {
  const session = await auth();
  if (!session) return { success: false, error: 'Unauthenticated' };

  const parsed = schema.safeParse({ listingId: formData.get('listingId') });
  if (!parsed.success) return { success: false, error: 'Invalid input' };

  await bffClient.post('/saved-listings', {
    listingId: parsed.data.listingId,
    userId: session.user.id,
  });

  revalidateTag(`user-saved-${session.user.id}`);
  return { success: true };
}
```

### Fetch with ISR + tag-based revalidation
```tsx
async function getListing(id: string) {
  const res = await fetch(`${process.env.BFF_URL}/api/v1/listings/${id}`, {
    next: { revalidate: 60, tags: ['listing', `listing-${id}`] },
  });
  if (!res.ok) notFound();
  return res.json() as Promise<ListingDetailDto>;
}
```

## When to Use
* Any customer portal page or component (Next.js App Router)
* SEO-critical listing pages, CMS content pages, geo search pages
* NextAuth v5 auth integration
* Strapi content fetching or preview mode
* Cloudflare R2 image display

## When NOT to Use
* Admin SPA (React + Vite + Tanstack Router — see `react-admin-patterns`)
* Mobile app (Expo — see `react-native-patterns`)
* Backend API implementation (see `csharp-clean-arch`, `bff-patterns`)
