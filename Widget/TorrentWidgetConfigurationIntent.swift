import AppIntents

/// Configures which torrent server (and backend — Transmission or
/// qBittorrent) this widget instance connects to. WidgetKit persists these
/// values per widget instance (set via long-press → Edit Widget) and hands
/// them straight to `TorrentProvider` on every timeline request — no App
/// Group, Keychain, or host app settings window needed, since the widget is
/// the only thing that ever reads them.
///
/// The password is stored as a plain parameter rather than in the Keychain
/// — WidgetKit's own configuration form has no secure/masked field type, so
/// it's visible in the Edit Widget sheet either way. Acceptable for a
/// personal, local-network tool; revisit if that ever changes.
struct TorrentWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Torrent Server"
    static var description = IntentDescription("The Transmission or qBittorrent server this widget connects to.")

    @Parameter(title: "Backend", default: .transmission)
    var backend: TorrentBackend

    @Parameter(title: "Host", default: "192.168.1.1")
    var host: String

    @Parameter(title: "Port", default: 9091)
    var port: Int

    @Parameter(title: "Use HTTPS", default: false)
    var useHTTPS: Bool

    // Transmission only — qBittorrent's Web API has a fixed /api/v2/... layout,
    // so this is ignored (but still shown, since ParameterSummary can only
    // conditionally show parameters for AppUnionValue-backed types, not a
    // plain AppEnum like TorrentBackend) when Backend is qBittorrent.
    @Parameter(title: "RPC Path (Transmission only)", default: "/transmission/rpc")
    var rpcPath: String

    @Parameter(title: "Username", default: "")
    var username: String

    @Parameter(title: "Password", default: "")
    var password: String

    static var parameterSummary: some ParameterSummary {
        Summary("Connect to \(\.$host) via \(\.$backend)") {
            \.$port
            \.$useHTTPS
            \.$rpcPath
            \.$username
            \.$password
        }
    }

    var transmissionSettings: TransmissionSettings {
        TransmissionSettings(host: host, port: port, useHTTPS: useHTTPS, rpcPath: rpcPath, username: username)
    }

    var qbittorrentSettings: QBittorrentSettings {
        QBittorrentSettings(host: host, port: port, useHTTPS: useHTTPS, username: username)
    }

    /// Distinguishes cached snapshots per server+backend so two differently
    /// configured widget instances don't clobber each other's cache — there's
    /// no App Group, so `WidgetSnapshot` lives in `UserDefaults.standard`,
    /// which is process-wide rather than per-widget-instance.
    var cacheKey: String {
        "widgetSnapshot.\(backend.rawValue).\(host).\(port)"
    }
}
