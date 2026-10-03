import Foundation

/// Subset of Transmission's torrent-status values we care about for display.
/// Full list: https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md
enum TorrentStatus: Int, Codable {
    case stopped = 0
    case checkWaiting = 1
    case checking = 2
    case downloadWaiting = 3
    case downloading = 4
    case seedWaiting = 5
    case seeding = 6

    var symbolName: String {
        switch self {
        case .stopped: return "pause.circle"
        case .checkWaiting, .checking: return "magnifyingglass.circle"
        case .downloadWaiting, .downloading: return "arrow.down.circle.fill"
        case .seedWaiting, .seeding: return "arrow.up.circle.fill"
        }
    }

    var statusLabel: String {
        switch self {
        case .stopped: return "Paused"
        case .checkWaiting, .checking: return "Checking"
        case .downloadWaiting: return "Waiting"
        case .downloading: return "Downloading"
        case .seedWaiting: return "Waiting"
        case .seeding: return "Seeding"
        }
    }
}

extension TorrentStatus {
    /// Maps qBittorrent's `state` string (`torrents/info` response) onto
    /// the same status set Transmission uses. qBittorrent has finer-grained
    /// states (stalled, forced, queued, moving, allocating, error) than
    /// Transmission's six; each collapses onto its closest Transmission
    /// analog rather than growing the enum, since nothing in the UI branches
    /// on qBittorrent-specific nuance. Covers both `pausedDL`/`pausedUP` and
    /// `stoppedDL`/`stoppedUP` — qBittorrent 5.x renamed its pause/resume
    /// terminology to stop/start, confirmed live against a real server
    /// returning `stoppedDL`.
    init(qbittorrentState: String) {
        switch qbittorrentState {
        case "downloading", "forcedDL", "metaDL", "stalledDL", "allocating":
            self = .downloading
        case "queuedDL":
            self = .downloadWaiting
        case "uploading", "forcedUP", "stalledUP", "moving":
            self = .seeding
        case "queuedUP":
            self = .seedWaiting
        case "checkingDL", "checkingUP", "checkingResumeData":
            self = .checking
        default: // pausedDL, pausedUP, stoppedDL, stoppedUP, error, missingFiles, ...
            self = .stopped
        }
    }
}
