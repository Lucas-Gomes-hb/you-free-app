# YouFree

> **Educational Project — Non-Commercial Use Only**
>
> This project was built exclusively for learning and study purposes. It must not be used for any commercial purpose, monetization, or profit of any kind. See the [License & Usage Terms](#license--usage-terms) section for details.

---

YouFree is an open-source Flutter application that streams audio and video from YouTube through a self-hosted backend API. It was built as a hands-on study project to explore Flutter architecture, state management, media playback, and API integration.

**Repository:** [github.com/Lucas-Gomes-hb/you-free-app](https://github.com/Lucas-Gomes-hb/you-free-app)

---

## Table of Contents

- [Features](#features)
  - [Playback](#playback)
  - [Search & Discovery](#search--discovery)
  - [Playlists](#playlists)
  - [Downloads](#downloads)
  - [UI & Design](#ui--design)
  - [Settings](#settings)
- [Architecture](#architecture)
  - [Project Structure](#project-structure)
  - [State Management](#state-management)
  - [Navigation](#navigation)
  - [Data Flow](#data-flow)
- [Tech Stack](#tech-stack)
- [Backend](#backend)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Running the App](#running-the-app)
- [Configuration](#configuration)
- [License & Usage Terms](#license--usage-terms)
- [Disclaimer](#disclaimer)

---

## Features

### Playback

YouFree offers a full-featured media player with both audio-only and video modes.

**Audio/Video Toggle**
The player can switch between streaming just the audio track (lower bandwidth) and full video mode at any time. When switching to video, playback resumes from the exact position it was at in audio mode, and vice versa. This is handled by `switchToAudioMode()` and `switchToVideoMode()` actions in `PlayerController`.

**Picture-in-Picture (PiP) — Android**
A dedicated button in the player triggers native Android Picture-in-Picture mode via a `MethodChannel`. The PiP state (play/pause) stays synchronized with the app even after the full player screen is dismissed, because the PiP logic lives at the app level (`_YouFreeAppState`) rather than inside the player screen itself.

**Queue & Autoplay**
After the current track finishes, YouFree automatically fetches suggested videos from the backend and queues them for seamless continuous playback (Radio Mode). You can also override the queue by navigating into a playlist or collection, which replaces the auto-queue with a specific sequence.

**Background Audio**
Audio keeps playing when the app is sent to the background or the screen turns off. A persistent notification is shown with playback controls (play/pause, skip), powered by `audio_service` and `just_audio`.

**Resume from Last Position**
For videos longer than 6 minutes, YouFree saves the last playback position. The next time you open that video, it resumes from where you left off.

**Playback Recovery**
If a stream URL becomes stale or fails mid-playback (common with YouTube CDN URLs), the player automatically retries by fetching a fresh stream URL from the backend.

**Stream URL Caching**
Resolved stream URLs are cached locally for up to 4 hours (YouTube CDN links typically expire after 6 hours). A maximum of 40 URLs are kept in memory at a time. This avoids unnecessary API calls when replaying recent tracks.

**Server-Side Cache Warming**
When a track starts playing, the app proactively requests the backend to pre-resolve the next 8 tracks in the queue. This reduces loading delays when skipping to the next song.

**Lyrics**
A toggle button inside the player loads lyrics for the current track — either plain text or synchronized/timed (LRC format). Lyrics are fetched on demand from the backend and are not pre-loaded.

---

### Search & Discovery

**Global Search**
The home screen includes a search bar that queries the backend with a 500ms debounce. Results are organized across three tabs: **Videos**, **Artists/Channels**, and **Albums/Playlists**.

**Autocomplete Suggestions**
As you type, suggestions appear below the search bar in real time (300ms debounce), making it faster to find what you are looking for.

**Infinite Scroll**
Search results support pagination. As you scroll to the bottom of the list, the next page of results is loaded automatically.

**Home Feed**
Before searching, the home screen shows a curated feed loaded from the backend, giving you content to browse immediately on launch.

**Collection Browsing**
Paste or share a YouTube channel URL or playlist URL into the app. YouFree detects whether it is a channel or a playlist, fetches its contents from the backend, and displays them as a browsable collection with the cover art used as an ambient background.

**Recently Played History**
The last 50 played tracks are stored locally and shown in a sidebar on the home screen for quick access.

---

### Playlists

YouFree supports fully local, offline playlists stored on the device using `SharedPreferences`.

- **Create** a new playlist from the Playlists tab using the floating action button.
- **Rename** or **delete** any playlist via a context menu.
- **Add tracks** to a playlist from the video card menu on the home or search screen.
- **Remove tracks** from a playlist inside its detail screen.
- **Play a playlist** as a continuous queue — the player loads the playlist's tracks in order and auto-advances through them.

Playlists are entirely local and are not synced to any server. Only the video IDs and metadata (title, thumbnail URL, duration) are stored on the device.

---

### Downloads

YouFree includes a built-in download manager that lets you save videos locally for offline playback.

- Trigger a download from the video card's overflow menu.
- A progress indicator shows the download percentage in real time.
- Downloaded files are stored in the app's private directory on the device.
- Download metadata (file path, video info) is persisted via `SharedPreferences` so the app remembers which files are available offline across restarts.

---

### UI & Design

**Dark Theme**
The app uses a fully dark color scheme with a near-black background (`#0A0A0A`), a red/orange primary accent (`#E8432A`), and a yellow secondary accent (`#F5C030`).

**Ambient Background**
On the player screen, the collection screen, and the playlist detail screen, the current track's thumbnail (or the collection cover) is rendered as a large, heavily blurred and darkened background image. This creates an immersive "ambient" effect that updates as you switch tracks.

**MiniPlayer**
A compact persistent player bar is always visible at the bottom of the Home and Playlists tabs. It shows the current track's thumbnail, title, and play/pause + skip buttons. Tapping it opens the full player screen. The MiniPlayer is rendered at the shell level so it survives navigation between tabs without re-mounting.

**Bottom Navigation**
Two tabs — **Home** and **Playlists** — managed by a `StatefulShellRoute` with `IndexedStack`, which keeps both tab states alive in memory as you switch between them.

---

### Settings

The Settings screen allows you to:

- **Change the API base URL** — point the app at any instance of the YouFree API running on your local network or a remote server.
- **Test the connection** — a button sends a status request to the configured URL and reports whether the backend is reachable.
- **Manage Cookies** — pass authentication cookies to the backend so yt-dlp can access age-restricted or otherwise restricted content (for testing and study purposes only).

---

## Architecture

### Project Structure

```
youfree/lib/
├── main.dart                         # Entry point, dependency injection, service wiring
├── app/
│   ├── app.dart                      # MaterialApp, ThemeData
│   └── router.dart                   # GoRouter config, StatefulShellRoute, _MainShell
├── core/
│   └── constants.dart                # API endpoints, timeout values, cache settings
├── data/
│   ├── models/
│   │   ├── video_model.dart          # VideoModel, StreamInfo, StreamFormat
│   │   ├── collection_model.dart     # CollectionModel, PlaylistPreview, ChannelInfo
│   │   └── local_playlist.dart       # LocalPlaylist (user-created, device-only)
│   ├── repositories/
│   │   └── video_repository.dart     # Abstraction over ApiService; all data access goes here
│   └── services/
│       ├── api_service.dart          # Dio HTTP client, request/response handling
│       ├── audio_handler.dart        # just_audio + audio_service integration
│       ├── download_manager.dart     # Download queue, progress, file persistence
│       ├── history_service.dart      # Recently played persistence (SharedPreferences)
│       ├── lyrics_service.dart       # Fetches plain and synced lyrics
│       ├── playlist_service.dart     # Local playlist CRUD, ChangeNotifier
│       ├── progress_service.dart     # Per-video playback position persistence
│       ├── repertoire_service.dart   # Auto-download logic
│       └── settings_service.dart     # API URL config, SharedPreferences
├── presentation/
│   ├── controllers/
│   │   ├── player_controller.dart    # MobX: player state, audio/video, queue, lyrics
│   │   ├── player_controller.g.dart  # MobX generated code (auto-generated)
│   │   ├── home_controller.dart      # MobX: search, home feed, history
│   │   └── home_controller.g.dart    # MobX generated code (auto-generated)
│   ├── components/
│   │   ├── mini_player.dart          # Persistent mini player widget
│   │   ├── video_card.dart           # Video list item (thumbnail, title, menu)
│   │   └── channel_card.dart         # Channel search result item
│   └── pages/
│       ├── home_page.dart            # Home feed + search + recently played
│       ├── player_page.dart          # Full-screen player (audio/video/lyrics/PiP)
│       ├── playlists_page.dart       # Playlist list with create/rename/delete
│       ├── playlist_detail_page.dart # Single playlist view, play from playlist
│       ├── collection_page.dart      # YouTube channel or playlist collection
│       └── settings_page.dart        # API URL, connection test, cookies
```

---

### State Management

YouFree uses **MobX** for reactive state management across the UI. There are two central observable controllers:

**PlayerController**

Manages everything related to media playback.

| Observable | Type | Description |
|---|---|---|
| `currentVideo` | `VideoModel?` | The video currently loaded |
| `isPlaying` | `bool` | Whether audio/video is actively playing |
| `isLoading` | `bool` | Whether a stream is being fetched/buffered |
| `position` | `Duration` | Current playback position |
| `duration` | `Duration` | Total duration of the current track |
| `progress` | `double` (computed) | `position / duration`, 0.0–1.0 |
| `isVideoMode` | `bool` | Whether video player is active |
| `plainLyrics` | `String?` | Plain text lyrics |
| `syncedLyrics` | `String?` | LRC-format timed lyrics |
| `lyricsLoaded` | `bool` | Whether lyrics have been fetched |
| `suggestions` | `List<VideoModel>` | Auto-queue suggestions |
| `errorMessage` | `String?` | Current error, if any |

Key actions: `loadVideo()`, `togglePlayPause()`, `seekTo()`, `skipToNext()`, `skipToPrevious()`, `switchToAudioMode()`, `switchToVideoMode()`, `fetchLyrics()`.

**HomeController**

Manages the home feed and search.

| Observable | Type | Description |
|---|---|---|
| `searchQuery` | `String` | Current search text |
| `searchType` | `SearchType` | Videos / Channels / Playlists |
| `videos` | `List<VideoModel>` | Current search/feed results |
| `channels` | `List<ChannelInfo>` | Channel search results |
| `playlists` | `List<PlaylistPreview>` | Playlist search results |
| `isLoading` | `bool` | Search/feed in progress |
| `recentlyPlayed` | `List<VideoModel>` | History for the sidebar |
| `errorMessage` | `String?` | Current error, if any |

Key actions: `search()`, `searchChannels()`, `searchPlaylists()`, `loadMoreSearch()`, `setSearchQuery()`, `clearSearch()`, `loadHistory()`.

**Supporting Services**

Services that notify the UI but do not require full MobX use Flutter's `ChangeNotifier`:

- `PlaylistService` — local playlist CRUD
- `DownloadManager` — download progress tracking

---

### Navigation

Routing is handled by **GoRouter** with a `StatefulShellRoute.indexedStack` containing two branches:

```
/ (StatefulShellRoute — _MainShell wraps: BottomNavigationBar + MiniPlayer)
├── /           → HomePage
└── /playlists  → PlaylistsPage

(outside the shell — full screen, no bottom nav)
├── /player          → PlayerPage         (extra: VideoModel)
├── /collection      → CollectionPage     (extra: CollectionModel + PlayerController)
├── /playlist-detail → PlaylistDetailPage
└── /settings        → SettingsPage
```

The `_MainShell` widget wraps the two-tab shell with a `Scaffold` that always renders the `MiniPlayer` and `BottomNavigationBar` at the bottom, regardless of which tab is active. Pages outside the shell (player, collection, etc.) overlay the shell entirely as full-screen routes.

---

### Data Flow

```
Search
  User types
    → HomeController.setSearchQuery()
    → debounce 500ms
    → HomeController.search()
    → VideoRepository.search()
    → ApiService.get("/search?q=...")
    → List<VideoModel>
    → UI (MobX Observer rebuilds)

Play a track
  User taps video
    → PlayerController.loadVideo(video)
    → VideoRepository.getStreamInfo(videoId, format)
    → ApiService.get("/stream?video_id=...")
    → StreamInfo (URL + format metadata)
    → just_audio.setUrl(streamUrl)
    → AudioHandler broadcasts to audio_service (notification, background)
    → UI observes isPlaying / position / duration

Autoplay (suggestions)
  Track starts
    → PlayerController._fetchSuggestions()
    → VideoRepository.getSuggestions(videoId)
    → ApiService.get("/suggestions?video_id=...")
    → List<VideoModel>
    → suggestions observable updated
    → auto-queued for next play

Local Playlist
  User creates playlist
    → PlaylistService.createPlaylist(name)
    → LocalPlaylist serialized to JSON
    → SharedPreferences.setString(...)
    → ChangeNotifier notifies UI
```

---

## Tech Stack

| Package | Version | Purpose |
|---|---|---|
| Flutter | SDK | UI framework |
| mobx | ^2.3.3 | Reactive state management |
| flutter_mobx | ^2.2.1 | MobX widget integration |
| go_router | ^13.2.0 | Declarative navigation |
| just_audio | ^0.9.36 | Audio playback engine |
| audio_service | ^0.18.18 | Background audio + media notification |
| video_player | ^2.9.1 | Video playback |
| dio | ^5.4.0 | HTTP client for API requests |
| cached_network_image | ^3.3.1 | Image caching with placeholders |
| shared_preferences | ^2.3.0 | Local key-value storage |
| path_provider | ^2.1.3 | App directory (downloads) |
| build_runner | ^2.4.8 | Code generation (dev dependency) |
| mobx_codegen | ^2.6.1 | MobX `.g.dart` generation (dev dependency) |

---

## Backend

YouFree requires the **YouFree API** to be running. The API is a separate Python project built with **FastAPI** and **yt-dlp**. It is responsible for:

- YouTube search (videos, channels, playlists)
- Stream URL resolution (audio-only and video)
- Home feed generation
- Collection browsing (channels and playlists)
- Autoplay suggestions
- Lyrics proxy
- Cookie management for restricted content

The Flutter app communicates with the API over HTTP. The base URL can be changed at any time from the Settings screen.

> **YouFree API repository:** *(link will be added once published)*

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) — stable channel, 3.x or later
- An Android device or emulator (PiP is Android-only; all other features work on any Flutter-supported platform)
- The YouFree API running and reachable from the device or emulator

### Running the App

```bash
# 1. Clone the repository
git clone git@github.com:Lucas-Gomes-hb/you-free-app.git
cd you-free-app

# 2. Install dependencies
flutter pub get

# 3. Generate MobX code (required on first clone or after a clean build)
dart run build_runner build --delete-conflicting-outputs

# 4. Run on a connected device or emulator
flutter run
```

> If the MobX `.g.dart` files are already committed in the repository, you can skip step 3.

---

## Configuration

After launching the app for the first time:

1. Open the **Settings** screen.
2. Enter the base URL of your YouFree API instance — for example: `http://192.168.1.100:8000`.
3. Tap **Test Connection** to confirm the app can reach the backend.

The URL is stored locally via `SharedPreferences` and persists across restarts.

---

## License & Usage Terms

This project is released under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license.

**You are free to:**
- Use, study, copy, modify, and distribute this project and its source code.
- Build upon it and create derivative works.
- Share it with others freely.

**Under the following conditions:**
- **Attribution** — You must give appropriate credit to the original author(s) and include a link back to this repository.
- **NonCommercial** — You may **not** use this project, its source code, or any derivative of it for commercial purposes, monetization, profit, paid services, or any activity that generates revenue.

Full license text: [creativecommons.org/licenses/by-nc/4.0](https://creativecommons.org/licenses/by-nc/4.0/)

---

## Disclaimer

> **This project exists solely for educational and study purposes.**
>
> YouFree is not affiliated with, endorsed by, or in any way connected to YouTube, Google LLC, or any of their subsidiaries or partners. YouTube and all related names, logos, and trademarks are the property of their respective owners.
>
> Streaming or downloading YouTube content may be subject to YouTube's [Terms of Service](https://www.youtube.com/t/terms). By using this software, you acknowledge and agree that:
>
> - You will only use it for personal, non-commercial, and educational purposes.
> - You will not use it to infringe on the intellectual property rights of any content creator.
> - The authors of this project bear no responsibility for how the software is used by others.
>
> **This project must not be used for commercial purposes, for building products or services, or for any activity that generates revenue of any kind.**
