# Changelog

All notable changes to this project are documented here. Format loosely
follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/); this
project doesn't cut versioned releases yet, so entries are grouped under
`Unreleased`.

## [Unreleased]

### Added
- Per-configuration bundle identifiers (`.debug` suffix on Debug builds)
  so a Debug build can install and run side-by-side with a Release build.
- Widget extension scheme declared in `project.yml` so `xcodegen generate`
  doesn't silently drop it.
- Debug-only scenario testing: a menu bar **Debug: Load Scenario** picker
  (Normal/Empty/Error/Live Data) and a `MockTransmissionClient.Scenario.hardcoded`
  constant, both routed through a single explicit `.forced` scenario so the
  real widget and the host app always agree, without racing a live refresh.
- A "too many torrents" mock scenario (`.tooManyTorrents`) for exercising
  row-cap overflow behavior deliberately.
- `Shared/Constants.swift` — single source of truth for how many rows each
  widget family shows (`maxRows(for:)`) and how much data to fetch/cache
  (`fetchLimit`).
- Content-type icon per row, inferred from the torrent's file extension
  (disk image, archive, video, audio, folder as the fallback for
  multi-file releases).
- Filled progress circle replacing the linear progress bar: blue while in
  progress, green once complete, percentage label shown only while
  incomplete.
- Status (Downloading/Seeding/Paused/Checking/Waiting) folded into the
  row's second line alongside percent and both rates.
- Fixture set grown from 5 to 12 torrents, covering every extension/status
  combination the UI branches on.

### Changed
- Widget row count: medium 2 → 3, large 3 → 6 (`.systemSmall` dropped
  entirely — the redesigned row needs more room than it can offer).
- `TorrentEntry` and `TorrentProvider` split out of `TransmissionWidget.swift`
  into their own files under `Widget/`.

### Fixed
- Percent label inside the progress circle switched from `.primary` (black
  in light mode) to white with a dark shadow halo — `.primary` had poor
  contrast against the blue progress wedge.
- `MockTransmissionClient.Scenario.hardcoded` had been left at `.normal`,
  which unconditionally overrode the menu picker's persisted choice,
  making Empty/Error/Live Data appear to do nothing. Reset to `nil`.

### Security
- Removed the maintainer's personal name from all identifiers (bundle IDs,
  App Group identifier, Keychain access group) ahead of publishing —
  `com.rohan.*` → `com.halozero.*`.
