# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Kith** — a fully on-device personal CRM for iPhone. iOS 26+, pure SwiftUI, SwiftData mirrored to a private CloudKit database, WidgetKit small widget, local notifications. Single user, no backend, no accounts, no analytics.

## Repository state

`Kith.xcodeproj` is a hand-written Xcode 26 project using **synchronized folder groups** (`Kith/` and `KithTests/`): any file added under those folders is picked up automatically, so there is no per-file bookkeeping in `project.pbxproj`. Product specs live under `prds/`, which is **gitignored** — the specs exist on this machine but are not tracked, so do not assume another checkout has them.

Build settings that shape the code: iOS 26.0 deployment target, Swift 6 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency. Because of MainActor default isolation, pure value types that `@Model` classes call into (`CadenceEngine`, `KeyDateEngine`, the raw-value enums) are declared `nonisolated`.

```bash
# Build
xcodebuild build -project Kith.xcodeproj -scheme Kith -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run all tests (Swift Testing)
xcodebuild test -project Kith.xcodeproj -scheme Kith -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run one suite / one test
xcodebuild test -project Kith.xcodeproj -scheme Kith -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:KithTests/UpcomingFeedTests
xcodebuild test -project Kith.xcodeproj -scheme Kith -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:KithTests/UpcomingFeedTests/dateTodaySuppressesDuplicateReachOut

# Install + launch on a booted simulator with sample people (DEBUG only; seeds only an empty store)
xcrun simctl install booted <DerivedData>/Build/Products/Debug-iphonesimulator/Kith.app
xcrun simctl launch booted com.yashshenai.kith -kith-seed-sample
```

Do not pass `CODE_SIGNING_ALLOWED=NO`: it strips the App Group entitlement and SwiftData traps at launch. Simulator ad-hoc signing needs no team.

### Implemented so far
- Data model (`Kith/Models`), `CadenceEngine` / `KeyDateEngine` (`Kith/Cadence`), container coordinator + App Group preferences (`Kith/Persistence`).
- **Upcoming** screen end to end (`Kith/Upcoming`; the spec still calls it Home / Today): ranked feed, conditional segments, check + undo, Remind me tomorrow / Skip, caught-up state, contact avatar cache. The feed is a **30-day look-ahead** (`UpcomingFeed.horizonDays`) covering key dates and each person's *next* reach-out, due or not; a repeating cadence contributes exactly one row. A key date's `leadTimeDays` now only drives its notification, not its visibility.
- **Add Contact** flow (`Kith/AddContact`): picker → duplicate guard → Setup sheet.
- **People** roster end to end (`Kith/People`): in-memory A–Z sectioning (`PeopleRoster`), search + filter, count footer, three empty states, and the app's only delete (`PeopleActions`). The swipe Delete button is red-tinted but deliberately **not** `role: .destructive` — a destructive swipe button makes `List` dismiss the row before the confirmation dialog can present.
- `CatchupStatus` (`Kith/Models`) is the one home for the next-catchup line; the roster row and Contact Detail both derive from it.
- **Contact Detail** end to end (`Kith/ContactDetail`): header + live Notify editing (bindings write to the model, `ContactDetailActions.notifyDidChange` reschedules the reach-out), Dates with the `KeyDateEditorView` sheet and swipe-to-delete, Tags as rows, debounced Notes, and the read-only Timeline (`TimelineEntry` merges touches + skip markers). `NotificationScheduler` now schedules reach-out and key-date lead/day-of requests; `NotificationRecorder` is the test hook for asserting on IDs and fire dates.
- **Settings** end to end (`Kith/Settings`): one flat `Form` of section views, each bound to `@AppStorage` on `AppPreferences.store`. `SettingsActions` owns the two side effects: the all-people notification pass and the sync rebuild (writes the preference only after `ModelContainerCoordinator.rebuild` succeeds). Notification-preference changes are coalesced in `SettingsView` with a short settle delay before one pass. The developer card's bio, links, and `DeveloperAvatar` image set are placeholders (`DeveloperProfile`).
- **Privacy lock** (`Kith/Lock`): `AppLockGate` wraps `RootTabView` in `KithApp`; while locked the tab tree is not in the hierarchy at all, so unlocking lands on Upcoming. `AppLockState` is the `scenePhase` state machine (grace period measured from the first resign while unlocked; the switch is snapshotted at resign so enabling the lock during its own Face ID prompt doesn't lock the user out). `LockAuthenticator` is the only `LAContext` wrapper.
- `NotificationPlanner` (`Kith/Notifications`) is the single home for which requests a person should have and when. Contact Detail and Settings both go through it; `rescheduleAll` sorts by fire date and stops at `pendingLimit` (60), the seed of the rolling scheduler. It is not yet run on launch or background refresh.
- Every `AppPreferences` reader has an `(in: UserDefaults)` twin so actions can be tested against a throwaway suite. `syncEnabled` defaults to on only when `ModelContainerCoordinator.isICloudAvailable`.
- One model addition beyond the Data Model spec: `KeyDate.lastHandledAt: Date?` — required by Home §5 ("handled until next recurrence"); optional, so CloudKit-safe.

## Specs are the source of truth

Read the relevant spec before implementing a screen. They reconcile each other and record deliberate omissions as decisions, not gaps — don't "fix" an omission without checking the spec's "What's deliberately not here" section.

| Spec | Owns |
|---|---|
| `prds/Personal CRM PRD.md` | Goals, P0 requirements, cadence semantics (Appendix), notification + widget spec |
| `prds/Data Model & Persistence — Spec.md` | `@Model` definitions, CloudKit constraints, derived values, notification IDs, container setup |
| `prds/Home Screen (Today) — Flow Spec.md` | The Upcoming feed (named Today in the spec), `TabView` shell, the core-loop actions |
| `prds/People (Roster) — Flow Spec.md` | Roster, search, filter, swipe-to-delete cascade |
| `prds/Contact Detail (Contact Sheet) — Flow Spec.md` | Per-person read-and-configure screen |
| `prds/Add Contact — Flow Spec.md` | Contact picker → duplicate guard → Setup sheet |
| `prds/Settings — Flow Spec.md` | App-level preferences, sync toggle, privacy lock |

## Architecture — the non-obvious parts

### Data model is shaped by CloudKit, not by convenience
SwiftData + CloudKit private DB forbids things plain SwiftData allows. Every model must obey:
- **No `@Attribute(.unique)` / `#Unique`.** The duplicate guard on `linkedContactID` is a **fetch**, not a constraint.
- **Every relationship optional** (`[Touch]?`, `Person?`). A non-optional relationship stops the container from initializing.
- **Every non-optional attribute has a default.**
- **Inverse declared once, on the `Person` side** (`@Relationship(deleteRule: .cascade, inverse: \Touch.person)`). Without it the cascade delete silently doesn't propagate.
- Enums are stored as raw values (`cadenceRaw`, `notifyDayRaw`) with typed computed accessors that fall back to a default.
- `Person` is the aggregate root owning `Touch`, `SkipMarker`, `KeyDate`. `SkipMarker` is a separate type (not a `Touch.kind`) so a skip can never be counted as a real touch.
- `KeyDate` stores `month`/`day`/`year?` as ints, not a `Date`.
- **Photos are never stored** — referenced from Contacts by `linkedContactID` at render time, monogram fallback. They do not sync.
- `nextDue` / `isOverdue` are **computed, never persisted**. All interval math lives in one `CadenceEngine` so every surface derives identically.

### Two stores, deliberately split
- **SwiftData store** (App Group `group.com.yashshenai.kith`) — people and their children. Synced when sync is on. Read by the widget.
- **`UserDefaults` in the same App Group** via `@AppStorage` — all Settings values (default reminder time, the single notifications switch, new-contact cadence defaults, lock, sync flag). **Device-local, never synced.** The sync toggle can't live in the store it toggles.

### Sync toggle rebuilds the container
Sync on/off is a different `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.yashshenai.kith") vs .none)`, not a runtime flag. An app-level `@Observable` coordinator owns the container and republishes it into the environment. Turning sync off leaves the iCloud copy intact.

### Where actions live (hard boundaries between screens)
- **Upcoming is the only place a touch is logged.** Logged / Remind me tomorrow / Skip are Upcoming-only (check button + swipe actions); the swipe actions only appear on rows that are due or overdue. The widget's App Intent may also log.
- **Contact Detail is read-and-configure.** Live inline editing, no Edit/Save mode, no Logged, no delete.
- **People roster is find / open / add / remove.** Swipe-to-delete (confirmed, `allowsFullSwipe: false`) is the **only** removal path in the app. No archive.
- **Settings is app-level defaults and machinery**, never per-person editing. No "reset all" / "delete all".
- **Add is from Contacts only, one at a time.** No manual entry in v1.

### Tags never affect cadence
Cadence is set per contact via the Notify section (how often / day / time; default Weekly / Saturday / 6:00 PM, seeded from Settings). Tags are labels for grouping and filtering only.

### Notifications
- Deterministic identifiers derived from model UUIDs: `reachout-<personUUID>`, `remind-<personUUID>`, `keydate-<keyDateUUID>-lead`, `keydate-<keyDateUUID>-day`. Rescheduling is therefore idempotent.
- **Capture a person's notification IDs before `modelContext.delete(person)`** — the cascade makes `keyDates` unreadable afterward.
- Rolling scheduling on launch/background refresh to stay under the iOS ~64 pending limit.
- Reach-out notifications fire at the contact's own `notifyDay`/`notifyTime`; key-date notifications fire at the Settings default reminder time.

### Roster ordering is done in memory
Sort with `localizedStandardCompare` and section by first letter **in memory** from the `@Query` result. Do not push a custom string comparator into `@Query`'s sort descriptor — it isn't reliably honored by the store. Search (name ∪ notes ∪ tags) and filter (tag ∧ overdue) are also in-memory, no debounce.

### Contact photos in lists
Render the monogram immediately; fetch `thumbnailImageData` off the main thread via a shared cache keyed by `linkedContactID` in a per-row `.task(id:)`. Never read image data synchronously in a row body.

## UI constraints

- **Native SwiftUI components only.** No third-party UI kits, no custom design system. `NavigationStack`, `List`, `Form`, SF Symbols, system colors. Dark mode / Dynamic Type / VoiceOver must come for free.
- iOS 26 `TabView` uses the `Tab("Upcoming", systemImage:) { … }` builder, not `.tabItem`. One `NavigationStack` per tab; Contact Detail is always pushed, never modal.
- The one UIKit wrap is `CNContactPickerViewController` via `UIViewControllerRepresentable`, single-select. Don't wrap `UITableView` for the roster.
- Overdue is shown in an informative tint (secondary orange), never red badges or shaming copy.
- Empty states use `ContentUnavailableView`.
- The typeface is **SF Rounded**, chosen once by `.roundedTypeface()` on the root view in `KithApp`. SwiftUI text inherits it from `.fontDesign(.rounded)`; navigation titles, tab bar labels, and segmented controls are UIKit-drawn and need the appearance proxies in `RoundedChrome`, which override the design only and keep Apple's sizes and weights. `UIDatePicker` exposes no font hook, so pickers stay SF Pro. Never set a font family per view.
- Privacy lock: `LAContext` with `.deviceOwnerAuthentication`; privacy overlay driven by `scenePhase` whenever the lock is on.

## Sync validation checklist

The PRD calls for validating CloudKit sync early. The concrete checklist is in `prds/Data Model & Persistence — Spec.md` §10 — run it during the first sync spike before building UI on top of the model.
