import SwiftUI

struct SettingsView: View {
    @State private var settings = TransmissionSettings.load()
    @State private var password: String = KeychainHelper.loadPassword() ?? ""
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Host", text: $settings.host)
                TextField("Port", value: $settings.port, formatter: NumberFormatter())
                TextField("RPC path", text: $settings.rpcPath)
                Toggle("Use HTTPS", isOn: $settings.useHTTPS)
            }

            Section("Credentials (optional)") {
                TextField("Username", text: $settings.username)
                SecureField("Password", text: $password)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(statusMessage.hasPrefix("✓") ? .green : .red)
            }

            HStack {
                Button(isTesting ? "Testing…" : "Test Connection") {
                    Task { await testConnection() }
                }
                .disabled(isTesting)

                Spacer()

                Button("Save") {
                    settings.save()
                    KeychainHelper.savePassword(password)
                    reloadWidget()
                    statusMessage = "✓ Saved"
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        // This button intentionally tests the in-progress form values
        // against the real server, not the saved settings that
        // makeTransmissionClient() would load — that's the whole point of
        // "Test Connection". The one exception is Xcode's interactive
        // Preview canvas, which shouldn't ever block on a real network call.
        let client: any TransmissionFetching = DevEnvironment.isXcodePreview
            ? MockTransmissionClient(scenario: DevEnvironment.mockScenario)
            : TransmissionRPCClient(settings: settings, password: password)

        do {
            let rows = try await client.fetchTopTorrents(limit: 4)
            statusMessage = "✓ Connected — \(rows.count) active torrent\(rows.count == 1 ? "" : "s")"
        } catch {
            statusMessage = "✗ \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
}
