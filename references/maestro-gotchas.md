# Maestro Gotchas & Platform Limitations

Known Maestro pitfalls and their solutions. Read this alongside `maestro-templates.md` when generating YAML (Workflow 2), and consult it when debugging failures (Workflow 3).

## Table of Contents

1. [BottomSheet / Portal — Native Modal Dual-Render](#bottomsheet--portal--native-modal-dual-render)
2. [Scroll Command Limitations](#scroll-command-limitations)
3. [SegmentedControl Interaction](#segmentedcontrol-interaction)
4. [StepHeader Back Button](#stepheader-back-button)
5. [pressKey: Escape — iOS Limitation](#presskey-escape--ios-limitation)
6. [assertNotVisible Limitation](#assertnotvisible-limitation)
7. [clearInput — Invalid Command](#clearinput--invalid-command)
8. [Keyboard & Text Management](#keyboard--text-management)
9. [Empty State Handling](#empty-state-handling)
10. [Coordinate Taps — Last Resort](#coordinate-taps--last-resort)

---

## BottomSheet / Portal — Native Modal Dual-Render

`@gorhom/bottom-sheet` renders content in an internal Portal layer that is completely invisible to Maestro's accessibility tree. **Neither `testID` nor `text` selectors work** — not `tapOn: id:`, not `tapOn: text:`, not `assertVisible`. This is a fundamental limitation of how gorhom renders content outside the normal React Native view hierarchy.

**The only reliable solution** is a dual-render approach: render BottomSheet content inside a native React Native `<Modal>` during E2E tests, while keeping the smooth BottomSheet UX for regular users.

### Implementation

1. **Add `EXPO_PUBLIC_E2E_TEST` env var** — Expo makes `EXPO_PUBLIC_*` vars available at runtime via `process.env`. Set it before starting Metro:
   ```bash
   EXPO_PUBLIC_E2E_TEST=true npx expo start --clear
   ```
   **IMPORTANT:** Metro must be restarted when changing env vars — hot reload doesn't pick them up.

2. **Add `useNativeModal` prop** to BottomSheet components:
   ```tsx
   const isE2E = process.env.EXPO_PUBLIC_E2E_TEST === 'true';
   <CheckAvailabilityModal useNativeModal={isE2E} onClose={handleClose} />
   ```

3. **Dual render path** in the BottomSheet component:
   ```tsx
   interface Props {
     useNativeModal?: boolean;
   }

   const renderNativeModal = () => (
     <Modal visible animationType="slide" presentationStyle="pageSheet"
       onRequestClose={handleClose}>
       <SafeAreaView style={styles.nativeModalContainer}>
         <View style={styles.nativeModalHandle} />
         <ScrollView keyboardShouldPersistTaps="handled">
           {renderStepContent()}
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

4. **Replace `BottomSheetScrollView`** — crashes with `"useBottomSheetInternal cannot be used out of the BottomSheet!"` when rendered inside a native `<Modal>`. Replace with regular `ScrollView` from `react-native` in content components that need to work in both modes.

5. **Use conditional mounting** instead of `index={-1}`:
   ```tsx
   const [isOpen, setIsOpen] = useState(false);
   {isOpen && <MyBottomSheetModal useNativeModal={isE2E} onClose={() => setIsOpen(false)} />}
   ```

### Why Native Modal Works

React Native's `<Modal>` renders in a new native `UIViewController` (iOS) / `Dialog` (Android), creating a **separate accessibility root** that Maestro reads perfectly. All testIDs and text selectors work normally inside it.

### Maestro YAML for Native Modal Content

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

---

## Scroll Command Limitations

Maestro's `scroll` command does NOT accept `id:` or other properties. It only scrolls the main screen.

```yaml
# CORRECT — plain scroll
- scroll

# WRONG — "Unknown Property: id"
- scroll:
    id: "my-scroll-view"
    direction: DOWN
```

**`scrollUntilVisible` is unreliable** — it sometimes fails to find elements even when they exist. Prefer plain `- scroll` (one or more times) followed by `assertVisible` or `extendedWaitUntil`:
```yaml
# Preferred — simple and reliable
- scroll
- scroll
- assertVisible:
    id: "element-at-bottom"
```

---

## SegmentedControl Interaction

Tapping a SegmentedControl **container** testID hits the divider between segments, not a segment. Always tap the individual segment testID.

Component pattern: `${containerTestID}-${option.key}`
```yaml
# WRONG — taps the divider
- tapOn:
    id: "view-toggle"

# CORRECT — taps the specific segment
- tapOn:
    id: "view-toggle-calendar"   # key = "calendar"
- tapOn:
    id: "view-toggle-list"       # key = "list"
```

---

## StepHeader Back Button

StepHeader components generate a back button with `${testID}-back` suffix. Tapping the header container won't trigger navigation.

```yaml
# WRONG — taps the header container (no effect)
- tapOn:
    id: "results-step-header"

# CORRECT — taps the actual back button
- tapOn:
    id: "results-step-header-back"
```

---

## pressKey: Escape — iOS Limitation

`pressKey: Escape` does NOT work on iOS simulators for dismissing modals or bottom sheets. Use close buttons or coordinate taps instead.

```yaml
# WRONG — no effect on iOS
- pressKey: Escape

# BEST — use a close button testID
- tapOn:
    id: "modal-close-button"

# OK — tap outside the modal area
- tapOn:
    point: "50%,10%"
    optional: true
```

---

## assertNotVisible Limitation

`assertNotVisible` only works for elements that **exist in the tree but are hidden**. It fails (errors) for elements whose testID doesn't exist at all.

```yaml
# Works — element exists but is hidden/off-screen
- assertNotVisible:
    id: "loading-spinner"

# Fails — testID doesn't exist in the tree
- assertNotVisible:
    id: "nonexistent-element"

# For checking element absence, use optional assertVisible
- assertVisible:
    id: "maybe-present-element"
    optional: true
```

---

## clearInput — Invalid Command

`clearInput` is NOT a valid Maestro command. Use `eraseText` instead:

```yaml
# WRONG — not a Maestro command
- clearInput:
    id: "email-input"

# CORRECT
- tapOn:
    id: "email-input"
- eraseText: 50
- inputText: "new-value@example.com"
```

---

## Keyboard & Text Management

**NEVER use `hideKeyboard`** — on iOS it causes Maestro to tap on the keyboard itself, inserting a stray character (typically `t` or `y`) into the focused field. This corrupts passwords, emails, and form data silently.

Two safe alternatives:
1. **Tap next element by testID** — tapping any element above the keyboard dismisses it automatically
2. **`pressKey: enter`** — simulates the Return/Done key on iOS keyboard, cleanly dismissing it without side effects. Use this when the next element is BEHIND the keyboard.

```yaml
# WRONG — hideKeyboard inserts stray characters on iOS
- tapOn:
    id: "email-input"
- inputText: "test@example.com"
- hideKeyboard                    # May type 't' into email field!

# CORRECT — tap next field directly (keyboard auto-dismisses)
- tapOn:
    id: "email-input"
- inputText: "test@example.com"
- tapOn:
    id: "password-input"          # Keyboard dismisses on its own
- inputText: "password123"

# CORRECT — when submit button is BEHIND keyboard, use pressKey enter first
- pressKey: enter                 # Dismisses keyboard cleanly
- tapOn:
    id: "submit-button"           # Now visible and tappable

# Clear pre-filled text before typing
- eraseText: 20
- inputText: "new value"
```

---

## Empty State Handling

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

---

## Coordinate Taps — Last Resort

For BottomSheets not yet migrated to the dual-render approach, coordinate taps are the only option. Always document the calibration device:
```yaml
# Calibrated for: iPhone 16e (390x844), iOS 26.0
- tapOn:
    point: "50%,10%"   # Tap outside bottom sheet to close
    optional: true
```
