// QRCodeGenerator.swift
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Generates a QR-code image from a plain-text string using CoreImage.
/// This replaces the Windows dependency on the third-party ``QRCoder`` NuGet package.
enum QRCodeGenerator {

    /// Returns an ``NSImage`` containing a QR code that encodes ``text``.
    /// Error-correction level Q is used (recovers ≈25 % of data when damaged),
    /// matching the Windows implementation.
    /// Returns ``nil`` when CoreImage fails to produce output.
    static func makeQRImage(from text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "Q"

        guard let output = filter.outputImage else { return nil }

        // Scale the raw 1-pt-per-module image to a comfortable viewing size.
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = output.transformed(by: scale)

        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
