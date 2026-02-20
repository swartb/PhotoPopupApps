# PhotoPopupReceiver — macOS

A native macOS receiver app with feature parity to the Windows WPF version located in
`receiver/windows/`.

## Features

| Feature | Implementation |
|---|---|
| HTTP listener | Apple Network.framework `NWListener` on a configurable port (default **5055**) |
| Authentication | Query-parameter token + optional `X-Auth` / `X-Auth-Token` password header |
| File storage | `~/Pictures/PhotoPopups/<yyyy-MM-dd>/` (created automatically) |
| Floating popup | Borderless `NSPanel` positioned at the bottom-right of the primary screen |
| Auto-clipboard | `NSPasteboard` copy on photo receipt (optional toggle) |
| Notifications | `UserNotifications` framework |
| Menu-bar icon | `NSStatusItem` with Open / Quit menu |
| Localisation | English (default) and Dutch; runtime-switchable via the language picker |

## Requirements

* macOS 13 Ventura or later
* Xcode 15 or later (for building)

## Building

### Option A — Open in Xcode (recommended)

```
open receiver/macos/Package.swift
```

Xcode will open the Swift Package.  Select the `PhotoPopupReceiverMac` scheme and
choose **Product → Run** (⌘R).

### Option B — Command line

```bash
cd receiver/macos
swift build -c release
```

The compiled binary will be at
`.build/release/PhotoPopupReceiverMac`.

> **Note:** Running the binary directly with `swift run` or from the command line
> means the app has no proper bundle and therefore no sandbox entitlements.
> For a distributable `.app` bundle, build via Xcode and archive the target.

## Sandbox entitlements

When shipping the app through the Mac App Store or with Hardened Runtime enabled,
add the following entitlements to the Xcode target:

```xml
<!-- Required to listen on a TCP port -->
<key>com.apple.security.network.server</key>
<true/>

<!-- Required to display UserNotifications -->
<key>com.apple.security.network.client</key>
<true/>
```

For **Keychain** storage of the session token / password (see
[problem statement](../../../../README.md) requirement 6), replace the in-memory
`AppSettings.token` / `AppSettings.password` properties with
`SecItemAdd` / `SecItemCopyMatching` calls and add:

```xml
<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.yourorg.PhotoPopupReceiverMac</string>
</array>
```

## Architecture overview

```
PhotoPopupReceiverMacApp   ← @main entry point; creates the SwiftUI scene
  └─ ContentView           ← main settings window (SwiftUI)
       ├─ AppSettings       ← ObservableObject: port, token, password, options
       ├─ LocalizationManager ← en/nl runtime switching
       ├─ PhotoReceiver     ← NWListener HTTP server; calls onPhotoSaved callback
       └─ AppDelegate       ← NSApplicationDelegate; owns StatusBarManager, PhotoPopupPanel
       │    ├─ StatusBarManager  ← NSStatusItem + UNUserNotificationCenter
       │    └─ PhotoPopupPanel   ← borderless NSPanel with SwiftUI content view
```

## Relationship to the Windows version

| Windows class | macOS equivalent |
|---|---|
| `PhotoReceiver.cs` (Kestrel / ASP.NET Core) | `PhotoReceiver.swift` (NWListener) |
| `AppSettings.cs` | `AppSettings.swift` |
| `MainWindow.xaml/.cs` | `ContentView.swift` |
| `PhotoPopupWindow.xaml/.cs` | `PhotoPopupPanel.swift` |
| `TrayIconService.cs` | `StatusBarManager.swift` |
| `ClipboardHelper.cs` | `ClipboardHelper.swift` |
| `LocalizationManager.cs` | `LocalizationManager.swift` |
| `Strings.resx` / `Strings.nl.resx` | `en.lproj/Localizable.strings` / `nl.lproj/Localizable.strings` |
