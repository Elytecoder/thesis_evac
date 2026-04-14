# Mobile App — AI-Powered Evacuation Routing

Flutter mobile application for the AI-powered evacuation routing system. Provides real-time evacuation routing, hazard reporting, and full offline support for residents and MDRRMO personnel.

---

## Features

### Resident Features
- **Live Navigation** — Turn-by-turn navigation with voice guidance to evacuation centers
- **Map View** — OpenStreetMap-based map showing evacuation centers and hazards
- **Route Planning** — Multiple risk-weighted route options (Green / Yellow / Red)
- **Hazard Reporting** — Submit hazard reports with photos/videos and location; queued offline and auto-synced when reconnected
- **Notifications** — Real-time updates on report status (approved/rejected)
- **Offline Mode** — Full offline support: cached evacuation centers, hazards, and routes; offline report queue; animated offline banner; auto-sync on reconnect
- **Settings** — Profile management, emergency contacts, account settings

### MDRRMO Features
- **Dashboard** — Real-time statistics, hazard distribution, system status
- **Reports Management** — Review, approve, or reject hazard reports
- **Map Monitoring** — View all hazards and evacuation centers on map
- **Evacuation Center Management** — Add, edit, activate/deactivate centers
- **Analytics** — Hazard type distribution and road risk analysis
- **User Management** — View and manage resident accounts
- **Settings** — Emergency contacts management, system configuration

---

## Tech Stack

| Category | Technologies |
|----------|--------------|
| **Framework** | Flutter 3.x, Dart 3.x |
| **Maps** | flutter_map, OpenStreetMap tiles, OSRM API |
| **Location** | geolocator, permission_handler |
| **Navigation** | flutter_tts (voice guidance) |
| **Offline storage** | hive + hive_flutter (evacuation centers, hazards, routes, pending queue) |
| **Connectivity** | connectivity_plus (network monitoring and auto-sync trigger) |
| **Auth storage** | flutter_secure_storage (token), shared_preferences (session cache) |
| **Network** | dio (HTTP singleton, keep-alive connections) |
| **Media** | image_picker (photo/video upload) |
| **UI** | Material Design 3, custom widgets |

---

## Project Structure

```
mobile/
├── lib/
│   ├── core/
│   │   ├── auth/              # SessionStorage (secure token + session metadata)
│   │   ├── config/            # api_config.dart, storage_config.dart (Hive box names)
│   │   ├── network/           # ApiClient — Dio singleton, keep-alive, debug-only logging
│   │   ├── services/          # ConnectivityService, SyncService (auto-sync on reconnect)
│   │   ├── storage/           # StorageService — all Hive read/write operations
│   │   └── utils/             # Shared helpers
│   ├── data/                  # Mock data providers
│   ├── features/
│   │   ├── admin/             # MDRRMO services
│   │   ├── authentication/    # AuthService (login, register, session)
│   │   ├── emergency_contacts/
│   │   ├── hazards/           # HazardService (submit, queue, sync, cache)
│   │   ├── navigation/        # Live navigation, offline routing
│   │   ├── residents/         # Resident hazard reports, notifications
│   │   └── routing/           # RoutingService (evacuation centers, route cache)
│   ├── models/                # Data models (User, HazardReport, EvacuationCenter, Route, …)
│   ├── ui/
│   │   ├── admin/             # MDRRMO screens
│   │   ├── screens/           # Resident screens (map, login, register, navigation, …)
│   │   └── widgets/           # Reusable widgets (OfflineBanner, report media preview, …)
│   └── main.dart              # App entry — Hive init, SyncService start
├── android/
├── ios/
├── windows/
├── pubspec.yaml
└── README.md
```

---

## Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher
- Android Studio or Xcode (for mobile development)
- Chrome (for web development)

---

## Installation

### 1. Install Flutter
Follow the official Flutter installation guide: https://docs.flutter.dev/get-started/install

### 2. Clone and setup
```bash
cd thesis_evac/mobile
flutter pub get
```

### 3. Run the app
```bash
# Android emulator
flutter run

# Chrome web
flutter run -d chrome

# Windows desktop
flutter run -d windows
```

---

## Configuration

### API configuration (`lib/core/config/api_config.dart`)

- **`useMockData`** — `false` for production / real backend.
- **`renderBaseUrl`** — Default deployed API root including `/api` (e.g. `https://your-service.onrender.com/api`). The getter **`baseUrl`** uses this for all builds.
- **Timeouts** — `connectTimeout` / `receiveTimeout` are extended (120s) so hosted backends (Render cold start) can respond before the client aborts.

Local examples:

```dart
// Emulator → host machine Django
static const String renderBaseUrl = 'http://10.0.2.2:8000/api';

// Web / desktop → same machine
static const String renderBaseUrl = 'http://127.0.0.1:8000/api';
```

### Mock Data Mode
By default, the app can use mock data. To use the real backend:
1. Start the Django backend and run `load_mock_data` (road network required for routing)
2. Set `useMockData = false` in `lib/core/config/api_config.dart`
3. Set `renderBaseUrl` to your backend (e.g. `http://10.0.2.2:8000/api` for Android emulator)
4. Log in so the app sends the auth token for protected endpoints (report hazard, calculate route, etc.)

---

## Offline Mode

The app is fully functional without internet using Hive-cached data.

### What is cached

| Data | Hive Box | Cached When |
|------|----------|-------------|
| Evacuation centers | `evacuation_centers` | Every successful API fetch |
| Verified hazards (map overlay) | `verified_hazards` | Every successful API fetch |
| Calculated routes | `road_segments` (key `route_*`) | After every route calculation |
| Baseline hazards | `baseline_hazards` | Bootstrap sync |
| Pending (offline) reports | `pending_reports` | On offline submission |
| User session | `user` box + SharedPreferences | After login |

### Offline report queue

When a hazard report is submitted while offline:
1. The report is saved locally in the `pending_reports` Hive box.
2. The user sees an immediate "queued" confirmation.
3. The offline banner shows the pending count.
4. When connectivity returns, `SyncService` flushes the queue automatically — only failed entries are retried on the next cycle.

### Auto-sync on reconnect

`SyncService` (started at app launch) listens to `ConnectivityService.onConnectionChange`. When the device goes online:
1. Queued reports are sent to the backend.
2. Evacuation centers are refreshed.
3. Verified hazards are refreshed.
4. `last_sync_time` is saved to `SharedPreferences`.

### Offline banner

An animated red banner slides in from the top of the map screen whenever the device has no network:

```
📵  Offline Mode: Data may not be up-to-date
     2 reports queued — will sync when online
```

It disappears automatically when connectivity returns.

See **[../docs/OFFLINE_MODE.md](../docs/OFFLINE_MODE.md)** for full technical documentation.

---

## Performance Optimizations

| Area | Optimization |
|------|-------------|
| **HTTP connections** | `ApiClient` is a singleton — all services share one `Dio` instance with persistent keep-alive connections |
| **Production logging** | `LogInterceptor` is wrapped in `kDebugMode` — no request/response body logging in release APKs |
| **App startup** | `AuthGateScreen` reads user role from `SharedPreferences` cache — no profile API call on restart if token is still valid |
| **Login storage** | `SharedPreferences.setString` and `SessionStorage.writeSession` run concurrently via `Future.wait` |
| **Timing logs** | Login and register methods log `"completed in XXXms"` via `dart:developer` — visible in Flutter DevTools |

---

## Testing

### Run unit tests
```bash
flutter test
```

### Manual testing
1. **Login** — Use **email + password** from your Django database (e.g. `create_test_users` / registration).
2. **Map** — Location permission, evacuation center and hazard markers
3. **Navigation** — Select a center and start live navigation
4. **Reporting** — Submit a hazard from the report flow (with location and optional media)
5. **Offline** — Disable internet → verify banner appears → submit a report → re-enable internet → verify report syncs
6. **Notifications** — Notification bell for report status updates
7. **MDRRMO** — Users tab loads `GET /api/users/` (requires MDRRMO role + token)

---

## Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_map` | `^7.0.2` | Interactive map widget |
| `latlong2` | `^0.9.1` | Latitude/longitude handling |
| `geolocator` | `^12.0.0` | GPS location tracking |
| `flutter_tts` | `^4.2.1` | Text-to-speech for live navigation |
| `dio` | `^5.4.0` | HTTP client (singleton, keep-alive) |
| `hive` | `^2.2.3` | Offline key-value storage engine |
| `hive_flutter` | `^1.1.0` | Flutter integration for Hive |
| `connectivity_plus` | `^6.0.0` | Network interface monitoring for offline mode |
| `flutter_secure_storage` | `^9.2.4` | Secure auth token persistence |
| `shared_preferences` | `^2.2.0` | Lightweight key-value store (profile cache, settings) |
| `image_picker` | `^1.0.7` | Camera/gallery access for hazard reports |

Full list in `pubspec.yaml`.

---

## Build for Production

### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

---

## Troubleshooting

### Location permission issues
- Android: Check `AndroidManifest.xml` for location permissions
- iOS: Check `Info.plist` for location usage descriptions
- Grant location permission manually in device settings

### Map tiles not loading
- Check internet connection
- Use Android emulator instead of Chrome (CORS issues)
- Verify OpenStreetMap service is accessible

### Backend connection issues
- Ensure Django server is running on `http://127.0.0.1:8000`
- For emulator, use `http://10.0.2.2:8000` instead of `127.0.0.1`
- Check `api_config.dart` for correct base URL
- On Render: first request after idle can take up to 2 minutes (cold start) — timeouts are already extended

### Offline reports not syncing
- Verify internet connection is restored
- Check the offline banner — it disappears when online
- `SyncService` triggers automatically; no manual action needed

---

## Documentation

- **[../docs/OFFLINE_MODE.md](../docs/OFFLINE_MODE.md)** — Full technical documentation for offline mode: architecture, Hive box layout, queue lifecycle, auto-sync, feature matrix
- **[../docs/FOLDER_STRUCTURE.md](../docs/FOLDER_STRUCTURE.md)** — Folder structure for backend + mobile; database, algorithms, and API file paths
- **[../README.md](../README.md)** — Full-stack overview, API table, performance notes
- **`../docs/`** — SRS, test cases, algorithm write-ups (`Algorithms_How_They_Work.md`, `algorithm-workflow.md`), class diagrams

---

## License

This project is for academic (thesis) use. See repository root for license information.
