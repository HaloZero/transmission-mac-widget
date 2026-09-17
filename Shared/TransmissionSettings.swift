import Foundation

/// Built directly from the widget's configuration intent each time a fetch
/// runs (see TransmissionWidgetConfigurationIntent) — WidgetKit already
/// persists the intent's own parameter values per widget instance, so
/// nothing here needs its own storage or an App Group.
struct TransmissionSettings {
    var host: String
    var port: Int
    var useHTTPS: Bool
    var rpcPath: String
    var username: String

    var baseURL: URL? {
        var components = URLComponents()
        components.scheme = useHTTPS ? "https" : "http"
        components.host = host
        components.port = port
        components.path = rpcPath
        return components.url
    }
}
