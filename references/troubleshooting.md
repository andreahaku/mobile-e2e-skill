# Troubleshooting Guide

Common problems and proven solutions from real Maestro E2E implementations. Use this when debugging test failures (Workflow 3) or handling edge cases during YAML generation.

## Critical Issues

### 1. iOS Keychain Persistence

**Problem:** `clearState: true` does NOT clear the iOS Keychain. Auth tokens stored via `expo-secure-store` or Keychain API survive app data reset, causing the app to restore a stale session.

**Solution:** Always use `clearKeychain: true` alongside `clearState: true`:
```yaml
- launchApp:
    clearState: true
    clearKeychain: true
```

**Note:** This is iOS-specific. Android's `clearState` handles everything.

### 2. Expo Dev Client Launcher

**Problem:** After `clearState`, Expo Dev Client shows a launcher screen instead of the app, listing Metro URLs and a "Continue" dialog.

**Solution:** Handle in utility flows with optional taps:
```yaml
- tapOn:
    text: "http://localhost:8081"
    optional: true
- tapOn:
    text: "http://localhost:8082"
    optional: true
- extendedWaitUntil:
    visible:
      text: "Continue"
    timeout: 60000
    optional: true
- tapOn:
    text: "Continue"
    optional: true
- tapOn:
    point: "95%,42%"
    optional: true
```

### 3. Session Loss Between Flows

**Problem:** `maestro test <directory>` runs flows in parallel. Each gets its own app instance, so flows that depend on a prior login fail.

**Solution:** Use a master `run-all.yaml` that inlines all steps in a single flow:
```bash
# CORRECT: single session
maestro test .maestro/release-checks/staging/run-all.yaml

# WRONG: parallel, session lost
maestro test .maestro/release-checks/staging/
```

### 4. BottomSheet / Portal Elements Completely Invisible to Maestro

**Problem:** `@gorhom/bottom-sheet` renders content in an internal Portal layer. Maestro can't find ANY elements inside it — **neither `testID` nor `text` selectors work**. This is NOT a simple accessibility issue — gorhom's Portal renders outside the native accessibility tree entirely.

**What doesn't work:**
- `tapOn: id: "my-button"` → element not found
- `tapOn: text: "Submit"` → element not found
- `assertVisible: id: "my-element"` → element not found
- `accessible={false}` on BottomSheet → no effect
- `accessibilityLabel` / `importantForAccessibility` → no effect
- Conditional mounting (useState + index={0}) → renders visually but still invisible to Maestro

**Solution:** Use a **dual-render approach** with native React Native `<Modal>` for E2E tests:

1. Set `EXPO_PUBLIC_E2E_TEST=true` env var before starting Metro
2. Add `useNativeModal` prop to BottomSheet components
3. When `useNativeModal` is true, render content in `<Modal presentationStyle="pageSheet">` instead of `<BottomSheet>`
4. Replace `BottomSheetScrollView` with regular `ScrollView` (see #19)
5. Use conditional mounting (`useState`) instead of `index={-1}`

Native `<Modal>` creates a separate native `UIViewController` (iOS) that Maestro reads perfectly — all testIDs and text selectors work normally inside it.

See `maestro-patterns.md` → "BottomSheet / Portal — Native Modal Dual-Render Strategy" for full implementation details.

**Coordinate taps** remain the only option for BottomSheets not yet migrated to the dual-render approach (see #16).

### 5. OTP Input Hidden Behind Visual Boxes

**Problem:** OTP screens show decorative boxes with a hidden TextInput behind them. Maestro can't interact with the hidden input.

**Solution:** Tap the visible container to focus the hidden input, then type:
```yaml
- tapOn:
    id: "otp-boxes-container"
- inputText: "123456"
```

## UI Interaction Issues

### 6. Native Alert Dialogs

**Problem:** Native iOS/Android alerts may have the title and button with the same text (e.g., both say "Logout"). Maestro taps the title instead of the button.

**Solution:** Use `index` to target the button:
```yaml
# index: 0 = alert title, index: 1 = the confirmation button
- tapOn:
    text: "Logout"
    index: 1
    optional: true
```

### 7. Multi-Language Apps

**Problem:** Buttons and alerts appear in different languages depending on user/device locale.

**Solution:** Try each language variant with `optional: true`:
```yaml
- tapOn:
    text: "Logout"
    index: 1
    optional: true
- tapOn:
    text: "Esci"
    index: 1
    optional: true
# Add more as needed for your supported languages
```

### 8. Auto-Opened Screens After Login

**Problem:** After login, the app may auto-open a specific screen (from a push notification or deep link), skipping the expected landing screen.

**Solution:** Try going back optionally after login:
```yaml
- extendedWaitUntil:
    visible:
      id: "<main-screen-id>"
    timeout: 60000
    optional: true

- tapOn:
    id: "<back-button-id>"
    optional: true

- extendedWaitUntil:
    visible:
      id: "<main-screen-id>"
    timeout: 30000
```

### 9. Permission-Gated Screens

**Problem:** Some screens are only visible to users with specific roles/permissions. Tests fail if the test account doesn't have access.

**Solution:** Use `optional: true` for permission-gated assertions:
```yaml
- extendedWaitUntil:
    visible:
      id: "admin-screen"
    timeout: 30000
    optional: true
```

### 10. Scroll vs Swipe Direction Confusion

**Problem:** `swipe DOWN` moves the finger down, which scrolls content UP. This is counterintuitive and causes tests to scroll the wrong way.

**Solution:** Remember: swipe direction = finger movement direction.
- `swipe DOWN` → content scrolls UP (older content)
- `swipe UP` → content scrolls DOWN (newer content)

For precise targeting, use `scrollUntilVisible`:
```yaml
- scrollUntilVisible:
    element:
      id: "target-element"
    direction: DOWN
    timeout: 10000
```

### 11. Drawer Navigation Gesture Unreliable

**Problem:** Swiping right from the left edge to open a drawer is unreliable in Maestro.

**Solution:** Prefer tapping the drawer button, then always wait for the item:
```yaml
- tapOn:
    id: "drawer-menu-button"

- extendedWaitUntil:
    visible:
      id: "drawer-<section>-item"
    timeout: 5000
```

### 12. Flaky Tests (Timing)

**Problem:** Tests pass locally but fail in CI, or pass intermittently.

**Solution:**
1. Use `extendedWaitUntil` before every interaction on async content
2. Never use `assertVisible` as the first check on a newly loaded screen
3. Use generous timeouts (30s for API-dependent screens)
4. Use `optional: true` for elements that may or may not appear

## Configuration Issues

### 13. Test Account Permissions

**Problem:** Tests fail because the test account can't access certain features.

**Solution:** Ensure the test account has all required permissions for the features being tested. Document required permissions in the test plan.

### 14. Credentials in Git

**Problem:** Hardcoded credentials in YAML files get committed.

**Solution:**
- Use `.env` (gitignored) for credentials
- Reference in YAML with `${ENV_VAR}` syntax
- Use `e2e-run.sh` to load `.env` and pass to Maestro
- Add `.env.example` with placeholder values

### 15. Chat Input Focus

**Problem:** Tapping the send button doesn't focus the text input on some devices.

**Solution:** Tap the placeholder text to focus:
```yaml
- tapOn:
    text: "Type a message..."
- inputText: "Test message"
```

### 16. Coordinate-Based Tapping (BottomSheet Fallback)

**Problem:** When neither testID nor text selectors work for BottomSheet/Portal content.

**Solution:** Use coordinate taps calibrated per device:
```yaml
- tapOn:
    point: "50%,90%"
    optional: true
```

**Important:** Always document the calibration device. Coordinates change across device sizes.

### 17. Keyboard Covering Inputs / hideKeyboard Causes Spurious Taps

**Problem:** iOS keyboard covers input fields in forms, especially in modals. Additionally, Maestro's `hideKeyboard` command on iOS often causes a spurious tap on the keyboard itself, inserting an unwanted character (commonly `t` or `y`) into the focused field. This corrupts the input and causes login/form failures.

**Solution:** NEVER use `hideKeyboard` when a text field has focus. Instead, tap directly on the next interactive element by testID — tapping a button or another field automatically dismisses the keyboard without side effects:
```yaml
# WRONG — hideKeyboard may type a stray character
- tapOn:
    id: "password-input"
- inputText: "MyPassword123"
- hideKeyboard          # ❌ Can insert 't' into the password field!
- tapOn:
    id: "submit-button"

# CORRECT — tap the next element directly
- tapOn:
    id: "password-input"
- inputText: "MyPassword123"
- tapOn:
    id: "submit-button"  # ✅ Keyboard dismisses automatically

# For multi-field forms, just tap the next field
- tapOn:
    id: "field-1"
- inputText: "value1"
- tapOn:                  # ✅ Tapping next field dismisses keyboard
    id: "field-2"
- inputText: "value2"
```

**Preferred keyboard dismissal method:** Use `pressKey: enter` — it simulates the Return/Done key on the iOS keyboard and cleanly dismisses it without inserting characters. Use this when the next interactive element (like a submit button) is hidden behind the keyboard.

```yaml
- inputText: "password123"
- pressKey: enter              # ✅ Dismisses keyboard cleanly
- tapOn:
    id: "submit-button"       # Now visible and tappable
```

**Rule:** Never use `hideKeyboard`. For multi-field forms, tap the next field by testID (auto-dismisses keyboard). When the submit button is behind the keyboard, use `pressKey: enter` first.

### 18. Clearing Pre-filled Text

**Problem:** Input fields have pre-filled values that need to be cleared before typing new ones.

**Solution:**
```yaml
- eraseText: 20
- inputText: "new value"
```

---

## Pre-Flight Checklist

Before running E2E tests, verify:

```bash
# 1. Maestro installed
maestro --version

# 2. Simulator/emulator running
xcrun simctl list devices booted          # iOS
adb devices                                # Android

# 3. Metro running
lsof -i :8081 -i :8082 | grep LISTEN

# 4. App installed
xcrun simctl listapps booted | grep <appId>   # iOS
adb shell pm list packages | grep <appId>      # Android

# 5. Credentials configured
cat .env | grep MAESTRO_

# 6. Runner script executable
ls -la scripts/e2e-run.sh
```

### 19. BottomSheetScrollView Crash Outside BottomSheet Context

**Problem:** Components using `BottomSheetScrollView` from `@gorhom/bottom-sheet` crash with `"useBottomSheetInternal cannot be used out of the BottomSheet!"` when rendered inside a native `<Modal>` (dual-render E2E approach).

**Solution:** Replace `BottomSheetScrollView` with regular `ScrollView` from `react-native` in any content component that needs to work in both BottomSheet and native Modal modes:
```tsx
// Before:
import { BottomSheetScrollView } from "@gorhom/bottom-sheet";
// After:
import { ScrollView } from "react-native";
```

### 20. `scroll` Command with Properties → "Unknown Property"

**Problem:** Maestro's `scroll` command does NOT accept `id:`, `direction:`, or other properties. Using them causes `"Unknown Property: id"` error.

**Solution:** Use plain `- scroll` (scrolls the main screen down):
```yaml
# ❌ WRONG
- scroll:
    id: "my-scroll-view"
    direction: DOWN

# ✅ CORRECT
- scroll
```

### 21. SegmentedControl Container Tap Hits Divider

**Problem:** Tapping a SegmentedControl by its container testID taps the divider between segments instead of a segment option. No segment gets selected.

**Solution:** Tap the individual segment testID. Components typically generate `${containerTestID}-${option.key}`:
```yaml
# ❌ WRONG — hits divider
- tapOn:
    id: "view-toggle"

# ✅ CORRECT — hits specific segment
- tapOn:
    id: "view-toggle-calendar"
```

### 22. `pressKey: Escape` Has No Effect on iOS

**Problem:** `pressKey: Escape` does nothing on iOS simulators — it doesn't dismiss modals, bottom sheets, or keyboards.

**Solution:** Use close buttons (preferred) or coordinate taps:
```yaml
# ✅ Close button
- tapOn:
    id: "modal-close-button"

# ✅ Coordinate tap outside modal
- tapOn:
    point: "50%,10%"
    optional: true
```

### 23. `clearInput` Is Not a Valid Maestro Command

**Problem:** `clearInput` doesn't exist in Maestro. Using it causes a parse error.

**Solution:** Tap the field first, then use `eraseText`:
```yaml
- tapOn:
    id: "email-input"
- eraseText: 50
- inputText: "new-value@example.com"
```

### 24. `assertNotVisible` Fails for Non-Existent Elements

**Problem:** `assertNotVisible` errors out when the testID doesn't exist in the view tree at all. It only works for elements that exist but are hidden/off-screen.

**Solution:** Don't use `assertNotVisible` to check that an element doesn't exist. For checking absence, use `assertVisible` with `optional: true` and check the WARNED status in results:
```yaml
# ✅ For elements that exist but should be hidden
- assertNotVisible:
    id: "loading-spinner"

# ✅ For elements that may not exist at all
- assertVisible:
    id: "maybe-present-element"
    optional: true
```

### 25. Empty State — Data-Dependent Elements

**Problem:** Tests fail when expecting elements that only appear when data exists (e.g., "Unblock" button only exists if there are blocked dates).

**Solution:** Use `optional: true` for all data-dependent interactions:
```yaml
# May or may not have blocked dates
- assertVisible:
    text: "Blocked Dates"
    optional: true

- tapOn:
    text: "Unblock"
    optional: true

# Dismiss confirmation if it appeared
- tapOn:
    text: "Cancel"
    optional: true
```

---

## Error → Cause → Fix

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `Element not found: id "X"` | testID missing or misspelled | Check component for testID prop |
| `Timeout waiting for element` | Screen didn't load, API slow | Increase timeout, check network |
| `App crashed` | Unhandled error in app code | Check Metro logs for stack trace |
| `Unable to connect to device` | Simulator not booted | Boot simulator/emulator |
| `Could not launch app` | App not installed | Rebuild and install app |
| `Multiple elements found` | testID not unique | Make testIDs unique or use `index` |
| `Element is not visible` | Element off-screen | Use plain `scroll` then `assertVisible` |
| `Cannot tap element` | Element behind overlay | Dismiss overlay/modal first |
| `Unknown Property: id` on `scroll` | `scroll` doesn't accept properties | Use plain `- scroll` with no args |
| `useBottomSheetInternal` crash | gorhom component outside BottomSheet | Replace `BottomSheetScrollView` with `ScrollView` |
| Element not found inside BottomSheet | gorhom Portal invisible to Maestro | Use native Modal dual-render (see #4) |
