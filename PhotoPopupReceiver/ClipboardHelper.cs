using System;
using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;

namespace PhotoPopupReceiver
{
    /// <summary>
    /// Provides utility methods for interacting with the Windows clipboard in the context
    /// of image files received by the application.
    /// </summary>
    public static class ClipboardHelper
    {
        /// <summary>
        /// Copies the image located at <paramref name="filePath"/> onto the Windows clipboard,
        /// making it immediately available for pasting into other applications.
        /// </summary>
        /// <param name="filePath">The full path to the image file to copy.</param>
        /// <remarks>
        /// <para>
        /// The image is fully loaded into memory before being placed on the clipboard
        /// (<see cref="BitmapCacheOption.OnLoad"/>) so that no file lock is held on the
        /// source file after the operation completes.
        /// </para>
        /// <para>
        /// The <see cref="BitmapImage"/> is frozen after loading, which makes it
        /// thread-safe and eligible for cross-thread access.
        /// </para>
        /// <para>
        /// The method returns silently without throwing if the specified file does not exist.
        /// </para>
        /// </remarks>
        public static void CopyImageFileToClipboard(string filePath)
        {
            // Do nothing if the file has already been deleted or was never written.
            if (!File.Exists(filePath))
                return;

            var bmp = new BitmapImage();
            bmp.BeginInit();
            // Load the full image data into memory immediately so the source file is not
            // kept locked after EndInit() returns.
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.UriSource = new Uri(Path.GetFullPath(filePath));
            bmp.EndInit();
            // Freeze the bitmap so it can be safely accessed from any thread.
            bmp.Freeze();

            System.Windows.Clipboard.SetImage(bmp);
        }
    }
}
