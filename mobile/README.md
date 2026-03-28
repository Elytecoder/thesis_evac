# Mobile App - AI-Powered Evacuation Routing

Flutter mobile application for the AI-powered evacuation routing system. Provides real-time evacuation routing, hazard reporting, and offline support for residents and MDRRMO personnel.

---

## Features

### Resident Features
- **Live Navigation**: Turn-by-turn navigation with voice guidance to evacuation centers
- **Map View**: OpenStreetMap-based map showing evacuation centers and hazards
- **Route Planning**: Multiple risk-weighted route options (Green/Yellow/Red)
- **Hazard Reporting**: Submit hazard reports with photos/videos and location
- **Notifications**: Real-time updates on report status (approved/rejected)
- **Offline Support**: Cached maps, routes, and hazards for offline use
- **Settings**: Profile management, emergency contacts, account settings

### MDRRMO Features
- **Dashboard**: Real-time statistics, hazard distribution, system status
- **Reports Management**: Review, approve, or reject hazard reports
- **Map Monitoring**: View all hazards and evacuation centers on map
- **Evacuation Center Management**: Add, edit, activate/deactivate centers
- **Analytics**: Hazard type distribution and road risk analysis
- **User Management**: View and manage resident accounts
- **Settings**: Emergency contacts management, system configuration

---

## Tech Stack

| Category | Technologies |
|----------|--------------|
| **Framework** | Flutter 3.x, Dart 3.x |
| **Maps** | flutter_map, OpenStreetMap tiles, OSRM API |
| **Location** | geolocator, permission_handler |
| **Navigation** | flutter_tts (voice guidance) |
| **Storage** | hive (offline cache), shared_preferences (settings) |
| **Network** | dio (HTTP), connectivity_plus |
| **Media** | image_picker (photo/video upload) |
| **UI** | Material Design 3, custom widgets |

---

## Project Structure

```
mobile/
├── lib/
│   ├── core/                      # Core configuration
│   │   ├── auth/                  # Session / token storage (SessionStorage)
│   │   ├── config/                # api_config, storage_config
│   │   ├── network/               # ApiClient (Dio)
│   │   ├── storage/               # Hive offline storage
│   │   └── utils/                 # Shared helpers (e.g. barangay normalize)
│   ├── data/                      # Mock data providers
│   ├── features/                  # Feature modules
│   │   ├── admin/                 # MDRRMO services
│   │   ├── authentication/        # Auth service
│   │   ├── emergency_contacts/    # Contacts service
│   │   ├── hazards/               # Hazard service
│   │   ├── residents/             # Resident services
│   │   └── routing/               # Routing services
│   ├── models/                    # Data models
│   ├── ui/                        # UI screens and widgets
│   │   ├── admin/                 # MDRRMO screens
│   │   ├── screens/               # Resident screens
│   │   └── widgets/               # Reusable widgets
│   └── main.dart                  # App entry point
├── android/                       # Android configuration
├── ios/                           # iOS configuration
├── windows/                       # Windows configuration
├── linux/                         # Linux configuration
├── pubspec.yaml                   # Dependencies
└── README.md                      # This file
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
- **`renderBaseUrl`** — Default deployed API root including `/api` (e.g. `https://your-service.onrender.com/api`). The getter **`baseUrl`** uses this for release builds.
- **Timeouts** — `connectTimeout` / `receiveTimeout` are extended (e.g. **120s**) so hosted backends (Render cold start) can respond before the client aborts.

Local examples:

```dart
// Emulator → host machine Django
static const String renderBaseUrl = 'http://10.0.2.2:8000/api';

// Web / desktop → same machine
static const String renderBaseUrl = 'http://127.0.0.1:8000/api';
```

Adjust `renderBaseUrl` to match your environment; do not commit secrets.

### Mock Data Mode
By default, the app can use mock data. To use the real backend:
1. Start the Django backend and run `load_mock_data` (road network required for routing)
2. Set `useMockData = false` in `lib/core/config/api_config.dart`
3. Set `baseUrl` to your backend (e.g. `http://10.0.2.2:8000/api` for Android emulator)
4. Log in so the app sends the auth token for protected endpoints (e.g. report hazard, calculate route)

---

## Testing

### Run unit tests
```bash
flutter test
```

### Manual testing
1. **Login** — Use **email + password** from your Django database (e.g. `create_test_users` / registration). Legacy demo strings like `resident1` apply only if those users exist.
2. **Map** — Location permission, evacuation center and hazard markers
3. **Navigation** — Select a center and start live navigation
4. **Reporting** — Submit a hazard from the report flow (with location and optional media)
5. **Notifications** — Notification bell for report status updates
6. **MDRRMO** — Users tab loads **`GET /api/users/`** (requires MDRRMO role + token)

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_map: ^7.0.2` | Interactive map widget |
| `latlong2: ^0.9.0` | Latitude/longitude handling |
| `geolocator: ^10.1.0` | GPS location tracking |
| `flutter_tts: ^4.2.0` | Text-to-speech for navigation |
| `dio: ^5.4.0` | HTTP client for API calls |
| `hive: ^2.2.3` | Offline data storage |
| `image_picker: ^1.0.7` | Camera/gallery access |
| `shared_preferences: ^2.2.0` | Local key-value storage |

Full list in `pubspec.yaml`.

---

## Offline Support

The app caches:
- **Evacuation centers**: Locations, names, addresses
- **Hazard reports**: Verified hazards from MDRRMO
- **Routes**: Previously calculated routes
- **Map tiles**: OpenStreetMap tiles for offline viewing
- **Road graph**: Road network for offline routing

Sync occurs automatically when online. Offline features:
- View cached evacuation centers
- Calculate routes using cached road graph
- View previously loaded map areas
- Report hazards (synced later)

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

---

## Documentation

At the repository root:

- **[docs/FOLDER_STRUCTURE.md](../docs/FOLDER_STRUCTURE.md)** — **Folder structure** for backend + mobile; **database**, **algorithms**, and **API** file paths
- **[README.md](../README.md)** — Full-stack overview
- **`docs/`** — SRS, test cases, algorithm write-ups (`Algorithms_How_They_Work.md`, `algorithm-workflow.md`), class diagrams

---

## License

This project is for academic (thesis) use. See repository root for license information.
