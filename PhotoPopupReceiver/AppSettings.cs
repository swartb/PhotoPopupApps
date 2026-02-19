using System;
using System.IO;

namespace PhotoPopupReceiver
{
    /// <summary>
    /// Holds all user-configurable settings for the application.
    /// An instance of this class is created at startup and passed to the HTTP listener
    /// (<see cref="PhotoReceiver"/>) as well as consulted when a photo arrives.
    /// </summary>
    public class AppSettings
    {
        /// <summary>
        /// The TCP port on which the HTTP server listens for incoming photo upload requests.
        /// Must be a free port on the host machine. Default is <c>5055</c>.
        /// </summary>
        public int Port { get; set; } = 5055;

        /// <summary>
        /// A shared secret that the sender must supply as the <c>token</c> query parameter
        /// (e.g. <c>?token=abc123</c>) to authenticate upload requests.
        /// A new random GUID token is generated each time the application starts, so each
        /// session has a unique, unguessable token.
        /// The default value is a placeholder that is replaced at startup.
        /// </summary>
        public string Token { get; set; } = "changeme";

        /// <summary>
        /// When <see langword="true"/>, a floating popup notification window is automatically
        /// displayed in the bottom-right corner of the screen whenever a new photo is received.
        /// Set to <see langword="false"/> to receive photos silently without any visible popup.
        /// Default is <see langword="true"/>.
        /// </summary>
        public bool AutoPopup { get; set; } = true;

        /// <summary>
        /// When <see langword="true"/>, each received photo is automatically placed onto the
        /// Windows clipboard immediately after it is saved, so the user can paste it directly
        /// into another application without any extra steps.
        /// Default is <see langword="false"/>.
        /// </summary>
        public bool AutoCopyToClipboard { get; set; } = false;
        public bool RequirePassword { get; set; } = true;   // default veilig
        public string Password { get; set; } = "";

        /// <summary>
        /// The local directory where received photo files are saved.
        /// Defaults to a <c>PhotoPopups</c> sub-folder inside the current user's
        /// <em>My Pictures</em> folder (e.g. <c>C:\Users\&lt;name&gt;\Pictures\PhotoPopups</c>).
        /// The folder is created automatically if it does not yet exist.
        /// </summary>
        public string SaveFolder { get; set; } =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), "PhotoPopups");
    }
}
