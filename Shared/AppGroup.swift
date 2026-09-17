import Foundation

/// Neither target is App-Sandboxed (see project.yml — the App Groups
/// capability that real sandboxing would need isn't provisionable on a free
/// Personal Team, only a paid Apple Developer Program membership). Without
/// the sandbox, `UserDefaults(suiteName:)` just reads/writes a plain
/// `~/Library/Preferences/<identifier>.plist`, which both the host app and
/// widget extension process can freely share as the same macOS user — no
/// App Group container or entitlement needed. Only change this string if
/// you also change it everywhere else it's read (nothing else currently
/// needs to match it, since it's just a UserDefaults suite name now).
enum AppGroup {
    static let identifier = "group.com.halozero.transmissionwidget"

    static var defaults: UserDefaults {
        guard let d = UserDefaults(suiteName: identifier) else {
            // Falls back instead of crashing: Xcode Previews run in a
            // process that can behave unpredictably around suite-named
            // UserDefaults, and this used to be a fatalError() that took
            // down the whole Preview canvas. Standard UserDefaults works
            // fine for local dev; it just won't be shared with the widget
            // extension in that context.
            #if DEBUG
            print("⚠️ AppGroup '\(identifier)' unavailable in this process — falling back to standard UserDefaults. Expected in Xcode Previews; settings won't be shared with the widget in that context.")
            #endif
            return .standard
        }
        return d
    }
}

/// Non-secret connection settings. The password is stored separately in the
/// Keychain (see KeychainHelper) since UserDefaults, even in an App Group,
/// is not encrypted at rest.
struct TransmissionSettings: Codable {
    var host: String
    var port: Int
    var useHTTPS: Bool
    var rpcPath: String
    var username: String

    static let `default` = TransmissionSettings(
        host: "192.168.1.1",
        port: 9091,
        useHTTPS: false,
        rpcPath: "/transmission/rpc",
        username: ""
    )

    private static let key = "transmissionSettings"

    static func load() -> TransmissionSettings {
        guard let data = AppGroup.defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(TransmissionSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            AppGroup.defaults.set(data, forKey: TransmissionSettings.key)
        }
    }

    var baseURL: URL? {
        var components = URLComponents()
        components.scheme = useHTTPS ? "https" : "http"
        components.host = host
        components.port = port
        components.path = rpcPath
        return components.url
    }
}
