# WhatsApp Web Dock for macOS

A native macOS dock and multi-account wrapper for [WhatsApp Web](https://web.whatsapp.com) built using Swift, SwiftUI, and WebKit (`WKWebView`).

---

## Features

- **Multi-Account Support**: Add and manage multiple WhatsApp accounts with customizable sidebar icons and colors.
- **Legitimate WebKit Identity**: Operates using a clean, native `WKWebView` identity configured with standard Safari release compatibility tokens (`Safari/605.1.15`), ensuring seamless compatibility with WhatsApp Web.
- **Native macOS Notifications**: Intercepts web notification requests and delivers them through native macOS system notifications using the `UserNotifications` framework.
- **File Downloads & Attachments**:
  - Intercepts file/blob downloads and presents native `NSSavePanel` dialogs.
  - Native file attachment picker support via `NSOpenPanel`.
  - Full drag-and-drop file sharing into chats.
- **Intelligent Upsell Suppression**: Suppresses intrusive "Get WhatsApp for Mac" desktop download banners while preserving chat layout, popovers, and drag-and-drop targets.
- **Session & Data Persistence**: Isolated website data stores (`WKWebsiteDataStore`) per account for persistent login sessions.

---

## Technical Details

| Component | Specification |
| :--- | :--- |
| **Language & Frameworks** | Swift, SwiftUI, WebKit, AppKit |
| **Minimum Deployment Target** | macOS 14.0+ (Tested up to macOS 26.1 SDK) |
| **Target URL** | `https://web.whatsapp.com` |
| **Entitlements** | Audio Input, Camera, User-Selected File Read/Write |

---

## Building and Running

### Prerequisites

- Xcode 15.0 or later running on macOS 14.0+
- macOS Command Line Tools (`xcodebuild`)

### Build via Command Line

To compile the debug build:

```bash
xcodebuild -project WhatsApp.xcodeproj -scheme WhatsApp -configuration Debug build
```

To create a release archive:

```bash
xcodebuild archive -project WhatsApp.xcodeproj -scheme WhatsApp -archivePath build/WhatsApp.xcarchive
```

### Packaging

To package the compiled `.app` bundle into a zip archive for distribution:

```bash
cd build/WhatsApp.xcarchive/Products/Applications
zip -r -y ../../../WhatsApp.zip WhatsApp.app
```

---

## Project Structure

```
WhatsApp/
├── WhatsApp/
├── WhatsAppApp.swift       # SwiftUI App entry point
├── ContentView.swift         # Sidebar & account management UI
├── WhatsAppWebView.swift     # WKWebView wrapper, delegates, JS injection & User-Agent config
├── Models.swift              # Account store & persistence models
└── WhatsApp.entitlements    # Sandbox security permissions
├── WhatsApp.xcodeproj/       # Xcode project configuration
├── build/                    # Output release archives (.xcarchive)
└── WhatsApp.zip              # Packaged macOS application bundle
```

---

## License

This project is open-source and intended for personal multi-account management.
