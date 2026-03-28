# Thesis Evacuation System — Folder Structure

This document maps the **thesis_evac** repository: where the **database**, **algorithms**, **API**, **mobile app**, and **documentation** live.

---

## Top level

| Path | Purpose |
|------|---------|
| **`README.md`** | Project overview, install, API summary, links |
| **`backend/`** | Django REST API, database file, ML/routing logic |
| **`mobile/`** | Flutter app (residents + MDRRMO) |
| **`docs/`** | Specifications, algorithms, diagrams, **this file** |
| **`archive_unused_files/`** | Historical notes (not part of the active app) |
| **`render.yaml`** | Optional Render.com blueprint (backend service) |

---

## Database

| What | Where |
|------|--------|
| **SQLite file (default)** | `backend/db.sqlite3` |
| **Django settings** | `backend/config/settings.py` → `DATABASES['default']` points to `BASE_DIR / 'db.sqlite3'` |
| **ORM models** | Under each Django app’s `models.py` (see below) |

**Note:** Production deployments may switch to PostgreSQL by changing `DATABASES` in `settings.py` (or via environment-driven settings). Migrations live in each app’s `migrations/` folder.

### Models by app (tables)

| App | `models.py` | Main entities |
|-----|-------------|---------------|
| `apps.users` | `users/models.py` | `User` (residents / MDRRMO), `EmailVerificationCode` |
| `apps.hazards` | `hazards/models.py` | `HazardReport`, `BaselineHazard` |
| `apps.evacuation` | `evacuation/models.py` | `EvacuationCenter` |
| `apps.routing` | `routing/models.py` | `RoadSegment` (graph edges for routing) |
| `apps.risk_prediction` | *(no separate tables)* | Random Forest updates **`RoadSegment.predicted_risk_score`** in `routing` |
| `apps.notifications` | `notifications/models.py` | `Notification` |
| `apps.system_logs` | `system_logs/models.py` | `SystemLog` |
| `apps.validation` | *(no separate tables)* | Naive Bayes + consensus live in **`validation/services/`** |

---

## Algorithms & ML (backend)

| Algorithm / logic | Primary location | Role |
|-------------------|------------------|------|
| **Modified Dijkstra** (risk-weighted shortest paths) | `backend/apps/routing/services/dijkstra.py` — class `ModifiedDijkstraService` | Builds routes on the road graph |
| **Route orchestration** (multiple routes, risk labels, OSRM-style response shaping) | `backend/apps/mobile_sync/services/route_service.py` | Calls Dijkstra, combines “safest” vs “shortest” runs, evaluation metadata |
| **Naive Bayes** (hazard report score) | `backend/apps/validation/services/naive_bayes.py` — `NaiveBayesValidator` | `P(valid \| features)`; features include hazard type, description length bucket, distance category, nearby-report category |
| **Nearby reports / “consensus” features** | `backend/apps/validation/services/consensus.py` — `ConsensusScoringService` | Counts nearby similar reports for NB input |
| **Report pipeline** (distance rule → nearby count → NB → save scores) | `backend/apps/mobile_sync/services/report_service.py` — `process_new_report` | End-to-end when a resident submits a report |
| **Proximity / auto-reject (>1 km)** | `backend/apps/hazards/proximity_validation.py` | Used from `report_service` |
| **Random Forest** (road segment risk) | `backend/apps/risk_prediction/services/random_forest.py` — `RoadRiskPredictor` | Predicted risk per segment; used in routing cost |
| **Mock training data (NB / RF)** | `backend/mock_data/` (e.g. `mock_training_data.json`) | Referenced by validators / loaders |

**Tests:** `backend/apps/routing/tests/test_dijkstra.py`, `backend/apps/validation/tests/`, `backend/apps/risk_prediction/tests/`.

---

## API layer (Django)

| Area | Location |
|------|----------|
| **Root URL includes** | `backend/config/urls.py` |
| **Settings, middleware, CORS** | `backend/config/settings.py`, `backend/config/middleware.py` |
| **Auth (login, register, profile)** | `backend/apps/users/views.py`, `users/urls.py`, `users/serializers.py` |
| **Mobile-facing API** (report hazard, verified hazards, MDRRMO reports, bootstrap, calculate route, evacuation centers) | `backend/apps/mobile_sync/views.py`, `mobile_sync/urls.py` |
| **MDRRMO user management** | `backend/apps/system_logs/views.py`, `system_logs/urls.py` — `GET/POST/DELETE` under `/api/users/` and legacy `/api/mdrrmo/users/` |
| **Notifications** | `backend/apps/notifications/` |
| **Hazard media uploads** | `backend/apps/hazards/hazard_media.py` (used from report flow); `MEDIA_*` in `settings.py` |

---

## Core utilities (backend)

| Path | Purpose |
|------|---------|
| `backend/reports/` | Management commands (e.g. cleanup rejected reports), shared report utilities |
| `backend/core/permissions/mdrrmo.py` | `IsMDRRMO` permission |
| `backend/core/utils/` | Shared helpers |
| `backend/core/utils/mock_loader.py` | Loading mock hazards into DB |
| `backend/apps/mobile_sync/management/commands/load_mock_data.py` | **Road network + risks** — required for routing in dev |
| `backend/apps/mobile_sync/management/commands/seed_evacuation_centers.py` | Sample centers |

---

## Mobile app (Flutter)

| Path | Purpose |
|------|---------|
| `mobile/lib/main.dart` | Entry point |
| `mobile/lib/core/config/api_config.dart` | **Base URL**, `useMockData`, timeouts (important for Render cold start) |
| `mobile/lib/core/network/api_client.dart` | Dio client, auth header, errors |
| `mobile/lib/core/auth/session_storage.dart` | Token persistence (web vs mobile secure storage) |
| `mobile/lib/features/authentication/` | Login, register, profile |
| `mobile/lib/features/hazards/` | Hazard reporting, lists |
| `mobile/lib/features/routing/` | Route requests to backend |
| `mobile/lib/features/evacuation/` | Evacuation center CRUD (MDRRMO) |
| `mobile/lib/features/admin/` | MDRRMO services (dashboard, users, logs, mocks) |
| `mobile/lib/models/` | Dart models (`User`, `HazardReport`, `EvacuationCenter`, …) |
| `mobile/lib/ui/screens/` | Resident UI (map, login, settings, …) |
| `mobile/lib/ui/admin/` | MDRRMO tabs (dashboard, reports, users, centers, …) |
| `mobile/lib/ui/widgets/` | Shared widgets |

---

## Documentation (`docs/`)

| File | Topic |
|------|--------|
| **`FOLDER_STRUCTURE.md`** | This guide |
| `SRS_Software_Requirements_Specification.md` | Requirements |
| `Test_Case_Document.md` | Test cases |
| `Algorithms_How_They_Work.md` | Algorithm narrative |
| `algorithm-workflow.md` | Workflow |
| `class_diagram_mermaid.md`, `class_diagram_verification.md` | Diagrams |

**Root-level `*.md` files** (e.g. `COMPLETE_SYSTEM_DOCUMENTATION.md`, `BACKEND_GUIDE_AND_ALGORITHMS.md`) are extra thesis/project notes; the **canonical quick start** is the root **`README.md`**.

---

## Quick “where do I change…?”

| Task | Go to |
|------|--------|
| Change API URL / timeouts in the app | `mobile/lib/core/config/api_config.dart` |
| Change DB engine or name | `backend/config/settings.py` |
| Tune NB or training data | `backend/apps/validation/services/naive_bayes.py`, `backend/mock_data/` |
| Tune routing / Dijkstra weights | `backend/apps/routing/services/dijkstra.py`, `route_service.py` |
| Add a REST endpoint | Relevant app’s `views.py` + `urls.py` (often `mobile_sync` or `system_logs`) |
| Add a DB table | App’s `models.py` → `python manage.py makemigrations` → `migrate` |
| MDRRMO user list API | `system_logs/views.py` (`list_users`) |

---

*Last updated to reflect the repository layout and main algorithm locations. If you move modules, update this file together with the root `README.md`.*
