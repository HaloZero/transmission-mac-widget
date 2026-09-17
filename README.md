# Transmission Mac Widget

A macOS menu-bar app + WidgetKit widget that shows your most active
Transmission torrents (status, progress, ↓/↑ rate), talking directly to
Transmission's RPC endpoint — the same one `transmission-remote` and the
web UI use. Row counts per widget size aren't hardcoded here — they live
in `Shared/Constants.swift`, the single place that controls them.

The project is described by `project.yml` for XcodeGen; the generated
`.xcodeproj` is a build artifact and isn't checked into git.

## Build it and put it on your Mac

(Assumes you've already run `xcodegen generate` and opened the resulting
`.xcodeproj`.) A Debug build launched via Xcode's Run button quits the
moment you stop the Xcode session, which defeats the point of a menu-bar
widget host — so for day-to-day use you want an exported `.app` instead.
Two ways to do it:

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
   General → Login Items** to have it launch at login — worth doing,
   since the host app's own background refresh (see Warnings below)
   only runs while it's actually open.

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

## Transmission-side settings

In Transmission's settings (`settings.json` or the daemon's web UI
preferences), you'll want:

- `rpc-enabled: true`
- `rpc-port`, `rpc-url` matching what you enter in the app (defaults
  here assume port `9091`, path `/transmission/rpc`)
- If Transmission is reachable only from a different host/network than
  the one this app runs on, make sure `rpc-whitelist-enabled` /
  `rpc-whitelist` / `rpc-host-whitelist` are configured to allow
  connections from wherever this Mac actually connects from.
- Basic auth (`rpc-authentication-required`, `rpc-username`,
  `rpc-password`) is optional but recommended if the daemon is
  reachable beyond localhost; the app's Settings screen has fields for
  both.

## Warnings

- **Refresh cadence has two different knobs, both in
  `Shared/Constants.swift`.** `hostPollInterval` controls how often the
  host app polls Transmission and refreshes the shared cache while
  it's running — it's a plain background loop, not a widget reload, so
  it isn't subject to WidgetKit's system reload budget. `widgetReloadInterval`
  (15 minutes) controls how often the host app actually asks WidgetKit
  to redraw the widget — keep this modest, since that budget applies
  no matter who triggers the reload, and calls beyond it are silently
  dropped rather than queued. The widget's own `TorrentProvider` only
  falls back to fetching directly if the cache is stale beyond
  `cacheStalenessThreshold`, i.e. the host app hasn't been running.
- Sort order / row count could easily become a `WidgetConfigurationIntent`
  if you want per-widget-instance settings (e.g. one small widget for
  downloads, one for seeding) instead of the shared global settings used
  here.
- If you'd rather not deal with Keychain access groups at all, you can
  drop `KeychainHelper` and store the password directly in the App
  Group `UserDefaults` alongside the rest of `TransmissionSettings` —
  less secure, but one less capability to configure.
