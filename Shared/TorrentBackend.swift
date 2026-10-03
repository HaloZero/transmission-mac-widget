import AppIntents

/// Which torrent daemon a widget instance talks to — surfaced in the Edit
/// Widget sheet via `TorrentWidgetConfigurationIntent.backend`, and used by
/// `TorrentProvider` to pick between `TransmissionRPCClient` and
/// `QBittorrentClient`.
enum TorrentBackend: String, AppEnum {
    case transmission
    case qbittorrent

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Backend"
    static var caseDisplayRepresentations: [TorrentBackend: DisplayRepresentation] = [
        .transmission: "Transmission",
        .qbittorrent: "qBittorrent"
    ]
}
