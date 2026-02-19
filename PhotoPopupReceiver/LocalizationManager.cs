using System;
using System.Globalization;
using System.Resources;

namespace PhotoPopupReceiver
{
    /// <summary>
    /// Provides application-wide localization support, allowing the UI language to be
    /// switched at runtime between English (<c>en</c>) and Dutch (<c>nl</c>).
    /// String resources are read from <c>Strings.resx</c> (English default) and the
    /// satellite assembly produced from <c>Strings.nl.resx</c> (Dutch).
    /// </summary>
    public static class LocalizationManager
    {
        private static readonly ResourceManager _resourceManager =
            new ResourceManager("PhotoPopupReceiver.Strings", typeof(LocalizationManager).Assembly);

        // Default to the system UI culture if it is English or Dutch; otherwise fall back to English.
        private static CultureInfo _currentCulture = DetectDefaultCulture();

        /// <summary>Raised after <see cref="SetLanguage"/> successfully changes the active culture.</summary>
        public static event EventHandler? LanguageChanged;

        /// <summary>Gets the currently active culture.</summary>
        public static CultureInfo CurrentCulture => _currentCulture;

        /// <summary>
        /// Switches the active language and fires <see cref="LanguageChanged"/> so that
        /// all subscribed UI components can refresh their text.
        /// Only <c>"en"</c> and <c>"nl"</c> are supported; unsupported codes are silently ignored.
        /// </summary>
        /// <param name="languageCode">A two-letter ISO language code, e.g. <c>"en"</c> or <c>"nl"</c>.</param>
        public static void SetLanguage(string languageCode)
        {
            if (languageCode != "en" && languageCode != "nl")
                return;

            _currentCulture = CultureInfo.GetCultureInfo(languageCode);
            LanguageChanged?.Invoke(null, EventArgs.Empty);
        }

        /// <summary>
        /// Returns the localized string identified by <paramref name="key"/> for the
        /// current culture.  Falls back to <paramref name="key"/> itself if the resource
        /// is not found.
        /// </summary>
        public static string GetString(string key) =>
            _resourceManager.GetString(key, _currentCulture) ?? key;

        // Returns Dutch when the system UI is Dutch, otherwise English.
        private static CultureInfo DetectDefaultCulture()
        {
            var twoLetter = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
            return twoLetter == "nl"
                ? CultureInfo.GetCultureInfo("nl")
                : CultureInfo.GetCultureInfo("en");
        }
    }
}
