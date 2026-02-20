// AppSettings.swift
import Foundation

/// Holds all user-configurable settings for the application.
/// An instance of this class is created at startup and shared between the UI and the
/// HTTP listener, mirroring the Windows ``PhotoPopupReceiver.AppSettings`` class.
final class AppSettings: ObservableObject {

    /// TCP port on which the HTTP server listens for incoming photo uploads.
    /// Must be a free port on the host machine. Default: 5055.
    @Published var port: Int = 5055

    /// Shared secret the sender must supply as the ``token`` query parameter to
    /// authenticate upload requests.  A new random UUID token is generated each
    /// session so each run has a unique, unguessable token.
    @Published var token: String = "changeme"

    /// When ``true`` a floating popup panel is shown in the bottom-right corner
    /// of the screen whenever a new photo is received.
    @Published var autoPopup: Bool = true

    /// When ``true`` each received photo is automatically placed on the macOS
    /// pasteboard (clipboard) immediately after it is saved.
    @Published var autoCopyToClipboard: Bool = false

    /// When ``true`` the sender must also supply the correct password in the
    /// ``X-Auth`` or ``X-Auth-Token`` HTTP header.
    @Published var requirePassword: Bool = true

    /// The password the sender must provide when ``requirePassword`` is ``true``.
    @Published var password: String = ""

    /// Local directory where received photo files are saved.
    /// Defaults to ``~/Pictures/PhotoPopups``.  The directory is created
    /// automatically by ``PhotoReceiver`` if it does not already exist.
    var saveFolder: String {
        let pictures = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)
            .first!
        return pictures.appendingPathComponent("PhotoPopups").path
    }
}
