// AppDelegate.swift
import AppKit
import SwiftUI

/// ``NSApplicationDelegate`` that manages the application lifecycle, the
/// menu-bar status item, and the floating photo-popup panel.
///
/// It is registered via ``@NSApplicationDelegateAdaptor`` in
/// ``PhotoPopupReceiverMacApp``.
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // MARK: - Shared services

    let receiver   = PhotoReceiver()
    var statusBar: StatusBarManager?
    private var popupPanel: PhotoPopupPanel?

    // Keeps a reference to the main app window so it can be shown from the tray.
    var mainWindow: NSWindow?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = NSApp.windows.first

        statusBar = StatusBarManager(
            onOpen: { [weak self] in self?.showMainWindow() },
            onQuit: { [weak self] in self?.quit() }
        )

        // Ensure the app does not appear in the Dock while running as a
        // background/menu-bar app.  Comment this line out if you prefer a
        // Dock-visible app.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    // Prevent the app from quitting when the last window is closed; it should
    // continue running in the menu bar instead.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Window management

    /// Brings the main settings window to the front.
    func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Popup management

    /// Shows (or replaces) the floating photo-popup panel for the file at ``path``.
    func showPopup(for path: String) {
        if popupPanel == nil {
            popupPanel = PhotoPopupPanel()
        }
        popupPanel?.showPhoto(at: path)
    }

    // MARK: - Quit

    private func quit() {
        receiver.stop()
        NSApp.terminate(nil)
    }
}
