---
name: mobile-e2e
description: >
  Mobile E2E testing with Maestro for React Native / Expo apps. Three workflows:
  (1) Analyze code and generate user flow markdown docs describing what to test,
  (2) Generate Maestro YAML test files from those docs,
  (3) Execute tests and generate diagnostic reports with failure root-cause analysis.
  Use this skill whenever the user mentions E2E testing, Maestro, mobile test automation,
  test plans, user flows, testIDs, test coverage for mobile, QA workflows, acceptance testing,
  release checks, smoke tests, or regression testing for React Native apps. Also trigger when
  the user asks to "add testIDs", "find missing testIDs", "improve test coverage", "write
  maestro tests", "run e2e", "e2e report", "create test flows", "document user flows",
  "generate yaml tests", or "release check". Even if the user doesn't say "Maestro" explicitly,
  if they're working on a React Native / Expo app and mention E2E or integration testing,
  this skill applies.
argument-hint: "<workflow> [target]"
---

# Mobile E2E Testing Skill

End-to-end testing for React Native / Expo mobile apps using [Maestro](https://maestro.mobile.dev/). Three workflows that form a pipeline: analyze code → generate flow docs → generate Maestro YAML → execute & report.

## Workflows

Determine which workflow(s) the user needs:

| User Request | Workflow | Command |
|---|---|---|
| "analyze flows", "generate test plan", "document user flows", "find missing testIDs" | **1. Flow Analysis** | `/mobile-e2e analyze [screen/feature]` |
| "generate maestro tests", "create yaml tests", "write e2e" | **2. YAML Generation** | `/mobile-e2e generate [flow-doc.md]` |
| "run e2e", "execute tests", "e2e report" | **3. Execute & Report** | `/mobile-e2e run [environment]` |
| "full pipeline", "e2e from scratch" | **All three** | `/mobile-e2e pipeline [feature]` |

## When to Read Reference Files

Each reference file serves a specific purpose — only read what you need:

| Reference | Read When |
|-----------|-----------|
| `references/maestro-patterns.md` | Generating YAML files (Workflow 2). Contains all templates: config, utilities, flows, master flow, common patterns |
| `references/testid-conventions.md` | Analyzing testIDs or recommending new ones (Workflow 1). Contains naming rules and examples |
| `references/flow-doc-template.md` | Writing markdown test plan docs (Workflow 1). Contains the output template |
| `references/troubleshooting.md` | Debugging test failures (Workflow 3), or when generating YAML and you need to handle a known edge case. Contains 18 solved problems |

---

## Workflow 1: Flow Analysis → Markdown Docs

**Goal:** Analyze the app's codebase and produce detailed user flow documents that describe what to test.

### Steps

1. **Discover app structure**
   - Read `app.json` / `app.config.ts` to get `appId`
   - Find navigation structure: search for `createStackNavigator`, `createDrawerNavigator`, `createBottomTabNavigator`, `Screen name=`
   - Find all screen components (search for `Screen`, `export default`, screen-level components)

2. **Inventory testIDs**
   - Search for `testID` props across all `.tsx` files
   - Build a map of `screen → [testIDs]`
   - Flag screens with zero or few testIDs as **gaps**
   - Read `references/testid-conventions.md` for naming rules when recommending new testIDs

3. **Map user flows**
   - For each screen/feature, trace the user journey:
     - Entry point (how the user gets there)
     - Interactive elements (buttons, inputs, toggles, lists)
     - State changes (loading, empty, error, success)
     - Exit points (back navigation, drawer, tabs)
   - Classify flows by priority: P0 (critical path), P1 (important), P2 (nice-to-have)

4. **Generate markdown doc**
   - Read `references/flow-doc-template.md` for the output template
   - Output goes to `docs/e2e/<feature-name>-test-plan.md`
   - Include: flow descriptions, step-by-step actions, testIDs used, pass criteria, gaps/blockers

### Output Structure

```
docs/e2e/
├── <feature>-test-plan.md      # Per-feature test plans
├── staging-test-plan.md        # Full staging test plan (all features)
├── production-test-plan.md     # Production-safe subset (read-only)
├── E2E_TESTING_GUIDE.md        # Developer guide for writing new tests
└── RELEASE_CHECKLIST.md        # Pre-release procedures
```

### Scoping

If the user specifies a feature (e.g., "analyze the login flow"), only analyze that feature's screens and produce a single flow doc. Don't analyze the entire app unless asked.

---

## Workflow 2: YAML Generation → Maestro Tests

**Goal:** Convert flow documentation into executable Maestro YAML files.

Read `references/maestro-patterns.md` before generating any YAML — it contains all templates and conventions extracted from production test suites.

### Steps

1. **Read the flow doc** — parse the markdown test plan to extract steps, testIDs, and assertions

2. **Setup project structure** (if `.maestro/` doesn't exist)
   ```
   .maestro/
   ├── config.yaml              # Global config (appId, timeouts, env vars)
   ├── utils/                   # Reusable sub-flows
   │   ├── launch-app.yaml      # Fresh launch (clearState + clearKeychain)
   │   ├── resume-app.yaml      # Resume existing session
   │   ├── login.yaml           # Basic login (no OTP)
   │   └── login-with-otp.yaml  # Full login + OTP
   ├── flows/                   # Feature-level test flows
   │   ├── smoke.yaml
   │   ├── auth/
   │   └── <feature>/
   └── release-checks/          # Pre-release suites
       ├── staging/
       │   ├── run-all.yaml     # Master flow (single session)
       │   └── NN-flow-name.yaml
       └── production/
           ├── run-all.yaml
           └── NN-flow-name.yaml
   ```

3. **Generate files** using the templates from `references/maestro-patterns.md`:
   - config.yaml, utility flows, test flows, run-all.yaml master flows
   - `scripts/e2e-run.sh` — runner script that loads `.env` credentials

4. **Platform considerations**:
   - **iOS**: Use `clearKeychain: true`, handle Expo Dev Client launcher, swipe RIGHT for drawer
   - **Android**: Use `clearState: true` (keychain not an issue), handle back button with `pressKey: back`

### Key Conventions (details in maestro-patterns.md)

- Use `extendedWaitUntil` for dynamic content, `assertVisible` only after screen is confirmed loaded
- Use `optional: true` for permission-gated or state-dependent elements
- Never hardcode credentials — use `${ENV_VAR}` syntax loaded from `.env`
- Production flows are READ-ONLY (no sends, no edits, no deletes)
- Flows run sequentially sharing one session. `run-all.yaml` ensures this
- Handle multi-language alerts with `optional: true` for each language variant
- Handle BottomSheet/Portal elements with `text` selectors (testIDs don't work in portals)

---

## Workflow 3: Execute & Report

**Goal:** Run Maestro tests and produce a diagnostic report.

Read `references/troubleshooting.md` when analyzing failures — it contains 18 solved problems from real projects.

### Steps

1. **Pre-flight checks**
   ```bash
   maestro --version                                    # Maestro installed
   xcrun simctl list devices booted                     # Simulator booted (iOS)
   adb devices                                          # Emulator running (Android)
   lsof -i :8081 -i :8082 | grep LISTEN                # Metro running
   xcrun simctl listapps booted | grep <appId>          # App installed
   ```

2. **Execute tests**
   - Single flow: `maestro test .maestro/flows/<flow>.yaml`
   - Release suite: `./scripts/e2e-run.sh <staging|production>`
   - With JUnit output: `maestro test --format junit --output report.xml <flow>`
   - With env overrides: `maestro test -e EMAIL=x -e PASSWORD=y <flow>`

3. **Capture results** — parse Maestro output for PASSED/FAILED per flow, collect timing

4. **Generate report** — output to `docs/e2e/reports/YYYY-MM-DD-<env>.md`

### Report Format

```markdown
# E2E Test Report — <Environment>
**Date:** YYYY-MM-DD HH:MM
**Device:** <simulator/emulator name + OS version>
**App Version:** <from app.json>
**Total:** X flows | Passed: Y | Failed: Z

## Results

| # | Flow | Status | Duration | Notes |
|---|------|--------|----------|-------|
| 01 | App Launch | PASS | 12s | |
| 02 | Login Flow | PASS | 8s | |
| 03 | Feature X | FAIL | 30s | Timeout on element-id |

## Failures

### 03 — Feature X (FAILED)
**Error:** <exact Maestro error>
**Root Cause Analysis:**
- [ ] **Missing testID**: Check if testID exists in component
- [ ] **Loading timeout**: Screen takes too long to load
- [ ] **Auth session lost**: Previous flow broke the session
- [ ] **Navigation issue**: Screen didn't navigate correctly

**Recommended Fix:** <specific recommendation>

## TestID Coverage Gaps
| Screen | Missing testIDs | Impact |
|--------|----------------|--------|
| ScreenName | No testIDs found | Cannot test this screen |

## Recommendations
- <actionable next steps>
```

### Failure Classification

| Category | Description | Fix Owner |
|----------|-------------|-----------|
| **Missing testID** | Element has no testID prop | App Developer |
| **Wrong testID** | testID doesn't match YAML | Test Author |
| **Timeout** | Element loads too slowly | App Developer / Infra |
| **Navigation** | Wrong screen displayed | App Developer |
| **Auth** | Session expired or login failed | Backend / Config |
| **Portal/Modal** | Element in Portal not accessible by ID | Test Author (use text selector) |
| **Animation** | Element hidden during animation | Test Author (add wait) |
| **Permission** | Feature gated by user role | Config (test account perms) |
| **Flaky** | Intermittent failures | Test Author (add waits/retries) |
| **Not Implemented** | Feature not yet built | App Developer |
