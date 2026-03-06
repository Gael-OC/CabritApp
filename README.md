<h1 align="center">
  🎬 IPTV Player for macOS
</h1>

<p align="center">
  A native macOS IPTV player built with SwiftUI and AVKit.<br>
  Connect to any Xtream Codes-compatible server and enjoy live TV, movies, and series.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange?style=flat-square" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
</p>

---

## ✨ Features

- 🔐 **Xtream Codes Login** — Connect with server URL, username, and password
- 📺 **Live TV, Movies & Series** — Browse all categories with a clean sidebar
- 🎨 **Apple TV-inspired UI** — Dark theme, poster cards, hero banners, smooth animations
- ▶️ **Native AVPlayer** — Full macOS player with PiP, fullscreen, and keyboard shortcuts (← → to skip 10s)
- 📌 **Continue Watching** — Automatically saves and resumes your position (saves every 5 seconds)
- ⭐ **Favorites** — Save your preferred channels and movies
- 🔍 **Smart Search** — Diacritic-insensitive, deduplicated results
- 📁 **Custom Categories** — Group and organize server categories your way
- 🏷️ **Quality Filters** — Filter by 4K, FHD, HD, SD, language, and more
- 🖥️ **Screen Sleep Prevention** — Screen stays on during playback
- 💾 **Credential Storage** — Optional "remember me" for quick login

## 📋 Requirements

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+**
- No external dependencies — 100% native Swift/SwiftUI

## 🚀 How to Build

1. Clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/iptv-player-macos.git
   ```

2. Open in Xcode:
   ```bash
   cd iptv-player-macos
   open "IPTV probar inicio.xcodeproj"
   ```

3. Select **"My Mac"** as the build target

4. Press **⌘R** to build and run

> **Note:** The app uses App Sandbox with only outgoing network connections enabled. No server-side components needed.

## 📦 Releases

Check the [Releases](../../releases) page for pre-built versions. To create your own release:

1. In Xcode: **Product → Archive**
2. In the Organizer, click **"Distribute App" → Copy App**
3. Zip the `.app` file and upload it as a GitHub Release

> **Important:** Without an Apple Developer certificate, macOS will show a warning when opening the app. Users can bypass it with **right-click → Open**, or via **System Settings → Privacy & Security → Open Anyway**.

## 🏗️ Project Structure

```
IPTV probar inicio/
├── IPTV_probar_inicioApp.swift   # App entry point & window config
├── Models.swift                   # Data models (MediaItem, Session, etc.)
├── AppViewModel.swift             # Main ViewModel — all business logic
├── XtreamService.swift            # Xtream Codes API client
├── Persistence.swift              # UserDefaults stores (history, favorites, etc.)
├── LoginView.swift                # Login screen
├── ContentView.swift              # Root navigation (login vs dashboard)
├── DashboardView.swift            # Main UI — sidebar, hero, carousels
├── PlayerView.swift               # AVPlayer wrapper with PiP & shortcuts
├── CarouselSectionView.swift      # Horizontal carousel component
├── ContentDetailView.swift        # Movie/series detail sheet
├── CategoryManagerView.swift      # Category organization UI
├── CachedAsyncImage.swift         # Image loader with disk cache
├── Info.plist                     # App Transport Security config
├── PrivacyInfo.xcprivacy          # Apple Privacy Manifest
└── IPTV probar inicio.entitlements # Sandbox & network permissions
```

## ⚠️ Legal Disclaimer

> **This application is a generic media player.** It does not include, provide, host, or distribute any media content, IPTV playlists, channel lists, or streaming URLs.
>
> The user is solely responsible for the content they access using this application. The developers assume no responsibility for how the application is used or for any content accessed through it.
>
> **This software is provided "as is", without warranty of any kind.** Use at your own risk. The developers are not affiliated with any IPTV service provider.

## 🤝 Contributing

Contributions are welcome! Feel free to:
- 🐛 Report bugs via [Issues](../../issues)
- 💡 Suggest features
- 🔧 Submit pull requests

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
