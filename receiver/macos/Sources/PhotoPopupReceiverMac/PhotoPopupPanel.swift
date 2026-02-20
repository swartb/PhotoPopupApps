// PhotoPopupPanel.swift
import AppKit
import SwiftUI

/// A borderless, always-on-top floating ``NSPanel`` that displays a received
/// photo thumbnail in the bottom-right corner of the primary screen.
///
/// Mirrors the Windows ``PhotoPopupWindow`` (borderless WPF window) but uses
/// ``NSPanel`` with ``NSHostingView`` so the content is a native SwiftUI view.
final class PhotoPopupPanel: NSPanel {

    private var currentPath: String?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isReleasedWhenClosed = false
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // MARK: - Public API

    /// Loads the image at ``path``, updates the content view and makes the
    /// panel visible.  Also positions the panel in the bottom-right corner.
    func showPhoto(at path: String) {
        currentPath = path

        let view = PhotoPopupContentView(imagePath: path) { [weak self] in
            // Copy button
            guard let self, let p = self.currentPath else { return }
            ClipboardHelper.copyImageFileToPasteboard(p)
        } onClose: { [weak self] in
            self?.orderOut(nil)
        }

        contentView = NSHostingView(rootView: view)
        positionBottomRight()
        orderFront(nil)
    }

    // MARK: - Positioning

    /// Moves the panel to the bottom-right corner of the primary screen's
    /// visible working area, leaving a 16-pt margin from the edges.
    func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let workArea: NSRect = screen.visibleFrame
        let margin: CGFloat = 16
        let origin = NSPoint(x: workArea.maxX - frame.width - margin,
                             y: workArea.minY + margin)
        setFrameOrigin(origin)
    }
}

// MARK: - SwiftUI content view

/// The SwiftUI content rendered inside ``PhotoPopupPanel``.
/// Displays a rounded dark card with the photo thumbnail and Copy / Close buttons.
private struct PhotoPopupContentView: View {

    let imagePath: String
    var onCopy:  () -> Void
    var onClose: () -> Void

    @State private var image: NSImage?

    private let loc = LocalizationManager.shared

    var body: some View {
        ZStack {
            // Dark rounded background card (matches the Windows #EE1E1E1E style).
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.93))

            VStack(spacing: 0) {
                // Photo preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black)

                    if let img = image {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 336, height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
                .frame(width: 336, height: 200)
                .padding(.top, 12)
                .padding(.horizontal, 12)

                // Action buttons
                HStack {
                    Spacer()
                    Button(loc.getString("CopyButton"))  { onCopy()  }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .foregroundStyle(.white)
                    Button(loc.getString("CloseButton")) { onClose() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 360, height: 260)
        .onAppear { loadImage() }
    }

    private func loadImage() {
        // Load fully into memory so the source file is not locked.
        guard let img = NSImage(contentsOfFile: imagePath) else { return }
        image = img
    }
}
