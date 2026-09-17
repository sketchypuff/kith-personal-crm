# Changelog

Everything that's changed in Kith, newest first, in plain English.

Kith is a private address book for keeping in touch. It reminds you when it's
been a while since you spoke to someone, and never lets you forget a birthday.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Each heading is a version of the app, with the TestFlight build number beside it.

## [Unreleased]

### Added

- Call, Message, and WhatsApp buttons now sit under a person's name, so you can reach them without going hunting for their number. Tapping one counts as catching up with them, and their timeline remembers which way you got in touch.

### Changed

- Tapping one of those buttons more than once in a day only counts as catching up once. A call that rings out followed by a message is one conversation, not two.
- When you come back to Kith after tapping one, a short bar appears offering to undo it, in case you tapped by accident or never actually got through.
- The WhatsApp button is only there if you have WhatsApp installed, and all three are hidden for anyone whose contact card has no phone number on it.

### Deprecated

### Removed

### Fixed

- Kith now asks permission to read your Contacts the first time it needs to. Until now it never asked, so it could never load anyone's photo — people who should have had a picture showed their initials instead, with nothing on screen to explain why.

### Security

## [1.2] - 2026-09-11 — build 4

A pass over the way the app looks and moves, and a tidier person page.

### Added

### Changed

- The bar that lets you undo a check-in now has the same frosted look as the app's other floating buttons, so it sits over your list instead of on top of it.
- The tag filter row feels like one piece of glass rather than separate buttons, and the highlight slides between tags instead of blinking from one to the next.
- Lists now fade softly where they run under the bar at the bottom of the screen and under the filter row at the top, instead of cutting off in a hard line.
- On People, the search box has moved into the top bar as a small button that opens when you tap it. You get a full extra row of people on screen, and the box is out of the way when you aren't searching.
- On a person's page, the Info and Timeline switch now stays at the top as you scroll, so you can move between them without scrolling back up.
- Their photo, name, and next catch-up no longer sit above the Timeline. That's a list of what's already happened, so it now starts at the first entry — their name is in the bar at the top either way.

### Deprecated

### Removed

### Fixed

### Security

## [1.1] - 2026-09-11 — build 3

The first version sent out for testing, plus a rethink of how tags work.

### Added

- **Tags are now yours to manage.** Create and delete them in Settings, under
  Other. A tag sticks around even when nobody has it yet, so you can set up the
  groups you want before sorting anyone into them.
- **Filter by tag with one tap.** A row of tag buttons sits at the top of both
  the Upcoming and People screens. Tap one to see only those people, tap it
  again to see everyone. Each screen remembers its own choice.
- **Switch between Upcoming and Overdue by tapping the screen's title.** The
  menu also shows how many people you're behind on, so you can tell at a glance
  even when the list in front of you looks calm.
- **Make a new tag without losing your place.** While tagging someone, a Create
  button in the Tags area takes you straight to the tag list and back.
- **Four tags to start with** — Close friends, Family, Friends, and Work. They
  behave like any other tag, so delete the ones you don't want.

### Changed

- **You now pick tags from a list instead of typing them.** Typing meant one
  slip of the keyboard could turn "Work" into a second, separate tag, splitting
  the same group of people in two.
- **Capital letters and accents no longer create duplicate tags.** "work",
  "Work", and "Wörk" are all treated as the same tag.

### Removed

- **The Upcoming and Overdue buttons that used to sit above the list.** They
  appeared and disappeared depending on whether anyone was overdue, which moved
  the list around under your thumb. Tapping the title does the same job.
- **The overdue filter on the People screen**, now that the title menu on
  Upcoming covers it.

## [1.0] - 2026-09-10 — build 1

The first complete version of the app. Never released — version 1.1 replaced it.

### Added

- **Upcoming: one list of who needs you.** Birthdays, anniversaries, and people
  you're due to catch up with, all in one place, covering the next 30 days.
  Every row takes one tap to deal with, and you can undo it if you tap by
  mistake.
- **Three ways to deal with a reminder.** Tick it off once you've been in touch,
  push it to tomorrow if today got away from you, or skip this round entirely —
  skipping is remembered separately, so it never counts as having spoken.
- **Choose how far ahead you want to look** — just today, the next week, or the
  next month. Anyone you're already overdue with always stays on the list, no
  matter which you pick.
- **People: everyone you're keeping up with, A to Z.** Search by name, by
  anything you've written in their notes, or by tag. Swiping to remove someone
  asks first, and is the only way to remove anyone.
- **Each person's page**, where you set how often you'd like to be reminded and
  on which day, add birthdays and other dates worth remembering, apply tags, and
  jot notes. Everything saves as you go — there's no Save button to remember.
- **Add people straight from your phone's contacts.** Kith spots it if you've
  already added someone and takes you to them rather than making a second copy.
- **Reminders that arrive when you asked for them** — at the day and time you
  chose for each person, and ahead of birthdays so there's time to plan.
- **Lock Kith behind Face ID, Touch ID, or your passcode.** Optional, off by
  default. You can choose whether it locks the moment you leave or after a few
  minutes, and your people are hidden in the app switcher while it's locked.
- **Your data syncs privately through your own iCloud account**, so Kith looks
  the same on every device you own. There's no Kith account, no sign-up, and
  nothing is sent to anyone else. You can turn syncing off at any time, and
  what's already in iCloud stays there.
- **Light and dark themes**, or follow whatever your phone is set to.
- **A softer, rounded typeface** throughout, to make Kith feel less like a
  work tool.
- **An app icon** with its own dark version.

### Changed

- **Upcoming now shows what's coming, not just what's late.** Before, a birthday
  three weeks away stayed invisible until the week it arrived.
- **The People list is one continuous A–Z list.** The letter headings that used
  to divide it are gone. Names starting with a number or symbol still sit at the
  end.
- **The search box only appears once you have six or more people.** Below that,
  reading the list is quicker than typing into it.
- **On first run there's now a single, obvious Add Contact button** instead of
  two competing ones.

### Removed

- **The count of people at the bottom of the People list**, which only repeated
  what the list already showed.
- **The grey band behind the top of the Upcoming and People screens**, which
  made the buttons sitting on it hard to read.

### Fixed

- **The "Made by" page in Settings closed itself the instant you opened it.**
- **A stray line above the first row** on the Upcoming and People screens.

[Unreleased]: https://github.com/sketchypuff/kith-personal-crm/compare/dae5dbf...HEAD
[1.2]: https://github.com/sketchypuff/kith-personal-crm/compare/de0bd93...dae5dbf
[1.1]: https://github.com/sketchypuff/kith-personal-crm/compare/c713549...de0bd93
[1.0]: https://github.com/sketchypuff/kith-personal-crm/compare/37b84ce...c713549
