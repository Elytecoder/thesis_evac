# AI-Powered Evacuation Routing Application

A full-stack system for **intelligent evacuation route recommendation** using machine learning and risk-weighted routing. Built for **Bulan, Sorsogon, Philippines** — a mobile app for residents and an admin backend for MDRRMO (Municipal Disaster Risk Reduction and Management Office).

---

## Overview

This project provides:

- **Mobile app (Flutter)** — Residents view evacuation centers on a map, get multiple route options with risk levels (Green / Yellow / Red), report hazards with photo/video, receive notifications when reports are approved/rejected, and use fully cached data when offline — including an offline report queue that syncs automatically when connectivity returns.
- **Backend API (Django REST)** — Evacuation centers, risk-weighted route calculation (Modified Dijkstra on road segments), hazard report submission, Naive Bayes report validation, Random Forest segment risk, and MDRRMO workflows (approve/reject/delete reports, dashboard, analytics, user management).

**Verified hazards** on the map are **resident reports that MDRRMO has approved**; the system can run with resident reports only (MDRRMO baseline data is optional). **Routing** uses a **road network** (e.g. from `load_mock_data`); without it, no routes are returned.

---

## Features

### Mobile app

| Feature | Description |
|--------|-------------|
| **Map & location** | OpenStreetMap tiles, user GPS, evacuation center and hazard markers |
| **Evacuation centers** | List and map of operational centers; select one to get route suggestions |
| **Route options** | Up to 3 routes per destination with risk levels (Green / Yellow / Red); "High Risk" / "Safer Route" labels and "Possibly Blocked" tag; no-safe-route warning modal and alternative evacuation center suggestions when all routes are high-risk |
| **Hazard reporting** | Submit reports with type, location, description, photo/video; auto-rejected if reporter is more than 150 m from the hazard |
| **Hazard confirmation** | Residents can confirm existing approved hazards, strengthening the consensus score |
| **Notifications (resident)** | Report approved/rejected; tap approved notification to jump to the hazard location on the map with a pulsing highlight animation |
| **Notifications (MDRRMO)** | Slide-in in-app banner when a new report is submitted; tap to open that report directly in the Reports tab |
| **Email verification** | Real email verification code sent via Brevo API on registration; 5-minute expiry timer; resend cooldown |
| **Offline mode** | Full offline support: Hive cache for evacuation centers, verified hazards, and routes; offline report queue with automatic background sync on reconnect; animated offline banner |
| **Authentication** | Login, register, token-based; role-based (resident / MDRRMO); email verification required; session cached locally for instant app start without network call |
| **Resident** | Map, report hazard, confirm hazards, view routes, live navigation, notifications, settings |
| **MDRRMO** | Dashboard (stats, hazard distribution, recent activity), reports (pending/approved/rejected), approve/reject/delete/restore, map monitor, evacuation center management, analytics, user management, system logs |

### Backend API

| Feature | Description |
|--------|-------------|
| **Evacuation centers** | CRUD, list, filter; activate/deactivate |
| **Route calculation** | Modified Dijkstra on road segments; Random Forest segment risk; returns 3 alternatives; risk evaluation layer adds no_safe_route, message, recommended_action, alternative_centers, and per-route risk_label / possibly_blocked / contributing_factors (requires road network via `load_mock_data`) |
| **Hazard reports** | Submit report; Naive Bayes score; proximity gate (>150 m auto-reject); all new reports PENDING until MDRRMO approves/rejects |
| **Hazard confirmations** | Residents confirm existing reports (`POST /api/confirm-hazard-report/`); confirmation count raises consensus score |
| **Verified hazards** | Approved resident reports only (`GET /api/verified-hazards/`) |
| **Bootstrap sync** | Centers and baseline hazards for mobile cache |
| **MDRRMO** | Dashboard stats, hazard distribution, recent activity; pending/approved/rejected reports; approve, reject, restore, delete; notifications; user list (barangay/status filter) |
| **Notifications** | List, unread count, mark read, delete (residents) |
| **Email verification** | 6-digit code sent via Brevo HTTP API (HTTPS/443); 5-minute expiry; `verify_code()` returns `valid`/`expired`/`invalid` |
| **Django admin** | `/admin/` for users, centers, reports, road segments |

### Algorithms & ML

- **Modified Dijkstra** — Safest path with risk-weighted edge costs (`cost = distance + effective_risk × 500`) on the road graph.
- **Naive Bayes** — Hazard report text validation (`hazard_type + description` via CountVectorizer + MultinomialNB); gives MDRRMO a credibility score; no auto-approve.
- **Rule scoring** — Distance weight (reporter within 150 m) and consensus score (nearby same-type reports + confirmations within 100 m) combined with NB score: `final = NB×0.5 + distance×0.3 + consensus×0.2`.
- **Random Forest** — Road segment risk prediction from nearby approved hazard counts (8 types, within 200 m); stored as `predicted_risk_score` per segment.
- **Proximity gate** — Reports from users more than 150 m from the hazard location are auto-rejected before any ML runs.

---

## Tech stack

| Layer | Technologies |
|-------|--------------|
| **Mobile** | Flutter 3.x, Dart 3.x; flutter_map, geolocator, dio, hive, connectivity_plus, flutter_secure_storage, shared_preferences, image_picker |
| **Backend** | Python 3.10+, Django 4.2+, Django REST Framework |
| **Database** | SQLite (dev); PostgreSQL recommended for production |
| **Maps** | OpenStreetMap tiles; OSRM used only in app mock mode for route geometry |
| **ML** | scikit-learn (Random Forest); Naive Bayes implemented in-app |

---

## Repository structure

High-level layout (see **[docs/FOLDER_STRUCTURE.md](docs/FOLDER_STRUCTURE.md)** for algorithms, database file, and a full map):

```
thesis_evac/
├── README.md                 # This file
├── docs/                     # SRS, test cases, diagrams, folder structure guide
│   ├── OFFLINE_MODE.md       # Offline mode technical documentation
│   └── ...
├── backend/                  # Django API (SQLite: backend/db.sqlite3)
│   ├── config/               # Settings, URLs, middleware
│   ├── apps/
│   │   ├── evacuation/       # Evacuation centers
│   │   ├── hazards/          # Hazard reports, baseline hazards, proximity checks
│   │   ├── mobile_sync/      # Mobile API (routes, report, MDRRMO, bootstrap)
│   │   ├── risk_prediction/  # Random Forest segment risk
│   │   ├── routing/          # Road segments, Modified Dijkstra
│   │   ├── users/            # User model, auth, barangay utils
│   │   ├── validation/       # Naive Bayes, consensus (nearby count)
│   │   ├── notifications/    # User notifications
│   │   └── system_logs/      # Audit logs, MDRRMO user list (/api/users/)
│   ├── core/                 # Permissions, utils, mock_loader
│   ├── mock_data/            # Training / mock JSON for ML validators
│   ├── manage.py
│   └── requirements.txt
└── mobile/                   # Flutter app
    ├── lib/
    │   ├── core/
    │   │   ├── config/       # api_config, storage_config (Hive box names)
    │   │   ├── network/      # ApiClient (Dio singleton, keep-alive)
    │   │   ├── auth/         # SessionStorage (secure token)
    │   │   ├── services/     # ConnectivityService, SyncService
    │   │   └── storage/      # StorageService (Hive CRUD)
    │   ├── features/         # Auth, routing, hazards, residents, admin, navigation
    │   ├── models/
    │   ├── data/             # Mock data
    │   └── ui/               # Screens + widgets (OfflineBanner, etc.)
    ├── android/, ios/, web/, ...
    └── pubspec.yaml
```

---

## Prerequisites

- **Backend:** Python 3.10+, pip
- **Mobile:** Flutter 3.x, Dart 3.x; Android Studio / Xcode for device/emulator
- **Optional:** Git

---

## Installation & run

### 1. Clone the repository

```bash
git clone https://github.com/Elytecoder/thesis_evac.git
cd thesis_evac
```

### 2. Backend (Django API)

```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS/Linux
pip install -r requirements.txt
python manage.py migrate
python manage.py load_mock_data    # Road network + segment risk (required for routing)
python manage.py seed_evacuation_centers
python manage.py runserver
```

- **API base:** http://127.0.0.1:8000/api/
- **Admin:** http://127.0.0.1:8000/admin/  
  Create a superuser: `python manage.py createsuperuser`

**Note:** `load_mock_data` loads the road network and assigns segment risk scores so that **route calculation** returns paths. Without it, the routing API returns no routes.

### 3. Mobile app (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

Use an emulator or a connected device. For Android, ensure location permission is granted.

### 4. Connect app to backend

In `mobile/lib/core/config/api_config.dart`:

- Set `useMockData = false` to use the real API.
- Set **`renderBaseUrl`** (or local equivalent) so `baseUrl` points at your API root with **`/api` suffix**, e.g. `http://127.0.0.1:8000/api`, or `http://10.0.2.2:8000/api` on the Android emulator.
- **Hosted backends (e.g. Render):** the first request after idle can take **60–120+ seconds** (cold start). `connectTimeout` / `receiveTimeout` are set accordingly in `api_config.dart`.

The app uses **token authentication** for protected endpoints (e.g. report hazard, calculate route, notifications). Log in as resident or MDRRMO to use those features.

---

## API overview

All endpoints are under `http://127.0.0.1:8000/api/`. Token auth required where noted.

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/send-verification-code/` | No | Send 6-digit email verification code (Brevo API) |
| POST | `/auth/register/` | No | Register with verified email code |
| POST | `/auth/login/` | No | Login (email + password) |
| POST | `/auth/logout/` | Token | Logout |
| GET | `/auth/profile/` | Token | Current user profile |
| PATCH | `/auth/profile/update/` | Token | Update profile |
| POST | `/auth/change-password/` | Token | Change password |
| DELETE | `/auth/delete-account/` | Token | Delete own account |
| GET | `/evacuation-centers/` | No | List evacuation centers |
| GET | `/bootstrap-sync/` | No | Sync centers, baseline hazards |
| POST | `/report-hazard/` | Token | Submit hazard report |
| GET | `/my-reports/` | Token | Current user's reports |
| DELETE | `/my-reports/<id>/` | Token | Delete own pending report |
| GET | `/verified-hazards/` | No | Approved reports (for map) |
| POST | `/confirm-hazard-report/` | Token | Confirm an existing hazard report |
| POST | `/check-similar-reports/` | Token | Check for nearby similar reports |
| POST | `/calculate-route/` | Token | Get up to 3 risk-weighted routes |
| GET | `/notifications/` | Token | List notifications |
| GET | `/notifications/unread-count/` | Token | Unread count |
| POST | `/notifications/mark-all-read/` | Token | Mark all notifications read |
| GET | `/mdrrmo/dashboard-stats/` | Token (MDRRMO) | Dashboard stats, hazard distribution, recent activity |
| GET | `/mdrrmo/pending-reports/` | Token (MDRRMO) | Pending reports |
| GET | `/mdrrmo/rejected-reports/` | Token (MDRRMO) | Rejected reports |
| POST | `/mdrrmo/approve-report/` | Token (MDRRMO) | Approve or reject report |
| POST | `/mdrrmo/restore-report/` | Token (MDRRMO) | Restore rejected report |
| DELETE | `/mdrrmo/reports/<id>/` | Token (MDRRMO) | Delete approved/rejected report |
| GET | `/users/` | Token (MDRRMO) | List all registered users (barangay, status, search) |
| GET | `/users/<id>/` | Token (MDRRMO) | User detail + report counts |
| POST | `/users/<id>/suspend/` | Token (MDRRMO) | Suspend user |
| POST | `/users/<id>/activate/` | Token (MDRRMO) | Activate user |
| DELETE | `/users/<id>/delete/` | Token (MDRRMO) | Delete user |
| GET | `/mdrrmo/system-logs/` | Token (MDRRMO) | System audit logs |
| DELETE | `/mdrrmo/system-logs/clear/` | Token (MDRRMO) | Clear system logs |

---

## Routing behavior

- **Backend (real API):** Route calculation uses **RoadSegment** records and **Modified Dijkstra**. Run `python manage.py load_mock_data` to load the mock road network and segment risk scores; otherwise the graph is empty and no routes are returned.
- **Approved hazard reports** feed into routing in two ways: (1) as features for the Random Forest model (`predicted_risk_score` per segment, within 200 m) and (2) as live dynamic risk applied at route time (within 100 m). Only **approved** reports affect routing — pending and rejected reports have no effect.
- **Mobile mock mode:** When `useMockData = true`, the app can use OSRM for route geometry; with `useMockData = false`, routes come from the backend only.

---

## Offline mode

The app is fully functional offline using cached data. Core behaviour:

- **Evacuation centers** and **verified hazards** are cached to Hive on every successful API fetch and served locally when offline.
- **Routes** are cached per origin–destination pair for 7 days and replayed when offline.
- **Hazard reports** submitted while offline are saved to a dedicated `pending_reports` Hive queue and automatically sent to the backend when connectivity returns.
- A **red animated banner** appears at the top of the map screen when offline, showing how many reports are queued.
- **Auto-sync** triggers as soon as the device reconnects: queued reports are flushed, then evacuation centers and hazards are refreshed.
- **Session restore** on app startup uses the locally cached user role — no network call needed if the token is still valid.

See **[docs/OFFLINE_MODE.md](docs/OFFLINE_MODE.md)** for full technical documentation.

---

## Performance optimizations

### Backend
- **Email field indexed** (`users_user_email_idx`) — login lookup is O(log n) instead of O(n).
- **GZip compression** enabled on all responses via Django's `GZipMiddleware`.
- **`SessionAuthentication` removed** from REST framework — mobile API uses token-only auth, eliminating session middleware overhead per request.
- **Registration DB writes reduced** from 2 → 1 (password hashed inside `create_user` in a single step).
- **Response-time logging** — login and registration endpoints log `"completed in XXXms"` to the server logger.
- **Email sent synchronously via HTTPS** — Brevo HTTP API (port 443) called directly in the view; no background threads that Gunicorn could kill before completion.

### Mobile
- **`ApiClient` singleton** — all services share one `Dio` instance with persistent HTTP keep-alive connections instead of reconnecting per request.
- **`LogInterceptor` is debug-only** — zero request/response logging overhead in release APKs.
- **Cache-first session restore** — `AuthGateScreen` reads the user role from `SharedPreferences` on startup; the profile API is only called on a cold cache miss.
- **Parallel storage writes after login** — `SharedPreferences` and `SessionStorage` writes run concurrently via `Future.wait`.

---

## Testing

### Backend

```bash
cd backend
python manage.py test
python manage.py test apps.validation --verbosity=2   # Example: one app
```

### Mobile

```bash
cd mobile
flutter test
```

---

## Configuration

- **Backend:** `backend/config/settings.py` (DEBUG, SECRET_KEY, database, MOCK_DATA_DIR). Use environment variables for secrets (see below).
- **Mobile:** `mobile/lib/core/config/api_config.dart` (baseUrl, useMockData, timeouts).

### Required environment variables (Render / production)

| Variable | Description |
|----------|-------------|
| `DJANGO_SECRET_KEY` | Long random string (50+ chars) — generate with `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"` |
| `DJANGO_DEBUG` | `False` in production |
| `BREVO_API_KEY` | Brevo (Sendinblue) API key for transactional email (`xkeysib-...`) |
| `DEFAULT_FROM_EMAIL` | Verified sender email in your Brevo account (e.g. `yourname@gmail.com`) |

### Optional environment variables

| Variable | Description |
|----------|-------------|
| `EMAIL_HOST_USER` | SMTP username (used only for local SMTP fallback when `BREVO_API_KEY` is not set) |
| `EMAIL_HOST_PASSWORD` | SMTP password / app password |
| `SYSTEM_LOG_RETENTION_DAYS` | How many days to keep system logs (default: 30) |

---

## Documentation

- **[docs/OFFLINE_MODE.md](docs/OFFLINE_MODE.md)** — Full technical documentation for the offline mode: architecture, Hive box layout, connectivity detection, queue lifecycle, auto-sync, UI indicator, and feature availability matrix.
- **[docs/FOLDER_STRUCTURE.md](docs/FOLDER_STRUCTURE.md)** — **Folder structure**, where the **database**, **algorithms** (Dijkstra, Naive Bayes, Random Forest), **API modules**, and **Flutter layers** live.
- **[docs/Algorithms_How_They_Work.md](docs/Algorithms_How_They_Work.md)** — Detailed explanation of all algorithms with formulas (NB, rule scoring, RF, Dijkstra, risk evaluation layer).
- **[docs/algorithm-workflow.md](docs/algorithm-workflow.md)** — End-to-end data flow from report submission to safer route delivery.
- **[docs/HAZARD_CONFIRMATION_SYSTEM.md](docs/HAZARD_CONFIRMATION_SYSTEM.md)** — How resident confirmations strengthen consensus scoring.
- **[docs/PROXIMITY_AND_MEDIA_UPDATES.md](docs/PROXIMITY_AND_MEDIA_UPDATES.md)** — Proximity gate (150 m auto-reject) and media upload handling.
- **[backend/README.md](backend/README.md)** — Backend setup, commands, email config, tests, deploy.
- **[mobile/README.md](mobile/README.md)** — Mobile app structure, configuration, run instructions.
- **`docs/`** — See **[docs/README.md](docs/README.md)** for an index; includes SRS, test cases, algorithm write-ups, ML implementation guide, and class diagrams.

---

## Thesis context

This repository supports a thesis on **AI-powered mobile evacuation route recommendation** for Bulan, Sorsogon, combining:

- Risk-weighted pathfinding (Modified Dijkstra on road segments)
- Machine learning for report validation (Naive Bayes) and road segment risk (Random Forest)
- Resident hazard reporting and MDRRMO verification workflow
- Fully offline-capable mobile client with Hive caching, offline report queue, auto-sync, and animated connectivity indicator

---

## License

This project is for academic (thesis) use. See repository or author for terms.
