import Foundation

/// Built from the widget's configuration intent, same as `TransmissionSettings`.
/// No RPC path — qBittorrent's Web API has a fixed `/api/v2/...` layout, so
/// `QBittorrentClient` appends each endpoint's path itself rather than
/// taking one from configuration.
struct QBittorrentSettings {
    var host: String
    var port: Int
    var useHTTPS: Bool
    var username: String

    func url(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = useHTTPS ? "https" : "http"
        components.host = host
        components.port = port
        components.path = path
        return components.url
    }
}
