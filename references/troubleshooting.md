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

### 4. BottomSheet / Portal Elements Not Found

**Problem:** `@gorhom/bottom-sheet` renders in a React Native Portal. Maestro can't find elements by testID inside portals.

**Solution:** Use `text` selectors instead of `id`:
```yaml
- tapOn:
    text: "Button Label"
```

If text matching doesn't work, use coordinate taps as a last resort (see #16).

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

### 17. Keyboard Covering Inputs

**Problem:** iOS keyboard covers input fields in forms, especially in modals.

**Solution:** Use `hideKeyboard` between fields:
```yaml
- tapOn:
    id: "field-1"
- inputText: "value"
- hideKeyboard
- tapOn:
    id: "field-2"
- inputText: "value"
```

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
| `Element is not visible` | Element off-screen | Use `scrollUntilVisible` first |
| `Cannot tap element` | Element behind overlay | Dismiss overlay/modal first |
