# AI-Powered Evacuation Routing Application

A full-stack system for **intelligent evacuation route recommendation** using machine learning and risk-weighted routing. Built for **Bulan, Sorsogon, Philippines** — a mobile app for residents and an admin backend for MDRRMO (Municipal Disaster Risk Reduction and Management Office).

---

## Overview

This project provides:

- **Mobile app (Flutter)** — Residents view evacuation centers on a map, get multiple route options with risk levels (Green / Yellow / Red), report hazards with photo/video, and use the app offline with cached data.
- **Backend API (Django REST)** — Evacuation centers, risk-weighted route calculation (Dijkstra + OSRM), hazard report submission, ML-based report validation (Naive Bayes, Random Forest, consensus), and MDRRMO admin workflows.

The system uses **OpenStreetMap** for map tiles and road data, **OSRM** for real road-following routes, and **SQLite** (development) for the backend database.

---

## Features

### Mobile app

| Feature | Description |
|--------|-------------|
| **Map & location** | OpenStreetMap tiles, user GPS, evacuation center markers |
| **Evacuation centers** | List and map of centers; select one to get routes |
| **Route options** | Up to 3 routes per destination with risk levels (Green / Yellow / Red) |
| **Hazard reporting** | Submit reports with type, location, description, photo/video |
| **Offline support** | Hive cache for centers, routes, and baseline hazards |
| **Authentication** | Login, register, role-based (resident / MDRRMO) |
| **Admin (MDRRMO)** | Dashboard, pending reports, approve/comment, evacuation center management |

### Backend API

| Feature | Description |
|--------|-------------|
| **Evacuation centers** | CRUD, list, filter by status/barangay |
| **Route calculation** | Risk-weighted Dijkstra; OSRM for road geometry; returns 3 alternatives |
| **Hazard reports** | Submit report; Naive Bayes + consensus + Random Forest risk scores |
| **Bootstrap sync** | One-call sync of centers, baseline hazards, road network for offline use |
| **MDRRMO** | Pending reports, approve/reject, admin comment |
| **Django admin** | Full admin at `/admin/` for users, centers, reports, road segments |

### Algorithms & ML

- **Modified Dijkstra** — Shortest path with risk-weighted edge costs.
- **Naive Bayes** — Hazard report validation (authenticity score).
- **Random Forest** — Road segment risk prediction.
- **Consensus algorithm** — Aggregates multiple reports for the same area.

---

## Tech stack

| Layer | Technologies |
|-------|--------------|
| **Mobile** | Flutter 3.x, Dart; flutter_map, geolocator, dio, hive, image_picker |
| **Backend** | Python 3.10+, Django 4.2+, Django REST Framework |
| **Database** | SQLite (dev); PostgreSQL recommended for production |
| **Maps & routing** | OpenStreetMap tiles, OSRM API |
| **ML** | scikit-learn (Naive Bayes, Random Forest), NumPy, Pandas |

For a full list of tools, versions, and rationale see **[COMPLETE_TECH_STACK.md](COMPLETE_TECH_STACK.md)**.

---

## Repository structure

```
thesis_evac/
├── README.md                 # This file
├── COMPLETE_TECH_STACK.md    # Detailed tech stack
├── backend/                  # Django API
│   ├── config/               # Settings, URLs
│   ├── apps/
│   │   ├── evacuation/       # Evacuation centers
│   │   ├── hazards/          # Hazard reports, baseline hazards
│   │   ├── mobile_sync/      # Mobile API (bootstrap, routes, report)
│   │   ├── risk_prediction/  # Random Forest risk model
│   │   ├── routing/          # Road segments, Dijkstra
│   │   ├── users/            # User model, auth
│   │   └── validation/       # Naive Bayes, consensus
│   ├── core/                 # Permissions, utils
│   ├── manage.py
│   └── requirements.txt
└── mobile/                   # Flutter app
    ├── lib/
    │   ├── core/             # Config, API client, storage
    │   ├── features/          # Auth, routing, hazards services
    │   ├── models/
    │   ├── data/             # Mock data
    │   └── ui/               # Screens (map, login, admin, etc.)
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
python manage.py load_mock_data
python manage.py seed_evacuation_centers
python manage.py runserver
```

- **API base:** http://127.0.0.1:8000/api/
- **Admin:** http://127.0.0.1:8000/admin/  
  Create a superuser: `python manage.py createsuperuser`

### 3. Mobile app (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

Use an emulator or a connected device. For Android, ensure location permission is granted.

### 4. Point the app at your backend (optional)

If the backend runs on a different host/port, update the API base URL in the app (e.g. in `mobile/lib/core/config/api_config.dart` or equivalent) so the app uses the real API instead of mock data.

---

## API overview

All endpoints are under `http://127.0.0.1:8000/api/`. Authentication is token-based where required.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/evacuation-centers/` | List evacuation centers |
| POST | `/api/calculate-route/` | Get up to 3 risk-weighted routes (start + center id) |
| POST | `/api/report-hazard/` | Submit hazard report (with optional media) |
| GET | `/api/bootstrap-sync/` | Sync centers, hazards, road network for offline use |
| GET | `/api/mdrrmo/pending-reports/` | List pending reports (MDRRMO) |
| POST | `/api/mdrrmo/approve-report/` | Approve or reject report (MDRRMO) |

---

## Testing

### Backend

About **83 automated tests** cover models, algorithms, and APIs:

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

Run the app on a device/emulator for manual and integration testing.

---

## Configuration

- **Backend:** Environment variables and `backend/config/settings.py` (e.g. `DEBUG`, `SECRET_KEY`, database). No `.env` is committed; use a local `.env` or env vars for secrets.
- **Mobile:** API base URL and feature flags in `mobile/lib/core/config/` (e.g. mock vs real API).
- **OSRM:** Backend uses the public OSRM service by default; for production you can point to your own OSRM instance.

---

## Documentation

- **[backend/README.md](backend/README.md)** — Backend setup, commands, tests.
- **[mobile/README.md](mobile/README.md)** — Mobile app structure, dependencies, run instructions.
- **[COMPLETE_TECH_STACK.md](COMPLETE_TECH_STACK.md)** — Full tech stack, algorithms, and architecture.

---

## Thesis context

This repository supports a thesis on **AI-powered mobile evacuation route recommendation** for Bulan, Sorsogon, combining:

- Risk-weighted pathfinding (Dijkstra)
- Machine learning for hazard validation and road risk (Naive Bayes, Random Forest, consensus)
- Integration with OSM/OSRM for real road networks and route geometry
- Offline-capable mobile client for use in low-connectivity scenarios

---

## License

This project is for academic (thesis) use. See repository or author for terms.
