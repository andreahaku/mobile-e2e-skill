# testID Naming Conventions

How to name testIDs for React Native / Expo mobile apps. Use these rules when analyzing existing testIDs or recommending new ones.

## Naming Rules

1. **Kebab-case**: `login-email-input`, NOT `loginEmailInput` or `login_email_input`
2. **Screen prefix**: Every testID starts with its screen/feature name: `chat-*`, `settings-*`, `reservations-*`
3. **Suffix indicates element type**:
   - `-button` — tappable actions
   - `-input` — text inputs
   - `-list` — scrollable list containers (FlatList, ScrollView)
   - `-screen` — top-level screen wrapper
   - `-modal` — modal/overlay containers
   - `-link` — tappable text links
   - `-toggle` / `-switch` — toggle controls
   - `-dropdown` — dropdown/select controls
   - `-item` — individual items in a list or menu
4. **Dynamic IDs**: For list items, append the entity ID: `reservation-card-{id}`, `ticket-card-{id}`
5. **Container screens**: Top-level screen wrapper gets `-screen` suffix: `login-screen`, `settings-screen`
6. **Lists**: The scrollable list container gets `-list` suffix: `conversations-list`, `tickets-list`

## Common Patterns by Feature Type

These patterns apply regardless of the specific app. Adapt the prefix to match the app's feature names.

### Authentication Screens

| Element Type | Pattern | Example |
|---|---|---|
| Screen wrapper | `login-screen` | |
| Email input | `login-email-input` | |
| Password input | `login-password-input` | |
| Submit button | `login-button` or `login-submit-button` | |
| Password visibility | `login-toggle-password` | |
| Remember me | `login-remember-me` | |
| Forgot password | `login-forgot-password` | |
| OTP screen | `otp-screen` | |
| OTP input area | `otp-boxes-container` | Tap to focus hidden input |
| OTP verify button | `verify-otp-button` | |

### Navigation

| Element Type | Pattern | Example |
|---|---|---|
| Tab bar items | `tab-<name>` | `tab-home`, `tab-calendar`, `tab-inbox` |
| Drawer menu button | `drawer-menu-button` | Hamburger icon |
| Drawer items | `drawer-<section>-item` | `drawer-chat-item`, `drawer-settings-item` |
| Back buttons | `<screen>-back-button` | `chat-back-button` |
| Header actions | `<screen>-header-<action>` | `chat-header-title` |

### List Screens

| Element Type | Pattern | Example |
|---|---|---|
| List container | `<feature>-list` | `conversations-list`, `tickets-list` |
| List item (dynamic) | `<feature>-card-{id}` | `reservation-card-abc123` |
| Filter buttons | `<feature>-filter-<name>` | `tickets-filter-all`, `tickets-filter-active` |
| Search input | `<feature>-search-input` | `reservations-search-input` |
| Sort control | `<feature>-sort-button` | |
| New/create button | `<feature>-new-button` or `<feature>-create-button` | `conversations-new-chat-button` |

### Detail/Editor Screens

| Element Type | Pattern | Example |
|---|---|---|
| Save button | `<feature>-editor-save-button` | `kb-editor-save-button` |
| Delete button | `<feature>-editor-delete-button` | |
| Back/cancel | `<feature>-editor-back-button` | |
| Form inputs | `<feature>-<field>-input` | `kb-editor-name-input` |

### Settings Screens

| Element Type | Pattern | Example |
|---|---|---|
| Screen wrapper | `settings-screen` | |
| Sections | `settings-<section>-section` | `settings-notification-section` |
| Logout button | `settings-logout-button` | |
| Toggles | `<feature>-toggle` | `ai-toggle-button` |

### Modals & Overlays

| Element Type | Pattern | Example |
|---|---|---|
| Modal wrapper | `<feature>-modal` | `contact-info-modal`, `property-select-modal` |
| Close button | `<feature>-close-button` | `contact-info-close-button` |
| Overlay (dismiss area) | `<feature>-overlay` | `conversation-options-overlay` |

### Action Menus

| Element Type | Pattern | Example |
|---|---|---|
| Menu container | `<context>-options-menu` | `conversation-options-menu` |
| Menu items | `<context>-option-<action>` | `conversation-option-archive` |

## Compound Component Patterns

Some components generate child testIDs from a parent testID. Know these patterns to avoid tapping container elements that don't trigger actions.

### SegmentedControl / Toggle

Container testID generates per-segment IDs: `${containerTestID}-${option.key}`

| Element | testID | Example |
|---|---|---|
| Container (DON'T tap) | `view-toggle` | Tapping hits the divider |
| Segment option | `view-toggle-${key}` | `view-toggle-calendar`, `view-toggle-list` |

### StepHeader (Multi-Step Forms)

Header testID generates a back button: `${testID}-back`

| Element | testID | Example |
|---|---|---|
| Header container (DON'T tap) | `results-step-header` | No action on tap |
| Back button | `results-step-header-back` | Navigates to previous step |

### Property Selector

| Element | testID | Example |
|---|---|---|
| Scroll container | `property-selector-scroll` | |
| Individual pill | `property-pill-{propertyId}` | `property-pill-abc123` |

## Role-Specific Prefixes

Different roles use distinct prefixes to avoid testID collisions across screens.

### Owner Screens

| Element | testID Pattern | Example |
|---|---|---|
| Home scroll | `owner-home-scroll` | |
| Header avatar | `owner-header-avatar` | Opens account drawer |
| Performance card | `performance-card-revenue` | |

### Account Drawer

| Element | testID Pattern | Example |
|---|---|---|
| Drawer container | `account-drawer` | |
| User name | `account-drawer-user-name` | |
| Language selector | `account-drawer-language-selector` | |
| Sign out button | `account-drawer-sign-out` | |
| Close button | `account-drawer-close` | |

### Calendar (Shared Across Roles)

| Element | testID Pattern | Example |
|---|---|---|
| Month/year label | `calendar-month-year` | |
| Next month arrow | `calendar-next-month` | |
| Previous month arrow | `calendar-prev-month` | |
| Block dates button | `calendar-block-dates-button` | |

### Check Availability Modal (Admin)

| Element | testID Pattern | Example |
|---|---|---|
| Close button | `check-availability-close` | |
| Property selector | `check-availability-property` | |
| Check-in date | `check-availability-checkin` | |
| Check-out date | `check-availability-checkout` | |
| Guest count | `check-availability-guests` | |
| Search button | `check-availability-search` | |
| Create reservation | `check-availability-create-reservation` | |
| Send quote | `check-availability-send-quote` | |

## Adding testIDs to Components

When analysis reveals missing testIDs, recommend adding them:

```tsx
// Screen wrapper
<View testID="feature-screen">

// Input field
<TextInput testID="feature-name-input" />

// Button
<TouchableOpacity testID="feature-submit-button">
// or Pressable
<Pressable testID="feature-submit-button">

// List container
<FlatList testID="feature-list" />

// List item (dynamic ID)
<TouchableOpacity testID={`feature-card-${item.id}`}>

// Modal
<Modal testID="feature-modal">

// Toggle/Switch
<Switch testID="feature-toggle" />
```

## Coverage Check

To find screens missing testIDs, use the Grep tool:

```
# Search for screen files with zero testIDs
# 1. Find all screen files
Grep pattern="Screen" type="tsx" output_mode="files_with_matches"

# 2. For each screen file, count testIDs
Grep pattern="testID" path="<screen-file>" output_mode="count"
```

Screens with 0-2 testIDs are likely gaps that need addressing before E2E tests can cover them.
