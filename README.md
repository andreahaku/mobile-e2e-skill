# mobile-e2e

A Claude Code skill for end-to-end testing of React Native / Expo mobile apps using [Maestro](https://maestro.mobile.dev/).

## What It Does

Three workflows that form a pipeline:

1. **Analyze** — Reads your app's codebase, maps navigation and screens, inventories `testID` props, identifies gaps, and generates detailed user flow markdown docs describing what to test.

2. **Generate** — Converts flow docs into executable Maestro YAML test files: config, reusable utilities (launch, login, OTP), individual feature flows, master `run-all.yaml` for single-session execution, and a runner script.

3. **Execute & Report** — Runs Maestro tests, captures pass/fail results, classifies failures by root cause (missing testID, timeout, auth, portal, permission, etc.), and generates a diagnostic markdown report.

## Installation

Copy the skill into your Claude Code skills directory:

```bash
cp -r . ~/.claude/skills/mobile-e2e
```

Or symlink it:

```bash
ln -s "$(pwd)" ~/.claude/skills/mobile-e2e
```

The skill will be automatically detected by Claude Code.

## Usage

Invoke directly:

```
/mobile-e2e analyze                    # Analyze code → generate test plan docs
/mobile-e2e analyze login              # Analyze just the login flow
/mobile-e2e generate                   # Generate Maestro YAML from test plan docs
/mobile-e2e run staging                # Execute tests and generate report
/mobile-e2e pipeline                   # Full pipeline: analyze → generate → run
```

Or just describe what you need — the skill triggers automatically on phrases like "e2e test", "maestro test", "test plan", "generate tests", "run e2e", "release check", "find missing testIDs", etc.

## Skill Structure

```
mobile-e2e/
├── SKILL.md                           # Main skill (3 workflows, 224 lines)
├── references/
│   ├── maestro-patterns.md            # YAML templates & conventions (467 lines)
│   ├── testid-conventions.md          # testID naming rules (138 lines)
│   ├── flow-doc-template.md           # Markdown test plan template (187 lines)
│   └── troubleshooting.md            # 18 solved problems (298 lines)
└── scripts/
    └── e2e-run.template.sh            # Test runner script template (139 lines)
```

## Knowledge Base

The skill encodes patterns and solutions from real production E2E test suites:

- **18 solved problems** — iOS Keychain persistence, Expo Dev Client handling, session loss between flows, BottomSheet/Portal workarounds, OTP hidden inputs, native alert dialogs, multi-language apps, keyboard issues, and more
- **Complete Maestro templates** — config, utility flows (launch/resume/login/OTP), individual test flows, master run-all, e2e-run.sh runner
- **testID conventions** — kebab-case naming rules by feature type (auth, navigation, lists, modals, settings, etc.)
- **Session reuse architecture** — Setup (clearState + login) → Tests (resume session) → Teardown (logout)
- **Failure classification** — 10 categories with fix owner assignment
- **iOS + Android support** — platform-specific handling for keychain, back button, device commands

## Generated Output

When used on a project, the skill creates:

```
your-project/
├── .maestro/
│   ├── config.yaml
│   ├── utils/
│   │   ├── launch-app.yaml
│   │   ├── resume-app.yaml
│   │   ├── login.yaml
│   │   └── login-with-otp.yaml
│   ├── flows/
│   │   ├── smoke.yaml
│   │   ├── auth/
│   │   └── <feature>/
│   └── release-checks/
│       ├── staging/
│       │   ├── run-all.yaml
│       │   └── NN-flow-name.yaml
│       └── production/
│           ├── run-all.yaml
│           └── NN-flow-name.yaml
├── scripts/
│   └── e2e-run.sh
└── docs/e2e/
    ├── staging-test-plan.md
    ├── production-test-plan.md
    ├── E2E_TESTING_GUIDE.md
    ├── RELEASE_CHECKLIST.md
    └── reports/
        └── YYYY-MM-DD-staging.md
```

## Requirements

- [Maestro CLI](https://maestro.mobile.dev/) installed
- iOS Simulator or Android Emulator
- React Native / Expo app with Metro dev server
- Claude Code with skills support

## License

MIT
