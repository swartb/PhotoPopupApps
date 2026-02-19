using System;
using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;

namespace PhotoPopupReceiver
{
    /// <summary>
    /// A borderless, always-on-top notification window that displays a received photo
    /// as a thumbnail in the bottom-right corner of the screen.
    /// The window provides two action buttons: one to copy the image to the clipboard
    /// and one to dismiss the popup.
    /// </summary>
    public partial class PhotoPopupWindow : Window
    {
        // The full file path of the photo currently shown in the popup.
        // Used by the Copy button handler to copy the correct file to the clipboard.
        private string? _currentPath;

        /// <summary>
        /// Initializes the window, applies the current localization, and subscribes to
        /// <see cref="LocalizationManager.LanguageChanged"/> so the button labels update
        /// automatically if the user switches language while the popup is open.
        /// The subscription is removed when the window closes to avoid memory leaks.
        /// </summary>
        public PhotoPopupWindow()
        {
            InitializeComponent();
            // PositionBottomRight relies on ActualWidth/ActualHeight, which are only
            // available after the first layout pass triggered by the Loaded event.
            Loaded += (_, __) => PositionBottomRight();

            // Apply button labels for the current language.
            ApplyLocalization();

            // Keep button labels in sync if the language is switched while the popup is open.
            LocalizationManager.LanguageChanged += OnLanguageChanged;
            Closed += (_, __) => LocalizationManager.LanguageChanged -= OnLanguageChanged;
        }

        // Handler that marshals the localization refresh onto the UI thread.
        private void OnLanguageChanged(object? sender, EventArgs e) =>
            Dispatcher.Invoke(ApplyLocalization);

        // Sets the Content of each button from the current resource strings.
        private void ApplyLocalization()
        {
            CopyButton.Content = LocalizationManager.GetString("CopyButton");
            CloseButton.Content = LocalizationManager.GetString("CloseButton");
        }

        /// <summary>
        /// Loads the image from <paramref name="path"/> and displays it in the preview control.
        /// </summary>
        /// <param name="path">The full path to the image file to display.</param>
        /// <remarks>
        /// <see cref="BitmapCacheOption.OnLoad"/> is used to read the entire image into
        /// memory immediately, which releases the file handle and prevents any file lock.
        /// The bitmap is frozen to make it thread-safe.
        /// </remarks>
        public void SetImage(string path)
        {
            // Remember the path so the Copy button can reference it later.
            _currentPath = path;

            var bmp = new BitmapImage();
            bmp.BeginInit();
            // Load fully into memory so the source file is not locked after EndInit().
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.UriSource = new Uri(Path.GetFullPath(path));
            bmp.EndInit();
            // Freeze to allow safe cross-thread access if needed.
            bmp.Freeze();

            PreviewImage.Source = bmp;
        }

        /// <summary>
        /// Moves the window to the bottom-right corner of the primary monitor's working area,
        /// leaving a small margin so it does not overlap the taskbar or screen edges.
        /// This method should be called after the window's layout has been measured
        /// (i.e. <see cref="FrameworkElement.ActualWidth"/> and
        /// <see cref="FrameworkElement.ActualHeight"/> have non-zero values).
        /// </summary>
        public void PositionBottomRight()
        {
            var wa = SystemParameters.WorkArea;
            const double margin = 16;
            Left = wa.Right - ActualWidth - margin;
            Top = wa.Bottom - ActualHeight - margin;
        }

        /// <summary>
        /// Handles the "Copy" button click.
        /// Copies the currently displayed photo to the Windows clipboard using
        /// <see cref="ClipboardHelper.CopyImageFileToClipboard"/>.
        /// </summary>
        private void Copy_Click(object sender, RoutedEventArgs e)
        {
            // Guard against the rare case where no image has been set yet.
            if (_currentPath is null) return;
            ClipboardHelper.CopyImageFileToClipboard(_currentPath);
        }

        /// <summary>
        /// Handles the "Close" button click. Dismisses the popup window.
        /// </summary>
        private void Close_Click(object sender, RoutedEventArgs e) => Close();
    }
}
