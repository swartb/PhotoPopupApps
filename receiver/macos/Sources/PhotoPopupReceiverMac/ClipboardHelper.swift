// ClipboardHelper.swift
import AppKit

/// Utility helpers for interacting with the macOS pasteboard.
/// Mirrors the Windows ``PhotoPopupReceiver.ClipboardHelper`` class.
enum ClipboardHelper {

    /// Copies the image at ``filePath`` onto the general pasteboard so the user
    /// can immediately paste it into another application.
    ///
    /// The image is loaded fully into memory before being placed on the
    /// pasteboard so that no file lock is held on the source file afterwards.
    /// Returns silently without throwing when the file does not exist.
    static func copyImageFileToPasteboard(_ filePath: String) {
        guard FileManager.default.fileExists(atPath: filePath),
              let image = NSImage(contentsOfFile: filePath)
        else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
}
