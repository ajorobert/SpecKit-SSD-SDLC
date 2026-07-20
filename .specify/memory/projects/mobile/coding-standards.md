# vendor-app — Coding Standards

Overlay on shared `standards/coding-standards.md`. Stack-specific rules only.

## Formatter / Linter
Prettier + ESLint (Expo config). `sk.implement` runs `pnpm -F vendor-app lint --fix` after each task phase.

## Conventions
- Styling via NativeWind v5 only (`react-native-patterns`) — no web Tailwind/shadcn imports, no inline style objects where a NativeWind class exists.
- Native a11y: `accessibilityRole` / `accessibilityLabel` (`react-native-patterns §2.11`) — never DOM `aria-*`.
- Tokens in secure storage: access token in-memory; refresh via `expo-secure-store` only (never AsyncStorage/MMKV) — per `auth_contract.md`.
- Data fetching via the RN fetch wrapper (traceparent + Idempotency-Key) owned by `react-native-patterns`.
- Audience naming ("vendor") and behavioural event ids are project vocabulary — keep them here / in code, not in grammar skills.
- DTOs match `contracts/api-spec.json` exactly — no `any`.

## Architecture Rules
- Expo Router file-based structure per `react-native-patterns`.
- Component decomposition per `react-component-patterns`.
- Cross-cutting a11y core (POUR, 44px target, contrast, reduced-motion, blocking gate) from `accessibility-standards` (core only) — no web-DOM appendix.
- Observability: no Microsoft Clarity on RN.
