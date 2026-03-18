# AI-Powered Evacuation Routing Application

A full-stack system for **intelligent evacuation route recommendation** using machine learning and risk-weighted routing. Built for **Bulan, Sorsogon, Philippines** — a mobile app for residents and an admin backend for MDRRMO (Municipal Disaster Risk Reduction and Management Office).

---

## Overview

This project provides:

- **Mobile app (Flutter)** — Residents view evacuation centers on a map, get multiple route options with risk levels (Green / Yellow / Red), report hazards with photo/video, receive notifications when reports are approved/rejected, and use cached data when offline.
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
| **Hazard reporting** | Submit reports with type, location, description, photo/video; too-far warning (within 1 km) |
| **Notifications** | Report approved/rejected; tap approved notification to open map at report location |
| **Offline support** | Hive cache for centers, routes, and hazards |
| **Authentication** | Login, register, token-based; role-based (resident / MDRRMO) |
| **Resident** | Map, report hazard, view routes, live navigation, notifications, settings |
| **MDRRMO** | Dashboard (stats, hazard distribution, recent activity), reports (pending/approved/rejected), approve/reject/delete/restore, map monitor, evacuation center management, analytics, user management, system logs |

### Backend API

| Feature | Description |
|--------|-------------|
| **Evacuation centers** | CRUD, list, filter; activate/deactivate |
| **Route calculation** | Modified Dijkstra on road segments; Random Forest segment risk; returns 3 alternatives; risk evaluation layer adds no_safe_route, message, recommended_action, alternative_centers, and per-route risk_label / possibly_blocked / contributing_factors (requires road network via `load_mock_data`) |
| **Hazard reports** | Submit report; Naive Bayes score; distance check (>1 km auto-reject); all new reports PENDING until MDRRMO approves/rejects |
| **Verified hazards** | Approved resident reports only (`GET /api/verified-hazards/`) |
| **Bootstrap sync** | Centers and baseline hazards for mobile cache |
| **MDRRMO** | Dashboard stats, hazard distribution, recent activity; pending/approved/rejected reports; approve, reject, restore, delete; notifications; user list (barangay/status filter) |
| **Notifications** | List, unread count, mark read, delete (residents) |
| **Django admin** | `/admin/` for users, centers, reports, road segments |

### Algorithms & ML

- **Modified Dijkstra** — Shortest path with risk-weighted edge costs (distance + risk × multiplier) on the road graph.
- **Naive Bayes** — Hazard report validation (probability score); used for MDRRMO insight; report status is set by MDRRMO (no auto-approve).
- **Random Forest** — Road segment risk prediction; scores applied to segments for routing (mock training data or lazy-fill when all segment risks are zero).
- **Proximity rule** — Reports from users more than 1 km from the hazard location are auto-rejected.

---

## Tech stack

| Layer | Technologies |
|-------|--------------|
| **Mobile** | Flutter 3.x, Dart; flutter_map, geolocator, dio, hive, image_picker, shared_preferences |
| **Backend** | Python 3.10+, Django 4.2+, Django REST Framework |
| **Database** | SQLite (dev); PostgreSQL recommended for production |
| **Maps** | OpenStreetMap tiles; OSRM used only in app mock mode for route geometry |
| **ML** | scikit-learn (Random Forest); Naive Bayes implemented in-app |

---

## Repository structure

```
thesis_evac/
├── README.md                 # This file
├── backend/                  # Django API
│   ├── config/               # Settings, URLs
│   ├── apps/
│   │   ├── evacuation/       # Evacuation centers
│   │   ├── hazards/          # Hazard reports, baseline hazards
│   │   ├── mobile_sync/      # Mobile API (routes, report, MDRRMO, bootstrap)
│   │   ├── risk_prediction/  # Random Forest segment risk
│   │   ├── routing/          # Road segments, Modified Dijkstra
│   │   ├── users/            # User model, auth
│   │   ├── validation/       # Naive Bayes, consensus (nearby count)
│   │   ├── notifications/    # User notifications
│   │   └── system_logs/      # Audit logs, MDRRMO user management
│   ├── core/                 # Permissions, utils, mock_loader
│   ├── reports/              # Proximity/distance utilities
│   ├── manage.py
│   └── requirements.txt
└── mobile/                   # Flutter app
    ├── lib/
    │   ├── core/             # Config, API client, storage
    │   ├── features/          # Auth, routing, hazards, residents, admin
    │   ├── models/
    │   ├── data/             # Mock data
    │   └── ui/               # Screens (map, login, admin, notifications, etc.)
    ├── android/, ios/, ...
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
- Set `baseUrl` to your backend (e.g. `http://localhost:8000/api` for web, `http://10.0.2.2:8000/api` for Android emulator).

The app uses **token authentication** for protected endpoints (e.g. report hazard, calculate route, notifications). Log in as resident or MDRRMO to use those features.

---

## API overview

All endpoints are under `http://127.0.0.1:8000/api/`. Token auth required where noted.

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/evacuation-centers/` | No | List evacuation centers |
| GET | `/bootstrap-sync/` | No | Sync centers, baseline hazards |
| POST | `/auth/login/` | No | Login (email + password) |
| POST | `/auth/register/` | No | Register with verification |
| GET | `/auth/profile/` | Token | Current user profile |
| POST | `/report-hazard/` | Token | Submit hazard report |
| GET | `/my-reports/` | Token | Current user's reports |
| DELETE | `/my-reports/<id>/` | Token | Delete own pending report |
| GET | `/verified-hazards/` | No | Approved reports (for map) |
| POST | `/calculate-route/` | Token | Get up to 3 risk-weighted routes |
| GET | `/notifications/` | Token | List notifications |
| GET | `/notifications/unread-count/` | Token | Unread count |
| GET | `/mdrrmo/dashboard-stats/` | Token (MDRRMO) | Dashboard stats, hazard distribution, recent activity |
| GET | `/mdrrmo/pending-reports/` | Token (MDRRMO) | Pending reports |
| GET | `/mdrrmo/rejected-reports/` | Token (MDRRMO) | Rejected reports |
| POST | `/mdrrmo/approve-report/` | Token (MDRRMO) | Approve or reject report |
| POST | `/mdrrmo/restore-report/` | Token (MDRRMO) | Restore rejected report |
| DELETE | `/mdrrmo/reports/<id>/` | Token (MDRRMO) | Delete approved/rejected report |
| GET | `/mdrrmo/users/` | Token (MDRRMO) | List users (filter by barangay, status, search) |

---

## Routing behavior

- **Backend (real API):** Route calculation uses **RoadSegment** records and **Modified Dijkstra**. Run `python manage.py load_mock_data` to load the mock road network and segment risk scores; otherwise the graph is empty and no routes are returned.
- **Mobile mock mode:** When `useMockData = true`, the app can use OSRM for route geometry; with `useMockData = false`, routes come from the backend only.
- Routing does **not** use resident hazard reports or MDRRMO baseline hazards to build the graph; it uses only the road network and per-segment risk (from Random Forest / mock training).

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

- **Backend:** `backend/config/settings.py` (DEBUG, SECRET_KEY, database, MOCK_DATA_DIR). Use environment variables or a local `.env` for secrets.
- **Mobile:** `mobile/lib/core/config/api_config.dart` (baseUrl, useMockData, timeouts).

---

## Documentation

- **[backend/README.md](backend/README.md)** — Backend setup, commands, tests.
- **[mobile/README.md](mobile/README.md)** — Mobile app structure, dependencies, run instructions.

---

## Thesis context

This repository supports a thesis on **AI-powered mobile evacuation route recommendation** for Bulan, Sorsogon, combining:

- Risk-weighted pathfinding (Modified Dijkstra on road segments)
- Machine learning for report validation (Naive Bayes) and road segment risk (Random Forest)
- Resident hazard reporting and MDRRMO verification workflow
- Offline-capable mobile client with cached data

---

## License

This project is for academic (thesis) use. See repository or author for terms.
