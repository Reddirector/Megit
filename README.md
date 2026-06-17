<div align="center">
  <img src="assets/logo.png" alt="Megit Logo" width="140" />

  <h1>Megit</h1>
  <p><strong>A premium music streaming experience — powered by YouTube Music, built with Flutter.</strong></p>

  <p>
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
    <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
    <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"/>
    <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Platform"/>
    <img src="https://img.shields.io/badge/License-MIT-9B59B6?style=for-the-badge" alt="License"/>
  </p>

  <p>
    <a href="#-features">Features</a> •
    <a href="#️-tech-stack">Tech Stack</a> •
    <a href="#-screenshots--demo">Screenshots</a> •
    <a href="#-getting-started">Getting Started</a> •
    <a href="#-contributing">Contributing</a>
  </p>
</div>

---

## 📖 About

**Megit** is a fully-featured, cloud-connected music streaming app built with Flutter. It taps directly into the YouTube Music library — no proxies, no slowdowns — wrapped in a stunning glassmorphic dark UI designed for OLED screens. Think of it as your personal music companion: offline downloads, smart radio queues, Spotify playlist imports, cross-device sync, and wrapped-style listening stats, all in one place.

> Forked and massively redesigned from the open-source [Pulse](https://github.com/BrightDV/BlackHole) codebase, with a completely new design language, architecture overhaul, and original feature additions.

---

## ✨ Features

### 🎨 Visual Experience & UI/UX

- **Glassmorphic Design** — Frosted panels, blurred backgrounds, and layered depth across every screen.
- **Custom Accent System** — Pick any primary color; buttons, sliders, progress bars, and glows update dynamically across the entire app.
- **Animated Halo Backgrounds** — Fluid gradient halos animate behind the Login and Player screens for a living, breathing atmosphere.
- **OLED-Optimized Dark Mode** — Pure deep blacks for maximum contrast and battery savings on OLED panels.
- **"Whale" Animated Backgrounds** — Subtle motion backgrounds on key screens.

---

### 🔍 Core Music Discovery

- **Direct YouTube Music Integration** — Access the world's largest music catalog without a middleman proxy.
- **Smart Search** — Instant suggestions as you type, with categorized results for Songs, Artists, Albums, and Playlists.
- **Dynamic Home Feed** — Personalized sections like *Trending Now*, *Global Top Songs*, and *Bollywood Hits*, automatically refreshed even when logged out.
- **Artist Pages** — Dedicated discography views with top songs, albums, singles, and subscriber counts.

---

### 🎛️ Advanced Playback

| Feature | Details |
|---|---|
| 🔊 **Professional Audio Engine** | Built on `just_audio` + `audio_service` for high-fidelity output |
| 🌊 **Crossfade Engine** | Smooth, configurable transitions (up to 12 seconds) between tracks |
| ⏯️ **Gapless Playback** | Zero-interruption continuous listening |
| 📻 **Intelligent Radio Queue** | "Start Radio" generates an infinite stream of similar music from any song |
| 🔁 **Queue Management** | Full drag-to-reorder and swipe-to-remove controls |
| 🔒 **Background Playback** | Lock screen controls and notification bar integration |
| 🎤 **Lyrics System** | In-sync lyrics with local caching for instant repeat playback |

---

### 📚 Playlist & Library Management

- **Cloud-Synced Playlists** — All Megit Playlists stored in Firebase Firestore, available on every device instantly.
- **Offline Playlist Backup** — Even offline playlists are cloud-backed. Reinstall the app and everything restores automatically.
- **Spotify Import** — Paste any Spotify playlist URL; Megit matches every track to a high-quality YouTube Music equivalent.
- **YouTube Music Import** — Direct import of any public YTM playlist or album.
- **Flexible Library** — Toggle Grid / List views with sorting by Alphabetical or Recently Added.

---

### 📥 Downloads & Offline Mode

- **Persistent Storage** — Save downloads to a public folder (`/Downloads/Megit`) that survives app reinstalls.
- **Quality Control** — Separate streaming and download quality settings (Low / Normal / High).
- **Local Metadata Database** — Optimized SQLite (`sqflite`) database for instant offline access with full track info, artwork, and folder paths.

---

### 👤 User Authentication & Profile

- **Dual-Auth System** — Email/Password and Google Sign-In both supported.
- **Profile Personalization** — Custom display names and avatars synced via Firestore.
- **Multi-Device Settings Sync** — Accent color, crossfade duration, and UI preferences follow you across all your devices.

---

### 📊 Listening Statistics (Megit Wrapped)

- **Real-Time Tracking** — Megit logs every second of playback for accurate insights.
- **Timeframe Filtering** — View stats for Today, This Week, Month, Year, or All Time.
- **Top 10 Songs** — Ranked by play count and total listening time.
- **Top 10 Artists** — Auto-enriched with high-res artist images and browse links.
- **Daily Averages** — See exactly how much music you consume each day.

---

## 🖼️ Screenshots & Demo

<div align="center">

<!-- 
  📸 Add screenshots to docs/screenshots/ in this repo.
  You can drag-and-drop MP4 screen recordings directly into a GitHub Issue 
  to get a hosted URL, then reference it here as:
  <video src="YOUR_URL" controls width="300"></video>
  
  Or convert to GIF for inline playback.
-->

| Home Feed | Now Playing | Library |
|:---:|:---:|:---:|
| *Coming soon* | *Coming soon* | *Coming soon* |

| Search | Megit Wrapped | Downloads |
|:---:|:---:|:---:|
| *Coming soon* | *Coming soon* | *Coming soon* |

</div>

> 💡 **To add your demo videos:** Go to any GitHub Issue in this repo → drag and drop the `.mp4` files → copy the hosted URL → paste it above using `<video src="URL" controls width="300"></video>`.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **State Management** | Riverpod (reactive, provider-based) |
| **Navigation** | GoRouter (deep linking + nested routes) |
| **Audio Engine** | `just_audio` + `audio_service` |
| **Backend** | Firebase Auth, Firestore, Analytics |
| **Network** | Dio with custom interceptors |
| **Local Storage** | SQLite via `sqflite` |
| **Music Source** | YouTube Music API (direct, no proxy) |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `3.x` → [Install Flutter](https://docs.flutter.dev/get-started/install)
- Android Studio or VS Code with Flutter & Dart extensions
- An Android device or emulator (API 21+)
- A Firebase project with Auth and Firestore enabled

### Installation

```bash
# 1. Clone the repo
git clone https://github.com/Reddirector/Megit.git

# 2. Navigate into the project
cd Megit

# 3. Install Flutter dependencies
flutter pub get

# 4. Add your Firebase config file
#    Download google-services.json from your Firebase console
#    and place it at: android/app/google-services.json

# 5. Run on your device or emulator
flutter run
```

> **Note:** You'll need to set up your own Firebase project and add the `google-services.json` before the app will compile. See the [Firebase setup guide](https://firebase.google.com/docs/flutter/setup).

### Building a Release APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📁 Project Structure

```
Megit/
├── lib/
│   ├── core/           # App-wide constants, themes, and utilities
│   ├── features/       # Feature modules (auth, player, library, search…)
│   ├── providers/      # Riverpod state providers
│   ├── services/       # Firebase, YTMusic API, Downloads, Auth services
│   └── main.dart       # Entry point + GoRouter setup
├── assets/
│   ├── logo.png
│   └── ...
├── android/
│   └── app/
│       └── google-services.json   ← add your Firebase config here
└── pubspec.yaml
```

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!

1. Fork the project
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

Please open an issue first to discuss major changes before submitting a PR.

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](./LICENSE) for more information.

---

<div align="center">
  <img src="assets/logo.png" alt="Megit" width="48" />
  <br/>
  <sub>Built with 💜 using Flutter &nbsp;|&nbsp; Designed by <a href="https://github.com/Reddirector">Reddirector</a></sub>
</div>
