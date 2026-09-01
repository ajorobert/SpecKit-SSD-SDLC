# Shared: Frontend comment-marker index

Frontend-reachable mirror of the comment-marker contract, so **FE-only work has
the marker index without loading `backend-architecture §7`** (which is not loaded
for frontend-only stories). The canonical cross-stack index still lives in
`backend-architecture §7`; this file mirrors the frontend subset.

Load this alongside the surface packs (referenced by
`.claude/skills/shared/surface-resolution.md`).

| Marker | Owning skill | Emitted on | Semantics |
|---|---|---|---|
| `// FETCH:` | surface-neutral **frontend fetch contract** — implemented by the loaded surface skill (`nextjs-patterns` on web/admin, `react-native-patterns` on mobile) | web · admin · mobile | Outbound call to a backend service composes bearer + `traceparent` + `Idempotency-Key` through the single fetch wrapper. The contract is identical across surfaces; each surface skill is present when its code is generated, so the marker's contract is always in context. |
| `// AUTH:` | `authorization-patterns` | web · admin · mobile | Auth gate / permission assumption; backend re-validates every call. |
| `// IDEMPOTENCY:` | `backend-feature-patterns` | web · admin · mobile | Mutating call supplies a stable `Idempotency-Key` per user action (not per retry). |
| `// EVENT:` | `observability-frontend` | web · admin · mobile | Analytics emission site (PostHog); dropped before consent. |
| `// CONSENT:` | `observability-frontend` | web · admin · mobile | Consent gate before any analytics SDK starts. |
| `// MASK:` | `observability-frontend` | **web only** | Clarity PII-redaction attribute. **Not emitted on admin or mobile** (Clarity is web-only). |
| `// A11Y:` | `accessibility-standards` | web · admin · mobile | Non-obvious accessibility annotation (e.g. enforced hit-area). |
| `// CSR:` | surface skill (client-only entry) | web · admin | Marks browser-only code (client component / island). |

> **F10 note.** `// FETCH:` is treated as a **surface-neutral** contract here
> rather than owned by `nextjs-patterns` alone, because it is emitted on all
> three surfaces and the owning surface skill is always co-loaded with the code
> that emits it (per the manifest). For admin-only or mobile-only changes the
> contract is therefore never absent.
