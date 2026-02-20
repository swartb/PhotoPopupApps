// LocalizationManager.swift
import Foundation

/// Provides application-wide localization, allowing the UI language to be
/// switched at runtime between English (``en``) and Dutch (``nl``).
/// String resources are read from ``Localizable.strings`` files in the
/// ``en.lproj`` and ``nl.lproj`` resource directories.
/// This mirrors the Windows ``PhotoPopupReceiver.LocalizationManager`` class.
final class LocalizationManager: ObservableObject {

    /// Shared singleton instance.
    static let shared = LocalizationManager()

    /// The currently active two-letter ISO language code (``"en"`` or ``"nl"``).
    @Published private(set) var currentLanguage: String

    private init() {
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        currentLanguage = (systemLang == "nl") ? "nl" : "en"
    }

    /// Switches the active language.
    /// Only ``"en"`` and ``"nl"`` are supported; other codes are silently ignored.
    func setLanguage(_ code: String) {
        guard code == "en" || code == "nl" else { return }
        currentLanguage = code
    }

    /// Returns the localized string for ``key`` in the current language.
    /// Falls back to ``key`` itself when the resource is not found.
    func getString(_ key: String) -> String {
        // Look up the lproj bundle for the active language.
        if let path = Bundle.module.path(forResource: currentLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
            if value != key { return value }
        }
        // Fallback: check the module bundle directly.
        return Bundle.module.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
