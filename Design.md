# Design.md

The design language of Kith: what has been decided, why, and how to decide the next thing.

This is a companion to the specs in `prds/`, not a replacement. **The specs own *what* each screen does; this document owns *how* anything in the app looks and behaves.** When a spec and this document disagree about behaviour, the spec wins. When they disagree about appearance, this document wins. Every rule below is drawn from code that already ships — file references point at the precedent, so a new screen can be built by reading the nearest one.

---

## 1. The five principles

Everything else in this document is a consequence of these.

1. **Native or nothing.** Kith is built entirely from stock SwiftUI. No third-party UI kits, no custom design system, no bespoke drawing. If a look can only be achieved by re-implementing a system control, the look is wrong, not the rule.
2. **Calm over urgent.** This is an app about people you like. Nothing shames, counts down, or turns red. Overdue is *information*, rendered in secondary orange (`UpcomingRow.subtitleStyle`, `PeopleRow.subtitleStyle`, `ContactDetailHeader.statusStyle`), never a red badge and never a scolding sentence.
3. **One row, one tap.** Every row in the feed resolves with a single tap on a single control. Secondary acts hide in swipes and menus; they never compete with the primary one.
4. **The screen tells the truth.** A filtered list says which filter it is under (`.navigationSubtitle(horizon.label)`); an empty list says *why* it is empty (`UpcomingEmptyView` has six distinct states); a destructive dialog says exactly what it will touch (`ManageTagsView.deletionWarning`). The app never lets a quiet control silently change what you are looking at.
5. **Free accessibility is the point of using system components.** Dark mode, Dynamic Type, VoiceOver, and Reduce Motion must all work without a single bespoke branch. When a component is hand-laid-out (there is exactly one — see §5.4), it pays for itself by still being made of stock `Button`s.

---

## 2. Foundations

### 2.1 Typeface — one decision, made once

The app is **SF Rounded**, everywhere. That decision is made in exactly one place: `.roundedTypeface()` on the root view in `KithApp`.

- SwiftUI text inherits it through `.fontDesign(.rounded)`.
- Navigation titles, tab bar labels, and segmented controls are UIKit-drawn and need appearance proxies — `RoundedChrome`. Those proxies override **the design only**; every size and weight in them is the one UIKit would have used anyway.
- `RoundedChrome.apply()` re-runs on every Dynamic Type change and then pushes the fonts onto chrome already on screen, because a proxy only seeds controls built after it.
- `UIDatePicker` exposes no font hook, so wheel pickers stay SF Pro. This is accepted, not worked around.

**Never set a font family, or a font design, per view.** If new UIKit-drawn chrome appears, extend `RoundedChrome` rather than patching the call site.

### 2.2 Type scale — semantic styles only

Only semantic text styles are used, so Dynamic Type is automatic. The whole vocabulary in use:

| Style | Where |
|---|---|
| `.title` | Developer card name (`DeveloperCardHeader`) |
| `.title2` | Contact Detail name; the check glyph (`UpcomingCheckButton`) |
| `.headline` | The label on a `.controlSize(.large)` empty-state button |
| `.body` | Every row's primary line (`UpcomingRow`, `PeopleRow`) |
| `.subheadline` | Every secondary line: status, timeline dates, notes, tag pills, toast |
| `.footnote.bold()` | Disclosure chevrons drawn by hand (`AboutSection`, `ManageTagsRow`) |
| `.largeTitle` | The privacy overlay glyph only |

The single fixed-size font in the app is the avatar monogram, `.system(size: size * 0.4, weight: .medium, design: .rounded)` in `ContactAvatarView` — it scales with the avatar, which is itself a fixed frame, so it cannot be a text style.

**A row is `.body` over `.subheadline`.** That pairing is the app's basic unit of text. Don't invent a third line.

### 2.3 Colour — a hierarchy, not a palette

There is no colour palette. `AccentColor` is deliberately **empty**, so the tint is the system accent. Colour carries exactly four meanings:

| Style | Meaning | Example |
|---|---|---|
| `.tint` | The app's own affordances and the "today" case | check button, monogram, timeline touch glyph |
| `.primary` | Content | names, row labels |
| `.secondary` | Context, and everything at rest | status lines, footers, timeline dates |
| `.tertiary` | Absent or inert | "No catchup scheduled", hand-drawn chevrons |
| `.orange` | Overdue or due today — **informative, not alarming** | row subtitles, detail header status |
| `.red` | Destruction only | Delete swipe tint, the minus glyph in Manage tags |

Two hard rules:

- **Orange is the only status colour.** Nothing is ever green for "on track" or red for "late." Being on track is expressed by the *absence* of orange and by the calm empty state.
- **Red appears only where something is deleted.** It is never used for errors, warnings, or emphasis.

Because status styles have to switch between `.orange`, `.secondary`, and `.tertiary`, they are written as `AnyShapeStyle` computed properties on the view. Follow that shape (`PeopleRow.subtitleStyle` is the canonical one) rather than reaching for `Color`.

### 2.4 Materials and glass

iOS 26 glass is used sparingly and only for things that float above content:

- `.buttonStyle(.glassProminent)` — **the primary call to action on a surface**, accent-tinted. Exactly three uses: the toolbar `+` on Upcoming and People, the tick in `NewTagSheet`, and the lit pill in `TagPillRow`.
- `.buttonStyle(.glass)` — an unlit tag pill.
- `.buttonStyle(.borderedProminent)` + `.controlSize(.large)` + `.font(.headline)` — the call to action **inside a `ContentUnavailableView`**. Empty-state buttons are bordered, not glass, because they sit on a plain background with nothing to refract.
- `.background(.regularMaterial, in: .capsule)` — the undo toast, the one floating panel in the app.
- `ToolbarSpacer(.fixed, …)` splits unrelated toolbar acts into separate glass capsules (Upcoming's filter vs. add). Related acts share one.
- `.scrollEdgeEffectStyle(.soft, for: .top)` on Upcoming, so the list softens under the pill row rather than cutting against it.

**Glass is for controls that float over scrolling content.** It is never a background, never a card, never a section.

### 2.5 Iconography

SF Symbols only, always by semantic name. The stable vocabulary:

| Symbol | Meaning |
|---|---|
| `calendar` | Upcoming (tab, and "nothing coming up") |
| `person.2` / `person.2.fill` | People; the privacy overlay |
| `gearshape` | Settings |
| `checkmark.circle` | The universal check; "on track" |
| `checkmark.circle.fill` | A logged touch in the timeline |
| `forward.end` / `forward.end.circle` | Skip, and a skip in the timeline |
| `clock.arrow.circlepath` | Remind me tomorrow |
| `tag` | Tags, everywhere |
| `plus` / `plus.circle` / `plus.circle.fill` | Add — bare in toolbars, circled in rows |
| `line.3.horizontal.decrease.circle(.fill)` | The horizon filter; **filled whenever narrowed** |
| `trash` | Delete, in swipes |
| `minus.circle.fill` | Delete, as a quiet in-row glyph |
| `xmark` / `xmark.circle.fill` | Close a sheet; remove a tag from a person |
| `lock.fill` | The lock screen |
| `chevron.right` | A hand-drawn disclosure on a button that presents a sheet |

Two conventions worth keeping:

- **A filter icon fills when it is doing something.** `UpcomingFilterMenu` swaps to the `.fill` variant the moment the horizon is narrowed, so a narrowed feed is never silently narrow.
- **A glyph inside a row is `.buttonStyle(.borderless)`**, so only the glyph is the tap target and not the whole row (`TagsSection`, `ManageTagsView.TagRow`, `UpcomingCheckButton`).

### 2.6 Metrics

Small, consistent, and few. These are the numbers actually in use:

| Value | Meaning |
|---|---|
| 44 pt | Default avatar; minimum tap target (`UpcomingCheckButton` frame) |
| 64 pt | Contact Detail header avatar |
| 12 pt | Avatar-to-text gap in a row |
| 2 pt | Between a row's two text lines |
| 4 pt | Vertical padding on a list row |
| 8 pt | Between tag pills; toast inset from the bottom edge; header stack spacing |
| 16 pt | Tag row horizontal content margin; toast horizontal padding |
| 6 pt | Vertical padding around the tag pill row |

**Never hard-code a width.** Rows size themselves; `Spacer(minLength: 8)` protects the gap before a trailing control.

### 2.7 Motion

- Every state change that adds, removes, or reorders a row is wrapped in `withAnimation { }` with the **default** animation. No custom curves, durations, or springs anywhere in the app.
- View-level `.animation(.default, value:)` is used for the few values that change without an action — the Contact Detail segment, the tag selection, the undo toast's identity.
- The one transition: `.move(edge: .bottom).combined(with: .opacity)` on the undo toast.
- The one content transition: `.contentTransition(.opacity)` on the Contact Detail status line, so a status that recomputes fades rather than snapping.

Because everything is `.default`, Reduce Motion is honoured for free. Keep it that way.

### 2.8 Haptics

Exactly one: `.sensoryFeedback(.success, trigger: checkCount)` on Upcoming. Logging a touch is the app's one moment of accomplishment, and it is the only thing that buzzes. **Do not add a second.**

---

## 3. Structure

### 3.1 The shell

`TabView` with three tabs, built with the iOS 26 `Tab(_:systemImage:value:)` builder — never `.tabItem`. Upcoming is the default.

**One `NavigationStack` per tab.** Upcoming and People own theirs internally because each needs a `NavigationPath` for the duplicate-guard push; Settings gets one from `RootTabView`.

**Contact Detail is always pushed, never modal.** It is reachable from both Upcoming and People, and both register the same two destinations (`Person`, `ExistingPersonRoute`).

### 3.2 List styles — the choice is meaningful

| Style | Used for | Why |
|---|---|---|
| `.plain` | Upcoming feed, People roster | A continuous scan of people. Grouping would imply structure that isn't there. |
| `.insetGrouped` | Contact Detail | Distinct settings for one person, which is what grouped cards say. |
| `Form` | Settings, Setup sheet, Key date editor, New tag | Preferences and entry. |

A `.plain` list draws a separator above its first row, which reads as a stray rule under a pill row or search field. Both `UpcomingView` and `PeopleView` hide it:

```swift
.listRowSeparator(item.id == items.first?.id ? .hidden : .automatic, edges: .top)
```

Do that on any new `.plain` list with something in its top safe-area inset.

### 3.3 Titles and toolbars

- **`.toolbarTitleDisplayMode(.inline)` on every screen.** Kith has no large titles.
- `.navigationSubtitle` names the active scope when one applies. It has no hidden state and an empty string still reserves the line, so it is applied conditionally via a small `@ViewBuilder` extension (`horizonSubtitle`). `.searchable` is handled the same way (`rosterSearchable`) — the modifier is applied or it isn't.
- **The title can be a control.** `UpcomingView` uses `.toolbarTitleMenu` with an inline `Picker` so the title names the mode and the dropdown is how the mode changes. That replaced a segmented control, and it is the pattern for "which version of this screen am I looking at."
- A count belongs in the dropdown, not in the chrome: `"Overdue (3)"` is the only hint that anyone is late while the feed looks calm.
- The toolbar `+` is **hidden until at least one person exists**, so first run has exactly one call to action — the empty state's button.
- Sheets use semantic placements: `.cancellationAction` for Cancel/Close (natively leading), `.confirmationAction` for Save/Add/Done. Never hardcode `.topBarLeading` for a dismissal.

### 3.4 Sheets

- Every sheet wraps its content in its own `NavigationStack` and carries `.presentationDragIndicator(.visible)`.
- `.presentationDetents([.medium])` when the sheet holds one field — `NewTagSheet` — because one text field doesn't earn a full screen.
- **Present sheets from the `Form`/`List`, never from inside a `Section`.** A `.sheet` on a `Section` is applied once per row and the competing presentations cancel each other out instantly. `SettingsView`, `ContactDetailView`, and `SetupSheetView` all hoist their `isPresenting…` state for this reason; `AboutSection` and `TagsSection` take an `onShow…` closure instead. This bug is easy to reintroduce and hard to diagnose.
- Settings has **no navigation destinations**. Rows that go somewhere present a sheet and are drawn like navigation rows: a `Button` containing `Label` + `Spacer` + a hand-drawn `chevron.right` in `.footnote.bold()` / `.tertiary`, with `.foregroundStyle(.primary)` on the stack so the label doesn't take the button tint. `ManageTagsRow` and `AboutSection` are the two examples; copy them exactly, including `.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }` when the row leads with an icon.

### 3.5 Empty states

**Every empty list is a `ContentUnavailableView`, and the app distinguishes between reasons it is empty.** `UpcomingEmptyView` has six branches and `PeopleEmptyView` has three; between them they cover: nobody added yet, Contacts permission denied, a tag that hides everyone, a search with no results, caught up inside the window, and "everything left is overdue and overdue lives behind the dropdown."

The rules the branches encode:

- **Name the actual condition.** "Nothing this week" is not "nothing at all" — `feed.horizon.span` is interpolated into the title so a narrowed filter can't read as an empty app.
- **Give the way out.** If a filter caused it, offer to clear it. If overdue caused it, offer to switch. If permission caused it, offer Settings.
- **Use the explicit search variant.** `ContentUnavailableView.search(text:)`, not the parameterless one — the overlay sits outside the searchable scope, and the bare variant renders "No Results" with no query.
- Empty states are drawn in an `.overlay { }` over the list, not in place of it, so the toolbar and safe-area insets stay put.

---

## 4. Copy and voice

Kith writes the way you'd talk about a friend.

- **Sentence case for everything.** "Manage tags", "Add Contact", "No one here yet", "Notification defaults". Never Title Case A Whole Phrase.
- **Second person, present tense.** "Unlock to see your people." "Add someone from Contacts to start staying in touch."
- **Never shame.** "3d overdue" states a fact. There is no "You've been neglecting…", no streaks, no counts of how badly you're doing.
- **Say what a destructive act touches, by number.** `ManageTagsView.deletionWarning` says "No one is tagged with this", or "1 person", or "\(count) people" — a tag nobody carries is a cheap delete and shouldn't be dressed up as a dangerous one.
- **Confirm by restating the object.** The button in a delete dialog is `Delete "Maya Patel"`, not `Delete`.
- **Footers explain, they don't warn.** "Labels for grouping only. Tags never change cadence." "Reminders arrive at your default reminder time, set in Settings."
- **Status phrasing is derived once and shared.** `CatchupStatus.rosterLabel` and `.detailLabel` are the only places a next-catchup line is worded, so the roster and Contact Detail can never drift. Relative days follow one ladder: Today / Tomorrow / abbreviated weekday within the week / "12 Sep". Any new surface showing a date uses `CatchupStatus.relativeDay`.
- **Word a button when an icon would be ambiguous.** The Create button in the Tags section header is worded, not a plus, because a second plus would read as another "Add tag" when this one *makes* a tag rather than applying one.
- Curly quotes around user content: `No one tagged "work"`.

---

## 5. Components and patterns

### 5.1 The row

The app has one row shape, used by both feeds:

```
[ avatar 44 ] 12 [ name (.body) / subtitle (.subheadline, status-tinted) ] Spacer(min: 8) [ trailing control? ]
```

wrapped in a `NavigationLink(value:)`, `.padding(.vertical, 4)`, with `.accessibilityElement(children: .combine)` and `.accessibilityHint("Opens \(name)")`.

Only Upcoming's row has a trailing control. **The roster row deliberately has none** — logging lives on Upcoming (§7).

### 5.2 Avatars

`ContactAvatarView` is the only way a person is depicted. It renders the monogram immediately — a `Circle` filled `.tint.opacity(0.15)` with tinted initials — and fetches the real photo off the main thread through the shared `ContactImageCache` in a `.task(id: contactID)`. It is `.accessibilityHidden(true)`, because the name is right next to it.

**Never read image data synchronously in a row body.** Photos are referenced from Contacts at render time and never stored or synced.

### 5.3 The check button

`UpcomingCheckButton` is stateless by design: the row animates out on tap, and an undone row must come back showing the empty circle. `checkmark.circle` at `.title2`, `.tint`, a 44×44 minimum frame, `.buttonStyle(.borderless)`, and an explicit `.accessibilityLabel` naming the person and the act.

### 5.4 The tag pill row

`TagPillRow` is **the app's only `ScrollView`**, and the only hand-laid-out component. It exists because no system component fits: a segmented picker can't scroll and forces equal widths. It earns the exception by being made entirely of stock `Button`s in `.glass` / `.glassProminent` with `.buttonBorderShape(.capsule)`.

Its details are all load-bearing:

- `.contentMargins(.horizontal, 16, for: .scrollContent)` insets the *content*, so pills scroll to the screen edge instead of stopping short.
- `.scrollClipDisabled()` — a glass pill's shadow is wider than the pill, and clipped it ends in a straight rule across the row.
- `.scrollIndicators(.hidden)`, and `scrollTo(anchor: .center)` on selection.
- **Tapping the lit pill clears it**, same as tapping All.
- `.accessibilityAddTraits(isSelected ? [.isSelected] : [])` — the one thing a plain `Button` won't say for itself.
- It lives in `.safeAreaInset(edge: .top, spacing: 0)`, so it pins under the toolbar and the list scrolls beneath it.
- It hides itself entirely when there are no tags.

Each tab keeps its own selection, and both clear it when the last person carrying that tag is untagged. If you add a third filterable surface, reuse this component; do not build a variant.

### 5.5 The undo toast

`UndoToast` — a capsule of `.regularMaterial` with a soft shadow, `.overlay(alignment: .bottom)`, 8 pt off the edge, 5-second auto-dismiss via a cancellable `.task(id: undo?.id)`. Backgrounding commits the action and clears the toast.

**Undo is offered for the check, and only the check**, because that is the one action that moves a person's clock forward from a single tap. Skip and Remind me tomorrow are reversible in other ways; delete is confirmed instead.

### 5.6 Progressive disclosure

Controls disappear when they have nothing to do, rather than sitting disabled:

- The search field is hidden below **six** people (`PeopleView.searchThreshold`) — at that size scanning beats typing — and crossing back below the threshold clears the query so a hidden field can't leave the list filtered.
- The horizon filter is hidden in Overdue mode, which isn't horizon-bounded.
- The "Add tag" menu disappears when there's nothing left to pick: a finished state, not a broken one.
- The toolbar `+` is hidden on first run.

**But conditional *fields* stay put and go disabled.** The Day picker and Time picker in the Notify section are disabled when the cadence doesn't use them, never removed — the shape of the section is part of how it is understood. The notifications switch also stays visible but inert when iOS-level permission is denied, so intent is preserved for when it's re-granted.

The distinction: **hide a control that has nothing to act on; disable a control whose value still matters.**

---

## 6. Interaction rules

### 6.1 Destruction

- Swipe actions are `allowsFullSwipe: false` for anything that deletes a person or a tag; `true` only for removing a tag from a person or deleting a key date, which are cheap and local.
- **A swipe Delete button is `.tint(.red)` but deliberately *not* `role: .destructive`.** A destructive swipe button makes `List` dismiss the row before the confirmation dialog can present. The role goes on the button *inside* the `confirmationDialog`. This applies to `PeopleRow` and `ManageTagsView.TagRow`; it will apply to anything similar.
- `confirmationDialog` with `titleVisibility: .visible`, a restated destructive button, and a `message` that says what will be lost.
- **Deleting a person is the only removal path in the app**, and it lives only on the roster. No archive.

### 6.2 Editing

**Contact Detail has no Edit/Save mode.** Bindings write straight to the model; the parent observes the raw values and reschedules (`onChange(of: person.cadenceRaw)` → `actions.notifyDidChange`). Add this to any new configuration surface rather than introducing a save button.

Free text is the exception, because saving every keystroke is wasteful: `NotesSection` autosaves on a 0.8-second pause, on losing focus, and on disappearing — and it adopts a value edited on another device unless the field is currently focused.

Sheets that *create* something (Setup, Key date, New tag) do have Cancel/Save, because nothing exists to write to yet. Their confirmation button is `.disabled` until the draft is valid, and duplicates are detected as you type rather than swallowed on tap.

### 6.3 Time and the scene phase

Every screen that shows a relative date keeps `@State private var now = Date.now` and refreshes it when the scene becomes active. A screen that has been open since yesterday must not claim something is due today. Settings re-probes notification permission, lock availability, and iCloud on the same signal, because returning from iOS Settings is exactly when those change.

### 6.4 Coalescing and painting

- A burst of preference flips settles into one reschedule pass with a 400 ms cancellable delay (`SettingsView.notificationsDidChange`). The task is unstructured on purpose — it must survive switching tabs mid-settle.
- A synchronous, expensive operation gets a short `Task.sleep` first so its in-flight state can paint (`SyncRows` sleeps 300 ms so "Updating…" appears before the container rebuild blocks).
- A control that triggers an expensive change is `.disabled` while it is in flight, with a re-entry guard against the echo when a failure snaps it back.

---

## 7. Screen boundaries

These are behavioural, but they are the main reason the UI stays simple, so they belong here too. An action belongs to exactly one screen:

| Screen | Owns | Never |
|---|---|---|
| **Upcoming** | Logging a touch, Remind me tomorrow, Skip | — |
| **Contact Detail** | Reading and configuring one person | Logging, snoozing, deleting |
| **People** | Find, open, add, remove | Logging, snoozing, skipping |
| **Settings** | App-level defaults and machinery; the tag vocabulary | Per-person editing; any "reset all" / "delete all" |

Swipe actions on Upcoming appear **only on rows that are actionable** — holding or skipping a reach-out that isn't due yet would do nothing, so the affordance isn't offered.

**Tags never affect cadence.** They are labels for grouping and filtering, and the section footer says so out loud. Tags are created and destroyed in exactly one place (Manage tags); everywhere else is pick-only, from a menu, with no free text.

---

## 8. Accessibility

Most of this is free, which is the point of §1.1. The parts that aren't:

- **Combine a row into one element** (`.accessibilityElement(children: .combine)`) and give it a hint that names the destination.
- **Label every icon-only button** with the act and its object: "Log reach-out with Maya Patel", "Mark Maya Patel's birthday handled", "Create a tag".
- **Hide decoration**: avatars, hand-drawn chevrons, and the privacy overlay glyph are all `.accessibilityHidden(true)`.
- **Say what a custom control's state is**: the selected tag pill adds `.isSelected`; the horizon filter carries `.accessibilityValue(horizon.label)`.
- Minimum 44×44 tap targets on icon-only controls.
- Dynamic Type: no fixed font sizes, no fixed row heights, `.lineLimit(1)` only on lines that have a shorter fallback elsewhere, and `RoundedChrome` re-applies on every size change.

---

## 9. Deliberately not here

Do not add these back without changing this document first.

- **No custom colours, gradients, or shadows** beyond the toast's single soft shadow.
- **No cards, no custom containers.** Grouping is `Section`.
- **No red status, no badges, no streaks, no counters** other than the overdue count in the title dropdown.
- **No custom animation curves, springs, or durations.**
- **No second haptic.**
- **No `ScrollView`** other than the tag pill row. Everything else is a `List` or a `Form`.
- **No large navigation titles.**
- **No modal Contact Detail.**
- **No manual contact entry** in v1 — adding is from Contacts, one at a time.
- **No onboarding flow.** The first-run empty state is the onboarding.
- **No `UITableView` wrapping.** The one UIKit wrap in the app is `CNContactPickerViewController`.

---

## 10. Designing something new

A checklist, in order. If you can't answer one, the design isn't ready.

1. **Which spec in `prds/` owns this?** Read it, including "What's deliberately not here" — an omission there is a decision, not a gap.
2. **Which screen does the action belong to?** (§7.) If the answer is "two", the design is wrong.
3. **Which existing screen is this most like?** Build from that file. Contact Detail for configuration, Upcoming for a feed, Settings for preferences, `NewTagSheet` for a one-field sheet.
4. **Can it be stock?** `List`, `Form`, `Section`, `Menu`, `Picker`, `Toggle`, `ContentUnavailableView`, `confirmationDialog`, `.swipeActions`, `.searchable`, `.toolbarTitleMenu`. If not, say why in a comment at the call site — every exception in this codebase has one.
5. **What are its empty, denied, filtered, and first-run states?** Write the copy for each before writing the view.
6. **What does it look like at the largest Dynamic Type size, in dark mode, with VoiceOver on?** Run it, don't assume.
7. **Does it need an undo, a confirmation, or neither?** One tap that moves a clock → undo. Anything that destroys → confirmation. Everything else → neither.
8. **Does it add a colour, an animation curve, a haptic, or a `ScrollView`?** If yes, it's probably wrong. If it's genuinely right, update §2 and §9 here as part of the same change.
9. **Update `CHANGELOG.md`** under `[Unreleased]`, in plain English for someone holding the phone — no type names, no frameworks. (See `CLAUDE.md` for the full rule.)

### On references

The Mobbin MCP server is connected and is a good way to settle layout, ordering, and flow questions by seeing how shipped apps arrange a roster or a detail screen. What comes back is screenshots of apps built on custom design systems.

**A reference gets translated into stock `List`, `Form`, and SF Symbols, or it doesn't land.** If a reference can only be matched with custom drawing, that's a signal to drop the reference, not the rule.

---

## 11. Where things live

| Concern | File |
|---|---|
| Typeface, UIKit chrome | `Kith/App/RoundedChrome.swift` |
| Tab shell | `Kith/App/RootTabView.swift` |
| Theme (Light/Dark/System) | `Kith/Settings/AppTheme.swift`, applied in `KithApp` |
| The row shape | `Kith/Upcoming/UpcomingRow.swift`, `Kith/People/PeopleRow.swift` |
| Avatars | `Kith/Contacts/ContactAvatarView.swift` |
| Status wording and tint | `Kith/Models/CatchupStatus.swift`, `Kith/Upcoming/UpcomingItem.swift` |
| Tag filter | `Kith/Tags/TagPillRow.swift` |
| Shared tag editor | `Kith/Tags/TagsSection.swift` |
| Empty states | `Kith/Upcoming/UpcomingEmptyView.swift`, `Kith/People/PeopleEmptyView.swift` |
| Undo | `Kith/Upcoming/UndoToast.swift` |
| Sheet-from-`Form` pattern | `Kith/Settings/SettingsView.swift` |
| Navigation-style row that presents | `Kith/Settings/ManageTagsRow.swift` |
