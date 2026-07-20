# vendor-app (mobile)

| Field | Value |
|---|---|
| Surface | `mobile` |
| Workspace | TAGIN-PLATFORM |
| Type | Mobile — `rn-expo` |
| App | `vendor-app` |
| Code Root | `src/frontend/apps/vendor-app` |
| Architecture Pattern | React Native + Expo managed workflow (Expo Router) |

## Responsibility
Vendor mobile app. **Audience = vendor** (this is the correct project
vocabulary — the mobile app is the vendor's app; grammar skills must stay
audience-neutral and reference this file). React Native + Expo managed,
NativeWind v5, expo-auth-session PKCE, expo-secure-store.

## Toolchain
| | |
|---|---|
| Package manager | pnpm (workspace) |
| Build | `pnpm -F vendor-app build` (EAS for release) |
| Test | `pnpm -F vendor-app test` |
| Lint | `pnpm -F vendor-app lint` |

## Always-load skill packs
> The single source of truth for which frontend skills load for this surface.
> Read by the shared surface-resolution preamble; every command uses this list.

**Always:**
- `react-native-patterns`
- `react-component-patterns`
- `accessibility-standards` (**core only** — native a11y impl lives in `react-native-patterns`; do NOT load the web-DOM appendix)
- `observability-frontend` (policy: **no Microsoft Clarity on RN**)

**Never load on this surface:** `frontend-design-system` (web-only Tailwind/shadcn; RN uses NativeWind — owned by `react-native-patterns`).

**Keyword overlays (add when the story matches):**
- `state`, `zustand`, `store` → `zustand-state-management`
- `auth`, `login`, `session`, `permission` → `authorization-patterns` (claim contract; see `.specify/memory/auth_contract.md`)
- `file`, `upload`, `image`, `attachment` → `file-pipeline-patterns`

## Memory Files
- [tech-stack.md](./tech-stack.md)
- [coding-standards.md](./coding-standards.md)

## Notes
Audience naming and behavioural event identifiers (e.g. a vendor-signup event)
are project vocabulary and live here / in code — not in `react-native-patterns`.
Session shape (`MobileSession`) lives in `.specify/memory/auth_contract.md`.
