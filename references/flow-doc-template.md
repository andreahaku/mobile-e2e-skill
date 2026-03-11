# Flow Documentation Template

Use this template when generating user flow markdown docs (Workflow 1).

## Test Plan Template

```markdown
# E2E Test Plan — <Environment> Environment

**Target:** `.maestro/release-checks/<environment>/`
**Command:** `<package-manager> e2e:release:<environment>`
**Scope:** <Full feature coverage | Critical paths only>
**Last verified:** <date>

---

## Architecture

### Session Reuse Pattern

Flows are designed to run **sequentially** and share a single authenticated session:

| Phase | Flows | Utility | clearState |
|-------|-------|---------|------------|
| **Setup** | 01, 02 | `launch-app.yaml` | Yes (`clearState + clearKeychain`) |
| **Tests** | 03–NN | `resume-app.yaml` | No (reuses session from 02) |
| **Teardown** | NN+1 | `resume-app.yaml` | No (logs out at end) |

- **`launch-app.yaml`**: Clears app state + iOS Keychain, handles Expo Dev Client launcher
- **`resume-app.yaml`**: Launches without clearing state, handles Dev Client if needed
- **`login-with-otp.yaml`**: Email/password → OTP → waits for main screen

> **Important:** Flows MUST run sequentially (not in parallel). Use the master `run-all.yaml` flow or a wrapper script.

### iOS Keychain Note

`clearState: true` alone does NOT clear the iOS Keychain. Auth tokens stored in Keychain survive app data reset, causing stale session restoration. `launch-app.yaml` uses `clearKeychain: true` to prevent this.

---

## Environment Configuration

\```yaml
env:
  EMAIL: "<test-account-email>"
  PASSWORD: "<test-account-password>"
  OTP: "<static-otp-or-placeholder>"
\```

---

## Flow Index

| # | Flow | File | Priority | Session | Status |
|---|------|------|----------|---------|--------|
| 01 | App Launch & Cold Start | `01-app-launch.yaml` | P0 | Fresh | Not Implemented |
| 02 | Login Flow | `02-login-flow.yaml` | P0 | Fresh | Not Implemented |
| ... | ... | ... | ... | ... | ... |
| NN | Logout | `NN-logout.yaml` | P0 | Reuse | Not Implemented |

---

## Flow Descriptions

### 01 — App Launch & Cold Start (P0)

**Goal:** Verify the app boots correctly and renders the login screen.

**Steps:**
1. Run `launch-app.yaml` (clearState + clearKeychain + Dev Client handling)
2. Wait for login screen (`login-screen`, 60s timeout)
3. Assert visible: `login-email-input`
4. Assert visible: `login-password-input`
5. Assert visible: `login-button`

**testIDs required:** `login-screen`, `login-email-input`, `login-password-input`, `login-button`

**Pass criteria:** Login screen fully rendered within 60s of cold start.

**Gaps:** <list any missing testIDs or blockers>

---

### NN — <Flow Name> (<Priority>)

**Goal:** <one sentence>

**Preconditions:** <required permissions, test data, etc.>

**Steps:**
1. <step>
2. <step>
...

**testIDs required:** <list all testIDs this flow depends on>

**Pass criteria:** <what defines success>

**Gaps:** <missing testIDs, features not implemented, etc.>

**Notes:**
- <production safety notes>
- <optional assertions for permission-gated content>

---

## Gaps & Future Improvements

| Feature | Flow | Reason Not Implemented |
|---------|------|----------------------|
| <feature> | NN | <missing testID / not built yet> |

---

## Coverage Matrix

| Screen | Covered By |
|--------|-----------|
| LoginScreen | 01, 02 |
| ... | ... |

---

## <Environment> Safety Rules (Production only)

1. **NEVER send messages**
2. **NEVER modify data**
3. **NEVER archive/delete**
4. **Read-only navigation only**
5. **Dedicated test account** with limited data
```

## Individual Flow Description Template

When documenting a single feature (not full plan):

```markdown
# E2E Flow: <Feature Name>

**Screen:** `<ScreenComponent>`
**File:** `src/screens/<path>`
**Priority:** P0 | P1 | P2

## User Journey

### Entry Points
- <how user reaches this screen>

### Core Interactions
1. <interaction> → testID: `<id>` → expected: <result>
2. <interaction> → testID: `<id>` → expected: <result>

### State Variations
- **Loading:** <what user sees while loading>
- **Empty:** <empty state UI>
- **Error:** <error state UI>
- **Success:** <populated state>

### Exit Points
- <back button, drawer, tab switch>

## testID Inventory

| Element | testID | Status |
|---------|--------|--------|
| Screen wrapper | `feature-screen` | EXISTS |
| Submit button | `feature-submit-button` | MISSING |
| List | `feature-list` | EXISTS |

## Suggested Test Steps

### Happy Path
1. Navigate to feature screen
2. Verify core elements visible
3. Interact with primary action
4. Verify result
5. Navigate back

### Edge Cases
- Empty list state
- Error state recovery
- Permission denied (role-based)

## Blockers
- [ ] `feature-submit-button` testID missing — add to `<Component>`
- [ ] Empty state not rendered — component needs implementation
```
