# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Kith** — a fully on-device personal CRM for iPhone. iOS 26+, pure SwiftUI, SwiftData mirrored to a private CloudKit database, WidgetKit small widget, local notifications. Single user, no backend, no accounts, no analytics.

## Git: never commit or push unasked

**Do not run `git commit` or `git push` unless the current message explicitly asks for it.** Finishing a change means leaving it built, tested, and uncommitted, then saying what changed. Stop there.

- Permission does not carry forward. "Commit and push" applies to that request only — the next task starts from no again, however similar it looks.
- **Do not create branches unless asked.** Work lands on the branch already checked out, normally `main`. Read it with `git branch --show-current` rather than trusting a session-start snapshot, which goes stale; if it isn't the branch the work belongs on, say so instead of quietly going along with it.
- Committing without being asked is worse than waiting: it writes history the user has not reviewed, and pushing puts it somewhere they have to undo rather than simply approve.

## Keep the changelog current

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). **Any change a user would notice goes under `## [Unreleased]` as part of the same task that makes it** — not later, and not in a separate pass. Write the entry when you finish the work, in the same uncommitted state as the code.

**The audience is someone who uses Kith, not someone who builds it.** Write every entry in plain English, the way you would explain the change to a friend holding the phone.

- **No jargon, no code.** Never name a type, file, method, framework, or setting key — no `UpcomingFeed`, no SwiftData, no CloudKit, no `.toolbarTitleMenu`. Say "your data syncs privately through your own iCloud account", not "SwiftData mirrored to a private CloudKit database".
- **Say what changed for the person using the app, and why it's better.** "The search box only appears once you have six or more people. Below that, reading the list is quicker than typing into it." Not "applied `.searchable` above a threshold constant".
- **Lead with the plain fact, then the reason if it helps.** One or two sentences per entry is plenty.
- Group entries under the six standing headings: Added, Changed, Deprecated, Removed, Fixed, Security. Leave a heading empty rather than deleting it; the skeleton is what makes the next entry obvious.
- Skip what a user cannot observe: refactors, test-only changes, comment edits, `CLAUDE.md` itself. If nothing about using the app changes, it does not belong.
- **On a version bump**, rename `[Unreleased]` to the new `MARKETING_VERSION`, date it `YYYY-MM-DD`, note the build number beside it (`— build 4`), add a fresh empty `[Unreleased]` above, and update the compare links at the foot of the file.
- Versions map to `MARKETING_VERSION`, so a TestFlight build that only bumps `CURRENT_PROJECT_VERSION` extends the current version's entry rather than starting a new one.

## Repository state

`Kith.xcodeproj` is a hand-written Xcode 26 project using **synchronized folder groups** (`Kith/` and `KithTests/`): any file added under those folders is picked up automatically, so there is no per-file bookkeeping in `project.pbxproj`. Product specs live under `prds/`, which is **gitignored** — the specs exist on this machine but are not tracked, so do not assume another checkout has them.

Build settings that shape the code: iOS 26.0 deployment target, Swift 6 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency. Because of MainActor default isolation, pure value types that `@Model` classes call into (`CadenceEngine`, `KeyDateEngine`, the raw-value enums) are declared `nonisolated`.

`scripts/run.sh` wraps the whole build → install → launch loop, which is the fastest way to see a change running. It resolves the build directory from `xcodebuild -showBuildSettings` rather than hardcoding a DerivedData path, and boots the simulator if it isn't already up. Override the device with `KITH_SIM_DEVICE`.

```bash
scripts/run.sh            # build, install, launch with sample people
scripts/run.sh --fresh    # wipe the app's data first, so the sample seed runs again
scripts/run.sh --shot     # screenshot to /tmp/kith.png once it's up
scripts/run.sh --test     # the suite, filtered down to failures and the summary
```

The raw commands, when a step needs running on its own:

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

### Releasing to TestFlight

`ExportOptions.plist` at the repo root drives the upload; every key in it is one `xcodebuild -help` documents.

```bash
# Archive (Release, unsigned-for-simulator destinations won't work — must be generic iOS)
xcodebuild -project Kith.xcodeproj -scheme Kith -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Kith.xcarchive archive

# Re-sign for distribution and upload straight to App Store Connect
xcodebuild -exportArchive -archivePath build/Kith.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

Uploading authenticates as the Apple ID in Xcode's Accounts settings. Without one, pass an App Store Connect API key: `-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID`.

**Deploy the CloudKit schema to Production before the first upload.** A TestFlight build reads the Production container; the simulator and local device builds write the Development one. SwiftData infers the schema on first synced save, so the record types (`CD_Person`, `CD_Touch`, `CD_SkipMarker`, `CD_KeyDate`) only exist after the app has run on a device signed into iCloud with sync on. Promote them in the CloudKit Console with Deploy Schema Changes. Production schema is **additive only** — no renames, no deletions — which is the standing reason new attributes must be optional or defaulted.

`manageAppVersionAndBuildNumber` is off, so `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` ship exactly as set. Build numbers must be unique within a version string: re-uploading the same version needs `CURRENT_PROJECT_VERSION` bumped.

### Implemented so far
- Data model (`Kith/Models`), `CadenceEngine` / `KeyDateEngine` (`Kith/Cadence`), container coordinator + App Group preferences (`Kith/Persistence`).
- **Upcoming** screen end to end (`Kith/Upcoming`; the spec still calls it Home / Today): ranked feed, an `UpcomingMode` title dropdown (`.toolbarTitleMenu`) picking Upcoming vs Overdue, check + undo, Remind me tomorrow / Skip, caught-up state, contact avatar cache. The feed is a **30-day look-ahead** (`UpcomingFeed.horizonDays`) covering key dates and each person's *next* reach-out, due or not; a repeating cadence contributes exactly one row. A key date's `leadTimeDays` now only drives its notification, not its visibility.
- **Add Contact** flow (`Kith/AddContact`): picker → duplicate guard → Setup sheet.
- **People** roster end to end (`Kith/People`): in-memory A–Z sectioning (`PeopleRoster`), search, the tag pill row, three empty states, and the app's only delete (`PeopleActions`). The overdue-only filter and its menu were removed when the pill row landed; Overdue now lives in the Upcoming title dropdown. The swipe Delete button is red-tinted but deliberately **not** `role: .destructive` — a destructive swipe button makes `List` dismiss the row before the confirmation dialog can present.
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

`Kith/Tags` owns all of it. `TagVocabulary` is the single source for "every tag in use" and the only place tags are compared: folded case- and diacritic-insensitively, so one tag can't split into two pills. It also holds `defaults` — Close friends, Family, Friends, Work. The vocabulary is its own SwiftData model, `Tag` (`Kith/Models/Tag.swift`) — a name and nothing else, deliberately **not** related to `Person`. People keep `tags: [String]` and are matched by folded name, so no migration was needed; `TagActions.delete` is what keeps the two in step, stripping the name from everyone before removing the row. `TagVocabulary.defaults` is now only the seed list: `TagActions.seedIfNeeded` writes those four plus every tag already in use, once per device, guarded by `AppPreferences.tagsSeeded` rather than by an emptiness check (deleting every tag is a legitimate end state). On a synced account two devices can both seed before iCloud catches up; the duplicate rows collapse on read and delete takes them all.

**Manage tags** (`Kith/Tags/ManageTagsView.swift`, reached from Settings → Other) is the only place a tag is created or destroyed. Everywhere else is pick-only: the shared `TagsSection` has no text field, just a menu of `TagVocabulary.options(from:notIn:)`, used by both Contact Detail and the Add Contact setup sheet. The pill rows still derive from *people*, not from the store, so creating a tag makes it pickable without making it visible.

`Tag` adds the CloudKit record type `CD_Tag`. **Deploy the schema to Production before the next TestFlight upload**, or that build's tag list won't sync. A default nobody carries is not in the vocabulary and never reaches the pill row; the row itself is hidden until at least one person is tagged. `canonical(_:)` settles a typed tag on the default's spelling when it matches one, so "work" and the suggested "Work" stay one tag. Custom tags keep the first spelling seen. `TagPillRow` is the shared single-select filter under the toolbar on Upcoming and People — a horizontal `ScrollView` of glass capsule `Button`s, since no system component scrolls. Each tab keeps its own selection, and both clear it when the last person carrying that tag is untagged. The pill row is the app's only `ScrollView`; everything else scrolls as a `List` or `Form`.

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

### Mobbin is reference, not a spec

The Mobbin MCP server is connected, and its screen and flow searches are a good way to see how shipped apps arrange a roster, a detail screen, or an empty state. What comes back is screenshots of other people's apps, most of them built on custom design systems.

Use it to settle layout, ordering, and flow questions. Do not use it to justify rebuilding a look pixel by pixel: the native-components rule above still wins, so a Mobbin reference gets translated into stock `List`, `Form`, and SF Symbols, or it doesn't land. If a reference can only be matched with custom drawing, that is a signal to drop the reference, not to drop the rule.

## Sync validation checklist

The PRD calls for validating CloudKit sync early. The concrete checklist is in `prds/Data Model & Persistence — Spec.md` §10 — run it during the first sync spike before building UI on top of the model.
