---
name: react-native-patterns
description: "Load when: implementing or reviewing the vendor mobile app (React Native, Expo managed workflow, NativeWind v5). List performance, animations, navigation, Expo APIs, platform-specific styling. Loaded by: sk.implement (frontend/mobile), sk.plan, sk.review (frontend)."
---

# React Native Patterns (Expo Managed + NativeWind v5)

## Purpose
Production patterns for the vendor mobile app built with React Native and Expo managed workflow. Covers list rendering performance, Reanimated animations, navigation with Expo Router, NativeWind v5 styling, native module usage, state management, and platform-specific patterns.

## Core Rules

### Expo Managed Workflow
* Stay within managed workflow — do not eject unless a native module is absolutely unavailable via Expo SDK or a community Expo module. Ejecting breaks OTA updates.
* Use `expo-dev-client` for development builds with custom native modules — not bare workflow.
* OTA updates via Expo Updates — keep JS bundle small. Native changes require a new build.
* App configuration in `app.json` / `app.config.ts`. No manual `Info.plist` or `AndroidManifest.xml` edits in managed workflow.
* Target `expo@latest` SDK. Pin the SDK version explicitly — do not use `*`.

### List Rendering (CRITICAL Performance)
* **Always use `FlashList`** (from `@shopify/flash-list`) instead of `FlatList` or `ScrollView` for any list with more than 10 items.
* `FlashList` requires `estimatedItemSize` — measure a real item, do not guess.
* Memoize list items: wrap item component in `React.memo`. Ensure props are stable (no inline objects/functions).
* Stable callbacks: define `renderItem`, `keyExtractor`, `onEndReached` outside the component or with `useCallback` — unstable functions cause full list re-renders.
* Avoid inline objects in `renderItem`: `renderItem={({ item }) => <Item data={item} />}` is fine; `renderItem={({ item }) => <Item style={{ padding: 8 }} />}` re-renders every scroll.
* Images in lists: use `expo-image` (not `Image` from React Native) — it caches, handles `blurhash`, and recycles efficiently.
* Never use `ScrollView` + `map()` for potentially long lists. It renders all items at once.

### Animations (Reanimated 3)
* Use **React Native Reanimated 3** (`react-native-reanimated`) for all animations.
* **GPU-friendly properties only**: `transform` (translateX, translateY, scale, rotate), `opacity`. Never animate `width`, `height`, `top`, `left`, `margin`, `padding` — these trigger layout recalculation on every frame.
* Derived values: `useDerivedValue` to compute animation values from shared values — runs on the UI thread, not JS thread.
* Gestures: `react-native-gesture-handler` with `GestureDetector`. Never use `onPress` on `Animated.View` — use `Pressable` or `GestureDetector`.
* Shared values: `useSharedValue` for values driven by gestures or timers. `useAnimatedStyle` to map shared values to style.
* `withSpring`, `withTiming` for declarative animations. Avoid `Animated.loop` with Reanimated — use `withRepeat`.

### Navigation (Expo Router)
* Use **Expo Router** (file-based, built on React Navigation) — not bare React Navigation.
* Route files in `app/` directory — mirrors Next.js App Router conventions.
* Dynamic routes: `app/listings/[id].tsx`.
* Tab navigation: `app/(tabs)/_layout.tsx` with `<Tabs>` from Expo Router.
* Stack navigation: `app/(stack)/_layout.tsx` with `<Stack>`.
* Deep linking configured via `app.json` `scheme` field — automatically handled by Expo Router.
* Use native navigators (`native` prop) — renders platform-native navigation chrome (UINavigationController on iOS, Fragment on Android).
* Never use `router.back()` for predictable navigation — use `router.push()` or `router.replace()` with explicit paths.

### NativeWind v5 Styling
* NativeWind v5 + Tailwind CSS v4 — no Babel configuration needed (Metro transformer).
* Import platform-aware components from `react-native-css` wrapper: `View`, `Text`, `ScrollView`, `Pressable`, `TextInput`, `Image`, `Link`.
* `className` prop on these wrapped components — same Tailwind classes as web.
* Platform-specific styles via CSS media queries: `@media (platform: ios) { ... }`, `@media (platform: android) { ... }`.
* Custom theme variables in `src/global.css` via `@theme` block.
* Apple semantic colours: `light-dark()` function in CSS for automatic dark mode. Use `platformColor()` for native system colours (e.g., iOS `systemBlue`).
* `tailwind-merge` and `clsx` for conditional class composition — same as web pattern.
* Never use React Native's `StyleSheet.create` alongside NativeWind on the same component. Pick one approach per component.

### State Management
* Zustand for global state (auth session, user preferences, offline queue).
* TanStack Query for server state — auto-caches, handles background refresh, works offline with `networkMode: 'offlineFirst'`.
* Local component state (`useState`) for UI state that doesn't escape the component.
* Never use Context for frequently-updating state — causes wide re-renders. Use Zustand.
* Offline queue: persist pending mutations in Zustand (with MMKV storage) and replay on reconnect.

### Platform-Specific Code
* Platform-specific file extensions: `Component.ios.tsx` / `Component.android.tsx` for significantly different implementations.
* `Platform.OS === 'ios'` / `Platform.OS === 'android'` for minor inline differences only. Excessive inline checks are a code smell.
* Safe area: always use `useSafeAreaInsets()` or `SafeAreaView` from `react-native-safe-area-context`. Never hardcode status bar heights.
* Keyboard: `KeyboardAvoidingView` with `behavior="padding"` (iOS) / `behavior="height"` (Android).

### Native APIs (Expo SDK)
* Camera: `expo-camera`. Location: `expo-location`. Notifications: `expo-notifications`. File system: `expo-file-system`.
* Always request permissions before accessing native APIs. Handle `denied` and `undetermined` states explicitly — show explanatory UI before the permission prompt.
* Biometrics: `expo-local-authentication` for secure local authentication.
* Storage: `expo-secure-store` for sensitive data (tokens). `@react-native-async-storage/async-storage` or MMKV for non-sensitive persistent data.

### Performance Rules
* No `console.log` in production — remove or gate behind `__DEV__`.
* Avoid anonymous functions in JSX (`onPress={() => handler()}`) in list items — breaks `memo`. Extract to named handlers.
* `InteractionManager.runAfterInteractions` for expensive operations after navigation animations complete.
* `useFocusEffect` instead of `useEffect` for screen-level data refresh — runs only when screen is focused.

## Patterns / Examples

### FlashList with memoised item
```tsx
import { FlashList } from '@shopify/flash-list';
import { memo, useCallback } from 'react';

const ListingItem = memo(({ item, onPress }: { item: Listing; onPress: (id: string) => void }) => (
  <Pressable className="p-4 border-b border-border" onPress={() => onPress(item.id)}>
    <Text className="text-base font-semibold text-foreground">{item.title}</Text>
    <Text className="text-sm text-muted-foreground">{item.price}</Text>
  </Pressable>
));

export function ListingsList({ listings }: { listings: Listing[] }) {
  const router = useRouter();
  const handlePress = useCallback((id: string) => router.push(`/listings/${id}`), [router]);

  return (
    <FlashList
      data={listings}
      renderItem={({ item }) => <ListingItem item={item} onPress={handlePress} />}
      estimatedItemSize={72}
      keyExtractor={item => item.id}
    />
  );
}
```

### Swipe-to-action animation (Reanimated + Gesture Handler)
```tsx
import { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { GestureDetector, Gesture } from 'react-native-gesture-handler';

export function SwipeableListItem({ children, onDelete }: Props) {
  const translateX = useSharedValue(0);

  const panGesture = Gesture.Pan()
    .onUpdate(e => { translateX.value = Math.min(0, e.translationX); })
    .onEnd(e => {
      if (e.translationX < -80) { runOnJS(onDelete)(); }
      else { translateX.value = withSpring(0); }
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View style={animatedStyle}>{children}</Animated.View>
    </GestureDetector>
  );
}
```

### NativeWind + platform colour
```tsx
// src/global.css
@theme {
  --color-primary: platformColor(systemBlue, #3b82f6);
  --color-background: light-dark(#ffffff, #0a0a0a);
}

// Component
<View className="bg-background p-4">
  <Text className="text-primary font-bold">Hello</Text>
</View>
```

## When to Use
* Any vendor mobile app screen, component, or navigation flow
* List rendering, animations, gestures in the mobile app
* Expo SDK API usage (camera, location, notifications)
* NativeWind styling decisions
* `sk.implement (frontend/mobile)` for any mobile story

## When NOT to Use
* Customer portal (Next.js — see `nextjs-patterns`)
* Admin SPA (React + Vite — see `react-admin-patterns`)
* Web-specific patterns (CSS Grid, DOM APIs, SSR)
