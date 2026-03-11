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
env:
  # No credentials here — loaded from .env via scripts/e2e-run.sh
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
# Via close button
- tapOn:
    id: "modal-close-button"

# Via overlay tap
- tapOn:
    id: "modal-overlay"
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

### BottomSheet / Portal Workaround

React Native BottomSheet (`@gorhom/bottom-sheet`) renders in a Portal — testIDs are invisible to Maestro. Use text selectors or coordinate taps instead.

```yaml
# Try text first
- tapOn:
    text: "Button Label"

# Coordinate fallback — document calibration device!
# Calibrated for: <device model> (<resolution>)
- tapOn:
    point: "50%,90%"
    optional: true
```

### Keyboard & Text Management

```yaml
# Dismiss keyboard
- hideKeyboard
# or
- pressKey: Escape

# Clear pre-filled text before typing
- eraseText: 20
- inputText: "new value"

# Dismiss keyboard between form fields (prevents keyboard covering next input)
- tapOn:
    id: "email-input"
- inputText: "test@example.com"
- hideKeyboard
- tapOn:
    id: "password-input"
- inputText: "password123"
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
