// StatusBarManager.swift
import AppKit
import UserNotifications

/// Manages the macOS menu-bar status item and system notifications.
/// Mirrors the Windows ``TrayIconService`` class.
final class StatusBarManager {

    private var statusItem: NSStatusItem?
    var onOpen: (() -> Void)?
    var onQuit: (() -> Void)?

    init(onOpen: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onQuit = onQuit

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle",
                                   accessibilityDescription: "PhotoPopupReceiver")
            button.image?.isTemplate = true
        }

        let loc = LocalizationManager.shared
        let menu = NSMenu()

        let openItem = NSMenuItem(title: loc.getString("StatusBarOpen"),
                                   action: #selector(openAction),
                                   keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: loc.getString("StatusBarQuit"),
                                   action: #selector(quitAction),
                                   keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Request permission to show notifications.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Actions

    @objc private func openAction() { onOpen?() }
    @objc private func quitAction() { onQuit?() }

    // MARK: - Notifications

    /// Shows a macOS ``UserNotification`` with the given title and body.
    func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content,
                                             trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
