# vendor-app — Tech Stack

| Field | Value |
|---|---|
| Type | Mobile — `rn-expo` |
| Framework | React Native + Expo (managed workflow) |
| Routing | Expo Router (file-based) |
| Styling | NativeWind v5 |
| Lists / Animation | FlashList · Reanimated 3 |
| Auth | expo-auth-session PKCE · expo-secure-store |
| Files | expo-file-system |
| State | Zustand v5 |

> Confirm Expo SDK + library versions against
> `src/frontend/apps/vendor-app/package.json` (and `app.json`/`app.config.*`) in
> the real workspace — or let `sk.init` fill them.

## Stack Detail
- **UI layer:** NativeWind v5 (native styling) — owned by
  `react-native-patterns`. **No Tailwind/shadcn** (`frontend-design-system` is
  web-only and is not loaded on this surface).
- **A11y:** native accessibility (`accessibilityRole`/`accessibilityLabel`) —
  owned by `react-native-patterns`; shares the cross-cutting a11y core from
  `accessibility-standards` (core section only).
- **Data:** backend fetch contract (traceparent + bearer + Idempotency-Key);
  presigned uploads with progress — owned by `react-native-patterns`.
- **Observability:** OTel RN, Sentry RN→GlitchTip, PostHog (anonymous). **No
  Microsoft Clarity on RN** — `observability-frontend`.
