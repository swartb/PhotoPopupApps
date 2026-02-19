using System;
using System.Windows;
using System.Windows.Forms;

namespace PhotoPopupReceiver
{
    public class TrayIconService : IDisposable
    {
        private readonly NotifyIcon _notifyIcon;

        public TrayIconService(Action onOpen, Action onQuit)
        {
            _notifyIcon = new NotifyIcon
            {
                Text = "PhotoPopupReceiver",
                Icon = System.Drawing.SystemIcons.Application, // later vervangen door jouw icoon
                Visible = true
            };

            _notifyIcon.DoubleClick += (_, __) => onOpen();

            var menu = new ContextMenuStrip();
            menu.Items.Add("Open", null, (_, __) => onOpen());
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Quit", null, (_, __) => onQuit());

            _notifyIcon.ContextMenuStrip = menu;
        }

        public void ShowBalloon(string title, string message)
        {
            _notifyIcon.BalloonTipTitle = title;
            _notifyIcon.BalloonTipText = message;
            _notifyIcon.ShowBalloonTip(1500);
        }

        public void Dispose()
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }
    }
}
