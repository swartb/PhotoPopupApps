using System;
using System.Threading.Tasks;
using System.Windows;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using QRCoder;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Windows.Controls;
using System.Windows.Media.Imaging;

namespace PhotoPopupReceiver
{
    /// <summary>
    /// The application's primary window.
    /// Displays the listening endpoint URL, an optional QR code for easy mobile access,
    /// and a checkbox that controls whether received photos are automatically copied to
    /// the clipboard.  On startup it launches the HTTP listener via <see cref="PhotoReceiver"/>
    /// and wires up the callback that handles each received photo.
    /// A language ComboBox allows the user to switch the UI between English and Dutch at runtime.
    /// </summary>
    public partial class MainWindow : Window
    {
        // Application settings shared between the UI and the HTTP listener.
        private readonly AppSettings _settings = new();

        // The HTTP listener that accepts incoming photo upload requests.
        private readonly PhotoReceiver _receiver = new();

        // The currently open popup notification window, or null if none is shown.
        private PhotoPopupWindow? _popup;
        private TrayIconService? _tray;
        private bool _reallyClose = false;

        // The endpoint URL built at startup, stored separately so it can be
        // reformatted with a different language prefix when the language changes.
        private string _endpointUrl = string.Empty;

        /// <summary>
        /// Initializes the window, sets the correct language in the ComboBox, and once the
        /// window is fully loaded generates a session token, resolves the LAN IP address,
        /// and starts the HTTP listener.
        /// </summary>
        public MainWindow()
        {
            InitializeComponent();
            Closing += MainWindow_Closing;
            StateChanged += MainWindow_StateChanged;

            // Populate language ComboBox before applying localization.
            LanguageComboBox.Items.Add(new ComboBoxItem { Content = "English", Tag = "en" });
            LanguageComboBox.Items.Add(new ComboBoxItem { Content = "Nederlands", Tag = "nl" });

            // Pre-select the item that matches the current language without firing the handler.
            foreach (ComboBoxItem item in LanguageComboBox.Items)
            {
                if (item.Tag is string tag && tag == LocalizationManager.CurrentCulture.TwoLetterISOLanguageName)
                {
                    LanguageComboBox.SelectedItem = item;
                    break;
                }
            }

            // Apply initial localization to all named controls.
            ApplyLocalization();

            RequirePasswordCheckBox.IsChecked = _settings.RequirePassword;
            PasswordBox.Password = _settings.Password;
            ValidatePasswordUi();

            // Keep the UI in sync whenever the language is changed from elsewhere.
            LocalizationManager.LanguageChanged += (_, __) => Dispatcher.Invoke(ApplyLocalization);

            Loaded += async (_, __) =>
            {
                // Generate a unique token for this session to prevent unauthorised uploads.
                _settings.Token = Guid.NewGuid().ToString("N");

                // Build the full upload URL that the sender (e.g. a mobile app) must call.
                var ip = GetLanIPv4() ?? "LAN-IP";
                _endpointUrl = $"http://{ip}:{_settings.Port}/push-photo?token={_settings.Token}";

                // Show the port number in the title bar for quick reference.
                Title = string.Format(LocalizationManager.GetString("TitleBarListening"), _settings.Port);

                // Display the full URL in the read-only text box so the user can copy it.
                UrlText.Text = $"{LocalizationManager.GetString("EndpointLabel")}\n{_endpointUrl}";

                // Start the HTTP server; OnPhotoSavedAsync is called for every received photo.
                await _receiver.StartAsync(_settings, OnPhotoSavedAsync);
                
                _tray = new TrayIconService(
                    onOpen: () => Dispatcher.Invoke(ShowFromTray),
                    onQuit: () => Dispatcher.Invoke(QuitFromTray)
                );
            };
        }
        private void RequirePasswordChanged(object sender, RoutedEventArgs e)
        {
            _settings.RequirePassword = RequirePasswordCheckBox.IsChecked == true;
            ValidatePasswordUi();
        }

        private void PasswordChanged(object sender, RoutedEventArgs e)
        {
            _settings.Password = PasswordBox.Password;
            ValidatePasswordUi();
        }

        private void ValidatePasswordUi()
        {
            if (PasswordErrorText == null) return; // UI nog niet klaar

            bool needs = _settings.RequirePassword;
            bool ok = !needs || !string.IsNullOrWhiteSpace(_settings.Password);

            PasswordErrorText.Visibility = ok ? Visibility.Collapsed : Visibility.Visible;
        }
        private void MainWindow_StateChanged(object? sender, EventArgs e)
        {
            if (WindowState == WindowState.Minimized)
            {
                Hide();
                _tray?.ShowBalloon("PhotoPopupReceiver", "Draait nu in de tray.");
            }
        }

        private void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
        {
            if (_reallyClose) return;

            // standaard gedrag: naar tray i.p.v. echt afsluiten
            e.Cancel = true;
            Hide();
            _tray?.ShowBalloon("PhotoPopupReceiver", "Draait nu in de tray.");
        }

        private void ShowFromTray()
        {
            Show();
            WindowState = WindowState.Normal;
            Activate();
        }

        private void QuitFromTray()
        {
            _reallyClose = true;
            _tray?.Dispose();
            Close(); // triggert Closing event, maar we laten ‘m nu door
        }


        /// <summary>
        /// Refreshes all localised text in the window using the current culture from
        /// <see cref="LocalizationManager"/>.  Called once at startup and again whenever
        /// the user selects a different language.
        /// </summary>
        private void ApplyLocalization()
        {
            AppTitleText.Text = LocalizationManager.GetString("AppTitle");
            AutoCopyCheckBox.Content = LocalizationManager.GetString("AutoCopyCheckbox");
            ShowQrButton.Content = LocalizationManager.GetString("ShowQrButton");
            LanguageLabelText.Text = LocalizationManager.GetString("LanguageLabel");

            // Only update the URL text box if the URL has already been resolved.
            if (!string.IsNullOrEmpty(_endpointUrl))
            {
                UrlText.Text = $"{LocalizationManager.GetString("EndpointLabel")}\n{_endpointUrl}";
                Title = string.Format(LocalizationManager.GetString("TitleBarListening"), _settings.Port);
            }
        }

        /// <summary>
        /// Handles the language ComboBox selection change.
        /// Reads the <c>Tag</c> of the selected item (a two-letter ISO language code) and
        /// passes it to <see cref="LocalizationManager.SetLanguage"/>, which fires
        /// <see cref="LocalizationManager.LanguageChanged"/> so all subscribers update.
        /// </summary>
        private void LanguageComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (LanguageComboBox.SelectedItem is ComboBoxItem item && item.Tag is string languageCode)
                LocalizationManager.SetLanguage(languageCode);
        }

        /// <summary>
        /// Callback invoked by <see cref="PhotoReceiver"/> after a photo has been saved to disk.
        /// Depending on the current settings, shows a popup window and/or copies the image
        /// to the clipboard.
        /// </summary>
        /// <param name="savedPath">The full path to the file that was saved.</param>
        /// <returns>A completed <see cref="Task"/>.</returns>
        private Task OnPhotoSavedAsync(string savedPath)
        {
            // Show (or replace) the popup notification window in the bottom-right corner.
            if (_settings.AutoPopup)
            {
                Dispatcher.Invoke(() =>
                {
                    // Close the previous popup before opening a new one to avoid stacking.
                    _popup?.Close();
                    _popup = new PhotoPopupWindow();
                    _popup.SetImage(savedPath);
                    _popup.Show();
                    // Position after Show() so ActualWidth/ActualHeight are available.
                    _popup.Dispatcher.BeginInvoke(new Action(_popup.PositionBottomRight));
                });
            }

            // Optionally place the image on the clipboard for immediate use.
            if (_settings.AutoCopyToClipboard)
            {
                Dispatcher.Invoke(() =>
                {
                    ClipboardHelper.CopyImageFileToClipboard(savedPath);
                });
            }

            return Task.CompletedTask;
        }

        /// <summary>
        /// Returns the first active, non-loopback IPv4 address found on this machine,
        /// which is used to construct the endpoint URL that remote senders should call.
        /// Returns <see langword="null"/> if no suitable address is found.
        /// </summary>
        private static string? GetLanIPv4()
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                // Skip interfaces that are down or inactive.
                if (ni.OperationalStatus != OperationalStatus.Up) continue;
                // Skip the loopback adapter (127.0.0.1).
                if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;

                var ipProps = ni.GetIPProperties();
                var addr = ipProps.UnicastAddresses
                    .FirstOrDefault(a => a.Address.AddressFamily == AddressFamily.InterNetwork
                                      && !IPAddress.IsLoopback(a.Address));
                if (addr != null) return addr.Address.ToString();
            }
            return null;
        }

        /// <summary>
        /// Generates a WPF-compatible bitmap containing a QR code that encodes <paramref name="text"/>.
        /// The QR code uses error-correction level Q (recovers ~25 % of data if damaged).
        /// </summary>
        /// <param name="text">The text or URL to encode in the QR code.</param>
        /// <returns>A frozen <see cref="BitmapSource"/> ready to use as an image source.</returns>
        private BitmapSource MakeQrBitmap(string text)
        {
            // Use QRCoder to generate the QR code matrix.
            using var gen = new QRCodeGenerator();
            using var data = gen.CreateQrCode(text, QRCodeGenerator.ECCLevel.Q);
            using var code = new QRCode(data);
            // Render the QR code as a GDI+ Bitmap with 20 pixels per module.
            using Bitmap bmp = code.GetGraphic(20);

            // Convert the GDI+ Bitmap to a WPF BitmapSource via an in-memory PNG stream.
            using var ms = new MemoryStream();
            bmp.Save(ms, ImageFormat.Png);
            ms.Position = 0;

            var image = new BitmapImage();
            image.BeginInit();
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.StreamSource = ms;
            image.EndInit();
            // Freeze so the bitmap can be used safely across threads.
            image.Freeze();
            return image;
        }

        /// <summary>
        /// Handles the "Show QR" button click.
        /// Builds the current endpoint URL, generates a QR code for it, and toggles the
        /// visibility of the QR image control so the user can show or hide it.
        /// </summary>
        private void ShowQr_Click(object sender, RoutedEventArgs e)
        {
            // Re-derive the URL in case the network changed since startup.
            var ip = GetLanIPv4() ?? "LAN-IP";
            var url = $"http://{ip}:{_settings.Port}/push-photo?token={_settings.Token}";

            QrImage.Source = MakeQrBitmap(url);

            // Toggle between visible and collapsed to allow the user to hide the QR code.
            QrImage.Visibility = QrImage.Visibility == System.Windows.Visibility.Visible
                ? System.Windows.Visibility.Collapsed
                : System.Windows.Visibility.Visible;
        }

        /// <summary>
        /// Handles the AutoCopy checkbox being checked or unchecked.
        /// Synchronises the UI state with <see cref="AppSettings.AutoCopyToClipboard"/>.
        /// </summary>
        private void AutoCopyChanged(object sender, RoutedEventArgs e)
        {
            _settings.AutoCopyToClipboard = AutoCopyCheckBox.IsChecked == true;
        }

    }
}
