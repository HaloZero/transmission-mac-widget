import AppIntents

/// Configures which Transmission server this widget instance connects to.
/// WidgetKit persists these values per widget instance (set via long-press
/// → Edit Widget) and hands them straight to `TorrentProvider` on every
/// timeline request — no App Group, Keychain, or host app settings window
/// needed, since the widget is the only thing that ever reads them.
///
/// The password is stored as a plain parameter rather than in the Keychain
/// — WidgetKit's own configuration form has no secure/masked field type, so
/// it's visible in the Edit Widget sheet either way. Acceptable for a
/// personal, local-network tool; revisit if that ever changes.
struct TransmissionWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Transmission Server"
    static var description = IntentDescription("The Transmission server this widget connects to.")

    @Parameter(title: "Host", default: "192.168.1.1")
    var host: String

    @Parameter(title: "Port", default: 9091)
    var port: Int

    @Parameter(title: "Use HTTPS", default: false)
    var useHTTPS: Bool

    @Parameter(title: "RPC Path", default: "/transmission/rpc")
    var rpcPath: String

    @Parameter(title: "Username", default: "")
    var username: String

    @Parameter(title: "Password", default: "")
    var password: String

    static var parameterSummary: some ParameterSummary {
        Summary("Connect to \(\.$host)") {
            \.$port
            \.$useHTTPS
            \.$rpcPath
            \.$username
            \.$password
        }
    }

    var settings: TransmissionSettings {
        TransmissionSettings(host: host, port: port, useHTTPS: useHTTPS, rpcPath: rpcPath, username: username)
    }
}
