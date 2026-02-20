// PhotoPopupReceiverMacApp.swift
import SwiftUI

/// Application entry point for the macOS PhotoPopupReceiver.
///
/// Wires together the shared ``AppSettings``, ``LocalizationManager``, and
/// ``AppDelegate`` and presents the single main ``ContentView`` window.
@main
struct PhotoPopupReceiverMacApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var settings = AppSettings()
    @StateObject private var locMgr   = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(locMgr)
                .environmentObject(appDelegate)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Remove the "New Window" command – the app is single-window.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
