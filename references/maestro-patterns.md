# Maestro YAML Patterns Reference

Complete pattern library extracted from production E2E test suites. Use this when generating Maestro YAML files (Workflow 2).

## Table of Contents

1. [Config Template](#config-template)
2. [Utility Flow Templates](#utility-flow-templates)
3. [Individual Flow Template](#individual-flow-template)
4. [Master Flow Template](#master-flow-template)
5. [Common Patterns](#common-patterns)
6. [Runner Script](#runner-script)
7. [Timeout Strategy](#timeout-strategy)

---

## Config Template

```yaml
# .maestro/config.yaml
appId: <appId from app.json>
name: <Project Name> E2E Tests
defaultTimeout: 30000
tags:
  - smoke
  - auth
  - navigation
  # Add feature-specific tags
# Environment variables (loaded from .env via scripts/e2e-run.sh)
# No credentials stored here — see .env.example for required variables
```

### Environment Variables — MAESTRO_ Prefix Rule

**CRITICAL:** Maestro only auto-imports shell environment variables that start with `MAESTRO_`. Variables without this prefix are invisible to Maestro flows.

**`.env` file** (gitignored):
```bash
MAESTRO_ADMIN_EMAIL=admin@example.com
MAESTRO_ADMIN_PASSWORD=changeme
MAESTRO_STAGING_EMAIL=staging@example.com
MAESTRO_STAGING_PASSWORD=changeme
```

**Runner script** (`scripts/e2e-run.sh`):
```bash
# Source .env to export all MAESTRO_ vars into the shell environment
set -a
source "$PROJECT_ROOT/.maestro/.env"   # or "$PROJECT_ROOT/.env"
set +a
maestro test "$TARGET"  # Maestro auto-imports MAESTRO_* vars
```

**YAML flow header** — map MAESTRO_ vars to shorter local names:
```yaml
appId: com.example.app
env:
  EMAIL: ${MAESTRO_ADMIN_EMAIL}
  PASSWORD: ${MAESTRO_ADMIN_PASSWORD}
---
- tapOn:
    id: "email-input"
- inputText: ${EMAIL}           # Resolves to the MAESTRO_ADMIN_EMAIL value
```

**Without the runner script** — pass vars explicitly via CLI:
```bash
maestro test -e MAESTRO_ADMIN_EMAIL=admin@example.com flow.yaml
```

## Utility Flow Templates

### launch-app.yaml (Fresh Start)

```yaml
# Launch App Utility — fresh start with state clearing
appId: <appId>
---
# clearKeychain is needed because iOS Keychain survives clearState —
# without it, auth tokens persist and the app restores a stale session
- launchApp:
    clearState: true
    clearKeychain: true  # iOS only; harmless on Android

# Handle Expo Dev Client launcher (appears after clearState on dev builds)
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

# Dismiss dev menu overlay
- tapOn:
    point: "95%,42%"
    optional: true
```

### resume-app.yaml (Session Reuse)

```yaml
# Resume App Utility — preserves existing session
# Use for flows 03+ that depend on login from flow 02
appId: <appId>
---
- launchApp:
    clearState: false

# Same Expo Dev Client handling as launch-app
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

### login.yaml (Basic — No OTP)

```yaml
# Usage: runFlow with env EMAIL and PASSWORD
appId: <appId>
---
- extendedWaitUntil:
    visible:
      id: "login-screen"
    timeout: 30000

- tapOn:
    id: "login-email-input"
- inputText: ${EMAIL}

- tapOn:
    id: "login-password-input"
- inputText: ${PASSWORD}

- tapOn:
    id: "login-button"
```

### login-with-otp.yaml (Full Auth)

```yaml
# Usage: runFlow with env EMAIL, PASSWORD, and OTP
appId: <appId>
---
- extendedWaitUntil:
    visible:
      id: "login-screen"
    timeout: 30000

- tapOn:
    id: "login-email-input"
- inputText: ${EMAIL}
- tapOn:
    id: "login-password-input"
- inputText: ${PASSWORD}
- tapOn:
    id: "login-button"

# OTP — tap boxes container to focus the hidden input
- extendedWaitUntil:
    visible:
      id: "otp-screen"
    timeout: 30000

- tapOn:
    id: "otp-boxes-container"
- inputText: ${OTP}

- tapOn:
    id: "verify-otp-button"
    optional: true

# App may auto-open a deep link — handle by going back if needed
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

## Individual Flow Template

```yaml
# <Environment> Release Check NN: <Flow Name>
# <What this tests>
appId: <appId>
tags:
  - release
  - <environment>
  - <feature>
---
- runFlow:
    file: ../../utils/resume-app.yaml

- extendedWaitUntil:
    visible:
      id: "<main-screen-id>"
    timeout: 30000

# =============================================================================
# 1. <Section Name>
# =============================================================================
- assertVisible:
    id: "<element-id>"

# ... test steps ...

# =============================================================================
# N. Navigate back
# =============================================================================
- tapOn:
    id: "<back-button-id>"

- extendedWaitUntil:
    visible:
      id: "<main-screen-id>"
    timeout: 10000
```

## Master Flow Template

The master flow (`run-all.yaml`) inlines all test steps in a single Maestro session, preventing session loss between flows.

```yaml
# <Environment> Release Checks — Master Flow
appId: <appId>
tags:
  - release
  - <environment>
env:
  EMAIL: ${MAESTRO_<ENV>_EMAIL}
  PASSWORD: ${MAESTRO_<ENV>_PASSWORD}
  OTP: ${MAESTRO_<ENV>_OTP}
---
# =============================================================================
# PHASE 1: Setup — fresh launch + login
# =============================================================================
- runFlow:
    file: ../../utils/launch-app.yaml

# ... login steps inline (not via runFlow, to keep single session) ...

# =============================================================================
# PHASE 2: Tests — all within same session
# =============================================================================
# --- 03: <Flow Name> ---
# ... inline test steps ...

# =============================================================================
# PHASE 3: Teardown — logout
# =============================================================================
# ... logout steps ...
```

## Common Patterns

### Waiting for Elements

```yaml
# Use extendedWaitUntil for dynamic content — it waits up to the timeout
- extendedWaitUntil:
    visible:
      id: "element-id"
    timeout: 30000

# Use assertVisible only AFTER the screen is confirmed loaded
- assertVisible:
    id: "element-id"
```

### Optional Elements

```yaml
# For permission-gated or state-dependent elements
- assertVisible:
    id: "admin-only-button"
    optional: true

# Mutually exclusive states (e.g., archive OR unarchive)
- assertVisible:
    id: "option-archive"
    optional: true
- assertVisible:
    id: "option-unarchive"
    optional: true
```

### Tapping List Items

```yaml
- tapOn:
    id: "list-container"
    index: 0
    childOf:
      id: "list-container"
```

### Drawer Navigation

```yaml
# Prefer button over gesture — gesture is unreliable in Maestro
- tapOn:
    id: "drawer-menu-button"

- extendedWaitUntil:
    visible:
      id: "drawer-<section>-item"
    timeout: 5000

- tapOn:
    id: "drawer-<section>-item"

- extendedWaitUntil:
    visible:
      id: "<section>-screen"
    timeout: 30000
```

### Tab Navigation

```yaml
- tapOn:
    id: "tab-<name>"

- extendedWaitUntil:
    visible:
      id: "<name>-screen"
    timeout: 5000
```

### Scroll Until Visible

**Note:** `scrollUntilVisible` can be unreliable. Prefer plain `- scroll` when possible (see "Scroll Command Limitations" below).

```yaml
- scrollUntilVisible:
    element:
      id: "element-at-bottom"
    direction: DOWN
    timeout: 10000
```

### Sending Messages (STAGING ONLY)

```yaml
# WARNING: sends a real message — staging environments only
- tapOn:
    text: "Type a message..."
- inputText: "[E2E-STAGING] Test message - please ignore"
- tapOn:
    id: "send-button"

- extendedWaitUntil:
    visible:
      text: "Test message"
    timeout: 10000
    optional: true  # message text may not be Maestro-accessible
```

### Modal Dismissal

```yaml
# Via close button (preferred)
- tapOn:
    id: "modal-close-button"

# Via overlay tap
- tapOn:
    id: "modal-overlay"

# Via coordinate tap (for BottomSheets without close button)
# Note: pressKey: Escape does NOT work on iOS
- tapOn:
    point: "50%,10%"
    optional: true
```

### Logout (Multi-language)

Handle multiple languages by trying each with `optional: true`. Use `index: 1` because native iOS alerts show the title at index 0 and the button at index 1.

```yaml
- tapOn:
    id: "settings-logout-button"

# Try each supported language — only one will match
- tapOn:
    text: "Logout"
    index: 1
    optional: true
- tapOn:
    text: "Esci"        # Italian
    index: 1
    optional: true
# Add more languages as needed:
# - tapOn: { text: "Déconnexion", index: 1, optional: true }

- extendedWaitUntil:
    visible:
      id: "login-screen"
    timeout: 30000
```

### BottomSheet / Portal — Native Modal Dual-Render Strategy

**CRITICAL:** `@gorhom/bottom-sheet` renders content in an internal Portal layer that is completely invisible to Maestro's accessibility tree. **Neither `testID` nor `text` selectors work** — not `tapOn: id:`, not `tapOn: text:`, not `assertVisible`. This is a fundamental limitation of how gorhom renders content outside the normal React Native view hierarchy.

**The only reliable solution** is a dual-render approach: render BottomSheet content inside a native React Native `<Modal>` during E2E tests, while keeping the smooth BottomSheet UX for regular users.

#### Implementation Pattern

1. **Add `EXPO_PUBLIC_E2E_TEST` env var** — Expo makes `EXPO_PUBLIC_*` vars available at runtime via `process.env`. Set it before starting Metro:
   ```bash
   EXPO_PUBLIC_E2E_TEST=true npx expo start --clear
   ```
   **IMPORTANT:** Metro must be restarted when changing env vars — hot reload doesn't pick them up.

2. **Add `useNativeModal` prop** to BottomSheet components:
   ```tsx
   const isE2E = process.env.EXPO_PUBLIC_E2E_TEST === 'true';

   // In the parent screen:
   <CheckAvailabilityModal useNativeModal={isE2E} onClose={handleClose} />
   ```

3. **Dual render path** in the BottomSheet component:
   ```tsx
   interface Props {
     useNativeModal?: boolean;
     // ... other props
   }

   const renderNativeModal = () => (
     <Modal visible animationType="slide" presentationStyle="pageSheet"
       onRequestClose={handleClose}>
       <SafeAreaView style={styles.nativeModalContainer}>
         <View style={styles.nativeModalHandle} />
         <ScrollView keyboardShouldPersistTaps="handled">
           {renderStepContent()}  {/* Shared step rendering logic */}
         </ScrollView>
       </SafeAreaView>
     </Modal>
   );

   const renderBottomSheet = () => (
     <BottomSheet ref={bottomSheetRef} index={0} snapPoints={snapPoints}>
       <BottomSheetScrollView>
         {renderStepContent()}
       </BottomSheetScrollView>
     </BottomSheet>
   );

   return useNativeModal ? renderNativeModal() : renderBottomSheet();
   ```

4. **Replace `BottomSheetScrollView`** — Components using `BottomSheetScrollView` crash with `"useBottomSheetInternal cannot be used out of the BottomSheet!"` when rendered inside a native `<Modal>`. Replace with regular `ScrollView` from `react-native` in any content component that needs to work in both modes.

5. **Use conditional mounting** instead of `index={-1}`:
   ```tsx
   // Instead of keeping BottomSheet always mounted with index={-1}:
   const [isOpen, setIsOpen] = useState(false);
   // ...
   {isOpen && <MyBottomSheetModal useNativeModal={isE2E} onClose={() => setIsOpen(false)} />}
   ```

#### Why Native Modal Works

React Native's `<Modal>` renders in a new native `UIViewController` (iOS) / `Dialog` (Android), creating a **separate accessibility root** that Maestro reads perfectly. All testIDs and text selectors work normally inside it.

#### Maestro YAML for Native Modal Content

Once content is in a native Modal, standard selectors work:
```yaml
# Tap button that opens the BottomSheet (visible on main screen)
- tapOn:
    id: "quick-action-check-availability"

# Wait for content inside the native Modal — testIDs now work!
- extendedWaitUntil:
    visible:
      id: "check-availability-close"
    timeout: 10000

# Interact with form elements normally
- tapOn:
    id: "check-availability-search"

# Close via testID
- tapOn:
    id: "check-availability-close"
```

#### Coordinate Taps — Last Resort Only

For BottomSheets that haven't been migrated to the dual-render approach, coordinate taps are the only option. Always document the calibration device:
```yaml
# Calibrated for: iPhone 16e (390×844), iOS 26.0
- tapOn:
    point: "50%,10%"   # Tap outside bottom sheet to close
    optional: true
```

### Scroll Command Limitations

**CRITICAL:** Maestro's `scroll` command does NOT accept `id:` or other properties. It only scrolls the main screen.

```yaml
# ✅ CORRECT — plain scroll
- scroll

# ❌ WRONG — "Unknown Property: id"
- scroll:
    id: "my-scroll-view"
    direction: DOWN
```

**`scrollUntilVisible` is unreliable** — it sometimes fails to find elements even when they exist. Prefer plain `- scroll` (one or more times) followed by `assertVisible` or `extendedWaitUntil`:
```yaml
# ✅ Preferred — simple and reliable
- scroll
- scroll
- assertVisible:
    id: "element-at-bottom"

# ⚠️ Less reliable — may timeout even when element exists
- scrollUntilVisible:
    element:
      id: "element-at-bottom"
    direction: DOWN
    timeout: 10000
```

### SegmentedControl Interaction

Tapping a SegmentedControl **container** testID hits the divider between segments, not a segment. Always tap the individual segment testID.

Component pattern: `${containerTestID}-${option.key}`
```yaml
# ❌ WRONG — taps the divider
- tapOn:
    id: "view-toggle"

# ✅ CORRECT — taps the specific segment
- tapOn:
    id: "view-toggle-calendar"   # key = "calendar"
- tapOn:
    id: "view-toggle-list"       # key = "list"
```

### StepHeader Back Button

StepHeader components generate a back button with `${testID}-back` suffix. Tapping the header container won't trigger navigation.

```yaml
# ❌ WRONG — taps the header container (no effect)
- tapOn:
    id: "results-step-header"

# ✅ CORRECT — taps the actual back button
- tapOn:
    id: "results-step-header-back"
```

### pressKey: Escape — iOS Limitation

`pressKey: Escape` does NOT work on iOS simulators for dismissing modals or bottom sheets. Use coordinate taps or close buttons instead.

```yaml
# ❌ WRONG — no effect on iOS
- pressKey: Escape

# ✅ CORRECT — tap outside the modal area
- tapOn:
    point: "50%,10%"
    optional: true

# ✅ BEST — use a close button testID
- tapOn:
    id: "modal-close-button"
```

### assertNotVisible Limitation

`assertNotVisible` only works for elements that **exist in the tree but are hidden**. It fails (errors) for elements whose testID doesn't exist at all.

```yaml
# ✅ Works — element exists but is hidden/off-screen
- assertNotVisible:
    id: "loading-spinner"

# ❌ Fails — testID doesn't exist in the tree
- assertNotVisible:
    id: "nonexistent-element"
```

### clearInput — Invalid Command

`clearInput` is NOT a valid Maestro command. Use `eraseText` instead:

```yaml
# ❌ WRONG — not a Maestro command
- clearInput:
    id: "email-input"

# ✅ CORRECT
- tapOn:
    id: "email-input"
- eraseText: 50
- inputText: "new-value@example.com"
```

### Empty State Handling

Use `optional: true` for elements that depend on data state (empty vs populated):
```yaml
# Data-dependent — may or may not exist
- assertVisible:
    text: "Blocked Dates"
    optional: true

- tapOn:
    text: "Unblock"
    optional: true
```

### Keyboard & Text Management

**CRITICAL: NEVER use `hideKeyboard`** — on iOS it causes Maestro to tap on the keyboard itself, inserting a stray character (typically `t` or `y`) into the focused field. This corrupts passwords, emails, and form data silently.

Two safe alternatives:
1. **Tap next element by testID** — tapping any element above the keyboard dismisses it automatically
2. **`pressKey: enter`** — simulates the Return/Done key on iOS keyboard, cleanly dismissing it without side effects. Use this when the next element is BEHIND the keyboard.

```yaml
# ❌ WRONG — hideKeyboard inserts stray characters on iOS
- tapOn:
    id: "email-input"
- inputText: "test@example.com"
- hideKeyboard                    # May type 't' into email field!

# ✅ CORRECT — tap next field directly (keyboard auto-dismisses)
- tapOn:
    id: "email-input"
- inputText: "test@example.com"
- tapOn:
    id: "password-input"          # Keyboard dismisses on its own
- inputText: "password123"

# ✅ CORRECT — when submit button is BEHIND keyboard, use pressKey enter first
- pressKey: enter                 # Dismisses keyboard cleanly
- tapOn:
    id: "submit-button"           # Now visible and tappable

# Clear pre-filled text before typing
- eraseText: 20
- inputText: "new value"
```

### Screenshots

```yaml
- takeScreenshot: "descriptive-name-step-01"
```

### Android-Specific

```yaml
# Back button (Android hardware/gesture back)
- pressKey: back

# Android doesn't need clearKeychain — clearState is sufficient
- launchApp:
    clearState: true
```

## Runner Script

The `e2e-run.sh` template is at `~/.claude/skills/mobile-e2e/scripts/e2e-run.template.sh`. Copy it to the project's `scripts/` directory when generating the test infrastructure.

It handles:
- Loading credentials from `.env`
- Validating required env vars per environment
- Running the master flow (default) or individual flows
- Pass/fail summary with failed flow names

## Timeout Strategy

| Context | Timeout | Why |
|---------|---------|-----|
| Cold start (launchApp) | 60000ms | JS bundle load + app init |
| Screen load (API data) | 30000ms | Network request + render |
| Navigation transition | 10000ms | Quick animation |
| Modal/overlay appear | 5000ms | Near-instant |
| OTP manual entry | 120000ms | Human enters code from email |
| Dev client bundle | 60000ms | Metro compilation |
