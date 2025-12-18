<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9+-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
</p>

<h1 align="center">🎵 NowLyrics</h1>

<p align="center">
  <b>A modern desktop lyrics app for macOS, designed for Apple Music</b>
</p>

<p align="center">
  <a href="README_CN.md">🇨🇳 简体中文</a>
</p>

---

##  Features

-  **Auto Lyrics Fetching** - Automatically detects Apple Music playback and fetches matching lyrics
- ️ **Desktop Lyrics Display** - Floating transparent lyrics window, always on top
-  **Multiple Lyrics Sources** - Search from NetEase Music, QQ Music, and more
-  **Smart Caching** - Local lyrics cache for offline use
-  **Manual Selection** - Choose your preferred lyrics from search results



> Coming soon...

##  Requirements

- macOS 13.0 (Ventura) or later
- Apple Music app
- Automation permission (for Apple Music access)

##  Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/mahan/NowLyrics.git
cd NowLyrics

# Build with Swift Package Manager
swift build -c release

# Run the app
swift run NowLyrics
```

### Using Xcode

1. Open `NowLyrics.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

## Usage

1. **Launch NowLyrics** - The app runs in the menu bar
2. **Play Music** - Start playing a song in Apple Music
3. **Grant Permission** - Allow automation access when prompted
4. **Enjoy Lyrics** - Lyrics will automatically appear on your desktop

### Menu Bar Options

| Option | Description |
|--------|-------------|
| Show/Hide Desktop Lyrics | Toggle lyrics visibility |
| Select Lyrics | Choose from available lyrics |
| Offset +/- | Adjust lyrics timing |
| Search More | Search for additional lyrics |
| Preferences | App settings |
| Quit | Exit the application |

## Architecture

```
NowLyrics/
├── Sources/
│   ├── App/
│   │   └── AppDelegate.swift           # Application entry point
│   ├── Core/
│   │   ├── LyricsManager.swift         # Core lyrics orchestration
│   │   ├── LocalizationManager.swift   # i18n management
│   │   └── Logger.swift                # Unified logging system
│   ├── Models/
│   │   ├── Track.swift                 # Track data model
│   │   ├── Lyrics.swift                # Lyrics model + LRC parser
│   │   └── PlaybackState.swift         # Playback state model
│   ├── Services/
│   │   ├── AppleMusicService.swift     # Apple Music communication
│   │   ├── LyricsSearchService.swift   # Multi-source lyrics search
│   │   └── LyricsCacheService.swift    # Lyrics persistence
│   └── Views/
│       ├── DesktopLyricsWindow.swift   # Floating lyrics window
│       ├── LyricsSelectionViewController.swift
│       └── PreferencesViewController.swift
├── Resources/
│   ├── en.lproj/                       # English localization
│   └── zh-Hans.lproj/                  # Chinese localization
└── Package.swift
```

## Core Components

### AppleMusicService
Communicates with Apple Music via AppleScript to retrieve current track info and playback state. Uses Swift Actor for thread-safe state management.

### LyricsSearchService
Parallel search across multiple lyrics providers (NetEase, QQ Music) using Swift TaskGroup. Results are ranked by relevance score.

### LyricsCacheService
Manages local lyrics storage with LRC file persistence and user preference tracking.

### LyricsManager
Central orchestrator that:
- Monitors playback state changes
- Coordinates lyrics search and caching
- Calculates current lyrics line using binary search
- Broadcasts updates via AsyncStream


## Permissions

NowLyrics requires the following permissions:

- **Automation** - Access Apple Music to get playback information
- **Network** - Download lyrics from online sources

When first launched, macOS will prompt you to grant automation permission. You can also enable it in:
> System Settings → Privacy & Security → Automation → NowLyrics

##  Contributing

Contributions are welcome! Feel free to submit a Pull Request.

Have a feature request or found a bug? Please [open an issue](../../issues/new) — I'd love to hear your feedback!




##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Acknowledgments

- Inspired by [LyricsX](https://github.com/ddddxxx/LyricsX)
- Thanks to all lyrics providers

---

<p align="center">
  Made with ❤️ for music lovers
</p>
