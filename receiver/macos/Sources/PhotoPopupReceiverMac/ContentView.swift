// ContentView.swift
import SwiftUI

/// The application's primary settings window.
///
/// Displays the listening endpoint URL, controls for auto-popup, auto-clipboard-copy,
/// and password authentication, and a language selector.  On appear it starts the HTTP
/// listener via ``PhotoReceiver`` and wires up the callback for each received photo.
///
/// This mirrors the Windows ``MainWindow`` (WPF) but is written in SwiftUI for
/// macOS.
struct ContentView: View {

    @EnvironmentObject private var settings:  AppSettings
    @EnvironmentObject private var locMgr:    LocalizationManager
    @EnvironmentObject private var appDelegate: AppDelegate

    // MARK: - State

    @State private var endpointUrl:   String = ""
    @State private var serverStarted: Bool   = false
    @State private var serverError:   String?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ──────────────────────────────────────────────────
                HStack {
                    Text(locMgr.getString("AppTitle"))
                        .font(.title2.bold())

                    Spacer()

                    // Language selector
                    HStack(spacing: 6) {
                        Text(locMgr.getString("LanguageLabel"))
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get:  { locMgr.currentLanguage },
                            set:  { locMgr.setLanguage($0) }
                        )) {
                            Text("English").tag("en")
                            Text("Nederlands").tag("nl")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }
                }

                Divider()

                // ── Endpoint URL ─────────────────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(locMgr.getString("EndpointLabel"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if endpointUrl.isEmpty {
                            ProgressView()
                        } else {
                            Text(endpointUrl)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }

                        if let err = serverError {
                            Text(err)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                // ── Behaviour options ────────────────────────────────────────
                Toggle(locMgr.getString("AutoPopupCheckbox"),
                       isOn: $settings.autoPopup)

                Toggle(locMgr.getString("AutoCopyCheckbox"),
                       isOn: $settings.autoCopyToClipboard)

                Divider()

                // ── Password ─────────────────────────────────────────────────
                Toggle(locMgr.getString("RequirePasswordLabel"),
                       isOn: $settings.requirePassword)

                if settings.requirePassword {
                    SecureField(locMgr.getString("PasswordPlaceholder"),
                                text: $settings.password)
                        .textFieldStyle(.roundedBorder)

                    if settings.password.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(locMgr.getString("PasswordErrorText"))
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 360)
        .onAppear(perform: startServer)
        // Refresh URL label & window title when language changes.
        .onChange(of: locMgr.currentLanguage) { _, _ in
            updateEndpointLabel()
        }
    }

    // MARK: - Helpers

    private func startServer() {
        guard !serverStarted else { return }
        serverStarted = true

        // Generate a unique token for this session.
        settings.token = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        do {
            try appDelegate.receiver.start(settings: settings) { savedPath in
                DispatchQueue.main.async {
                    onPhotoSaved(savedPath)
                }
            }
        } catch {
            serverError = "Server error: \(error.localizedDescription)"
            return
        }

        updateEndpointLabel()
    }

    private func updateEndpointLabel() {
        let ip  = getLanIPv4() ?? "LAN-IP"
        let url = "http://\(ip):\(settings.port)/push-photo?token=\(settings.token)"
        endpointUrl = url
    }

    private func onPhotoSaved(_ savedPath: String) {
        // Show a floating thumbnail popup.
        if settings.autoPopup {
            appDelegate.showPopup(for: savedPath)
        }

        // Optionally copy to the pasteboard.
        if settings.autoCopyToClipboard {
            ClipboardHelper.copyImageFileToPasteboard(savedPath)
        }

        // Fire a native macOS notification.
        appDelegate.statusBar?.showNotification(
            title: LocalizationManager.shared.getString("NotificationTitle"),
            body:  LocalizationManager.shared.getString("NewPhotoNotificationBody")
        )
    }

    // MARK: - Network utilities

    /// Returns the first active, non-loopback IPv4 address on this machine.
    /// Used to build the endpoint URL shown to the user.
    private func getLanIPv4() -> String? {
        // `Host.current().addresses` returns all addresses for the local host.
        // Pick the first IPv4 address that isn't the loopback address.
        return Host.current().addresses.first { addr in
            !addr.hasPrefix("127.") && !addr.contains(":")
        }
    }
}
