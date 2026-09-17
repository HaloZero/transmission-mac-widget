# Transmission Widget Host

A macOS menu-bar app + WidgetKit widget that shows up to 4 rows of your
most active Transmission torrents (progress, ↓/↑ rate), talking directly
to Transmission's RPC endpoint — the same one `transmission-remote` and
the web UI use.

I can't run Xcode from here, so this is the source plus a `project.yml`
for XcodeGen to turn into a project — no manual target/capability
clicking required. Layout matches Xcode's target structure:

```
TransmissionWidgetHost/
├── project.yml      # XcodeGen spec — generates the .xcodeproj
├── Shared/          # added to BOTH targets
│   ├── AppGroup.swift
│   ├── KeychainHelper.swift
│   ├── MockTransmissionClient.swift
│   ├── TransmissionFetching.swift
│   ├── TransmissionModels.swift
│   └── TransmissionRPCClient.swift
├── App/             # main app target only
│   ├── TransmissionHostApp.swift
│   ├── SettingsView.swift
│   └── ContentView.swift
└── Widget/          # widget extension target only
    ├── TransmissionWidget.swift
    └── TransmissionWidgetBundle.swift
```

## Set up the project with XcodeGen

`project.yml` describes both targets, their bundle IDs, and the App
Groups + Keychain Sharing entitlements — so the whole project is one
command instead of clicking through Xcode's capability UI.

1. Install XcodeGen if you don't have it: `brew install xcodegen`
2. From the `TransmissionWidgetHost/` folder: `xcodegen generate` — this
   creates `TransmissionWidgetHost.xcodeproj` with both targets wired up,
   sources attached, `Shared/` files added to both, and entitlements
   files generated at `App/TransmissionWidgetHost.entitlements` and
   `Widget/TransmissionWidgetExtension.entitlements`.
3. Open the generated `.xcodeproj`. Set your Team ID: either fill in
   `DEVELOPMENT_TEAM` in `project.yml` and re-run `xcodegen generate`, or
   just set it once per target in Xcode's Signing & Capabilities tab
   (Xcode will remember it in the `.xcodeproj`, but re-running `xcodegen
   generate` regenerates the project from `project.yml`, so the
   `project.yml` edit is the one that sticks).
4. `KeychainHelper.accessGroup` needs your real Team ID substituted in
   for `YOUR_TEAM_ID` — open the built app's
   Signing & Capabilities tab (or check
   `App/TransmissionWidgetHost.entitlements` after building) to see the
   resolved `keychain-access-groups` value, then update the Swift
   constant to match.
5. Build the `TransmissionWidgetHost` scheme (it embeds the widget
   extension automatically per `project.yml`'s `dependencies:`), run it
   once, open **Preferences** from the menu bar item, fill in your Mac
   mini's Transmission RPC settings, hit **Test Connection**, then
   **Save**. Then add the widget from the macOS widget gallery — it
   reads the same App Group settings.
6. Whenever you add/remove/rename a Swift file under `App/`, `Shared/`,
   or `Widget/`, just re-run `xcodegen generate` rather than editing
   the `.xcodeproj` by hand — that's the whole point of driving it from
   `project.yml`. It's safe to run repeatedly; treat `project.yml` as
   the source of truth and the `.xcodeproj` as a build artifact (worth
   adding `*.xcodeproj` to `.gitignore` if you put this in git).

If you'd rather do it by hand in Xcode's UI instead (New Project → App,
then File → New Target → Widget Extension, adding App Groups/Keychain
Sharing capabilities manually), that works too — `project.yml` just
saves you those clicks and makes the setup reproducible.

## Build it and put it on your Mac

`xcodegen generate` only creates the project — you still need to build
and export an actual `.app` to run day-to-day (a Debug build launched
via Xcode's Run button quits the moment you stop the Xcode session,
which defeats the point of a menu-bar widget host). Two ways to do it:

### Option A — Archive & export (recommended for daily use)

1. In Xcode, select the **TransmissionWidgetHost** scheme, and set the
   destination to **My Mac**.
2. Make sure a **Team** is selected for both targets (Signing &
   Capabilities tab) — your personal Apple ID team is fine, no paid
   Developer Program membership required for local use.
3. **Product → Archive.** This always builds Release, which is what
   you want (Debug widget extensions are less reliable about
   background refresh).
4. When the Organizer window opens, select the archive → **Distribute
   App → Copy App** → choose a folder to export to. This produces
   `TransmissionWidgetHost.app` signed with your local development
   certificate — no App Store, no notarization needed.
5. Drag `TransmissionWidgetHost.app` into `/Applications` (or
   `~/Applications`).
6. First launch will likely get Gatekeeper's "unidentified developer"
   warning since it's not notarized — right-click the app → **Open**
   once to bypass that; after that it opens normally.
7. Since it's set as `LSUIElement`, it won't show a Dock icon — look
   for it in the menu bar. You can add it to **System Settings →
   General → Login Items** to have it launch at login.

### Option B — Just run it from Xcode while testing

`Cmd+R` builds and runs immediately, which is the fastest loop while
you're still tweaking `SettingsView`/`ContentView`/the widget UI. The
app and its embedded widget extension get installed into
`~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/`, and
macOS registers the widget with the widget gallery as long as that
build exists on disk — but the app itself quits when you stop the
Xcode session (Cmd+.), which stops the widget updating too. Once
you're happy with it, switch to Option A for something that survives
Xcode closing.

### A note on the free-Apple-ID caveat

If you're signing with a free personal team (no $99/year Developer
Program), the provisioning profile Xcode generates for the App Group +
Keychain Sharing entitlements expires after about a week — you'll need
to re-open the project and re-run Archive/Copy App periodically to
refresh it. A paid Developer ID membership avoids that expiry
entirely; for a personal home-server tool either is fine, just know
the free path needs an occasional rebuild.

## Adding the real Transmission icon

The widget header uses `TransmissionLogoView`, which looks for an image
named **TransmissionLogo** in `Widget/Assets.xcassets` and falls back
to an SF Symbol if that asset doesn't exist yet — so the widget looks
fine out of the box, but you can drop the real icon in:

1. Get the icon file itself — either pull it out of your own copy of
   Transmission.app (right-click → Show Package Contents →
   `Contents/Resources/`, look for the `.icns`), or grab it from the
   `macosx/` folder of the official
   [transmission/transmission](https://github.com/transmission/transmission)
   repo (dual MIT/GPL licensed). If you only have an `.icns`, unpack it
   to PNGs with `iconutil -c iconset AppIcon.icns` and pick whichever
   size you want (a 64–128px one is plenty for a widget row icon).
2. In Xcode, right-click `Widget/` → **New File → Asset Catalog**,
   name it `Assets.xcassets`.
3. Inside it, **New Image Set**, name it exactly `TransmissionLogo`,
   and drag the PNG in (1x is enough; add 2x/3x if you have them).
4. Add `Widget/Assets.xcassets` to the **TransmissionWidgetExtension**
   target's membership (File Inspector, right panel) if Xcode doesn't
   do it automatically.
5. Re-run `xcodegen generate` if you're regenerating the project from
   scratch afterward — asset catalogs under a target's `sources:` path
   are picked up automatically, no `project.yml` change needed since
   `Widget/` is already listed as a source path for that target.
6. Build again — the widget will now show the real icon instead of the
   SF Symbol fallback.

## Developing without hitting the real server

Previews were mostly broken before this because `ContentView`,
`SettingsView`'s Test Connection, and the widget's `TimelineProvider`
all constructed `TransmissionRPCClient` directly and hit the live RPC
endpoint — which either hangs or errors out in Xcode's Preview canvas
(a lightweight process that usually lacks this app's entitlements) and
is just annoying during normal development when you're off the
tailnet. There was also a real crash bug: `AppGroup.defaults` used to
`fatalError()` if the App Group suite wasn't available, which is
exactly the situation Previews are usually in before entitlements are
fully wired up.

Two fixes, both in `Shared/`:

- **`AppGroup.defaults` no longer crashes** — it falls back to
  `UserDefaults.standard` with a console warning instead of a
  `fatalError`, so any process without the App Group entitlement
  (Previews, or before you've run `xcodegen generate` + set a Team)
  degrades gracefully instead of taking down the canvas.
- **`TransmissionFetching` protocol + `MockTransmissionClient`** — the
  real client and a fixture-backed mock both conform to the same
  `func fetchTopTorrents(limit:) async throws -> [TorrentInfo]`, and
  `makeTransmissionClient()` in `TransmissionFetching.swift` picks
  between them:
  - **Automatically mock** whenever `XCODE_RUNNING_FOR_PREVIEWS=1` is
    set — which Xcode sets for you in every Preview, no configuration
    needed.
  - **Mock on demand** when you set `TRANSMISSION_USE_MOCK_DATA=1` as
    an environment variable on the scheme (Product → Scheme → Edit
    Scheme → Run → Arguments → Environment Variables) — useful for
    running the actual app or widget locally without the Mac mini
    reachable.
  - Pair either with `TRANSMISSION_MOCK_SCENARIO=empty` or `=failure`
    to deliberately preview the "no active torrents" and error states
    instead of the happy path.

`MockTransmissionClient` never touches the network, Keychain, or App
Group — it just sleeps briefly (to simulate latency) and returns
`TorrentInfo.fixtures`, five torrents covering every status the UI
branches on (downloading, seeding, checking, stopped).

`ContentView` also takes an optional `client:` parameter so its
Previews can pin down a scenario explicitly rather than relying only
on auto-detection:

```swift
#Preview("Empty") {
    ContentView(client: MockTransmissionClient(scenario: .empty))
}
```

The widget's Previews do the same by passing fixture data straight
into a `TorrentEntry` (see the three `#Preview` blocks at the bottom of
`Widget/TransmissionWidget.swift`) — normal, empty, and error variants,
all viewable in Xcode's canvas without any network access at all.

`SettingsView`'s **Test Connection** button is the one place that
deliberately still hits the real server when run normally — it exists
specifically to verify whatever host/port/credentials you just typed,
so mocking it there would defeat the point. It only falls back to the
mock automatically inside Xcode's interactive Preview canvas, so
tapping it there can't hang on a network call.

## Transmission-side settings

On m1mediaserver's Transmission (`settings.json` or the daemon's web UI
preferences), you'll want:

- `rpc-enabled: true`
- `rpc-port`, `rpc-url` matching what you enter in the app (defaults
  here assume port `9091`, path `/transmission/rpc`)
- If you connect over Tailscale (`nutria-typhon.ts.net`) rather than
  local Bonjour, set `rpc-whitelist-enabled: false` or add your Mac's
  Tailscale IP to `rpc-whitelist`, and set `rpc-host-whitelist` to
  include the tailnet hostname — this is the same host-header issue
  your Alfred `add_torrent.py` workflow already had to work around.
- Basic auth (`rpc-authentication-required`, `rpc-username`,
  `rpc-password`) is optional but recommended since this'll be reachable
  over the tailnet; the app's Settings screen has fields for both.

## Notes on the design

- **Widget does its own networking.** The `TimelineProvider` calls
  Transmission RPC directly on each refresh (every 5 minutes by
  default — see `nextRefresh` in `TransmissionWidget.swift`), so the
  widget stays current even if the menu bar app isn't running. It also
  caches the last good result to the App Group so a temporary failure
  (Mac mini asleep, VPN down) shows stale-but-present data instead of a
  blank widget.
- **Menu bar app is for configuration + on-demand refresh.** It shows
  the same 4 rows in a popover and can force an immediate widget reload
  via `WidgetCenter.reloadAllTimelines()` after you change settings.
- **Row count**: capped at 4 as requested — `.systemSmall` shows 2 (not
  enough room for 4), `.systemMedium`/`.systemLarge` show up to 4.
- Sorting picks the torrents with the most combined ↓/↑ throughput
  first, so the 4 visible rows are whatever's actually active rather
  than an arbitrary alphabetical slice.

## Things you may want to change

- Refresh cadence (`nextRefresh`) — widgets have a limited daily
  refresh budget from the system, so don't go much below 5 minutes.
- Sort order / row count could easily become a `WidgetConfigurationIntent`
  if you want per-widget-instance settings (e.g. one small widget for
  downloads, one for seeding) instead of the shared global settings used
  here.
- If you'd rather not deal with Keychain access groups at all, you can
  drop `KeychainHelper` and store the password directly in the App
  Group `UserDefaults` alongside the rest of `TransmissionSettings` —
  less secure, but one less capability to configure for a
  Tailscale-only home setup.
