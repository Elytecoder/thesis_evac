# Backend – Folder Structure, Models, Services, Endpoints

## Folder structure

```
backend/
│
├── config/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   ├── asgi.py
│   └── wsgi.py
│
├── apps/
│   ├── users/
│   │   ├── models.py
│   │   ├── serializers.py (none; used via auth)
│   │   ├── views.py (optional)
│   │   ├── urls.py (optional)
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── services/ (none)
│   │   └── tests/
│   │
│   ├── evacuation/
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── services/ (none)
│   │   └── tests/
│   │
│   ├── hazards/
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── services/ (none; logic in validation + mobile_sync)
│   │   └── tests/
│   │
│   ├── validation/
│   │   ├── models.py (no own models)
│   │   ├── apps.py
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── naive_bayes.py
│   │   │   └── consensus.py
│   │   └── tests/
│   │
│   ├── risk_prediction/
│   │   ├── models.py (no own models)
│   │   ├── apps.py
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   └── random_forest.py
│   │   └── tests/
│   │
│   ├── routing/
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   └── dijkstra.py
│   │   └── tests/
│   │
│   └── mobile_sync/
│       ├── models.py (none)
│       ├── serializers.py (none; uses other apps’ serializers)
│       ├── views.py
│       ├── urls.py
│       ├── apps.py
│       ├── services/
│       │   ├── __init__.py
│       │   ├── report_service.py
│       │   ├── route_service.py
│       │   └── bootstrap_service.py
│       ├── management/commands/
│       │   ├── load_mock_data.py
│       │   └── seed_evacuation_centers.py
│       └── tests/
│
├── core/
│   ├── permissions/
│   │   ├── __init__.py
│   │   └── mdrrmo.py
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── geo.py
│   │   └── mock_loader.py
│   └── constants/
│       └── __init__.py
│
├── mock_data/
│   ├── mock_hazards.json
│   ├── mock_road_network.json
│   └── mock_training_data.json
│
├── manage.py
├── requirements.txt
├── README.md
├── REAL_DATA_INTEGRATION_GUIDE.md
└── FOLDER_STRUCTURE.md (this file)
```

---

## Models

| App        | Model             | Main fields |
|-----------|-------------------|-------------|
| **users** | User              | role (resident, mdrrmo), username, password, is_active |
| **evacuation** | EvacuationCenter | name, latitude, longitude, address, description |
| **hazards** | BaselineHazard  | hazard_type, latitude, longitude, severity, source="MDRRMO", created_at |
| **hazards** | HazardReport    | user, hazard_type, latitude, longitude, description, photo_url, status, naive_bayes_score, consensus_score, created_at |
| **routing** | RoadSegment    | start_lat, start_lng, end_lat, end_lng, base_distance, predicted_risk_score |
| **routing** | RouteLog       | user, evacuation_center, selected_route_risk, created_at |

---

## Services

| Module | Service / class | Purpose |
|--------|------------------|--------|
| **validation/services/naive_bayes.py** | NaiveBayesValidator | Train on mock (or real) data; `validate_report(report_data)` → probability score |
| **validation/services/consensus.py** | ConsensusScoringService | Count reports within radius; combine with Naive Bayes → consensus score |
| **risk_prediction/services/random_forest.py** | RoadRiskPredictor | Train on segment features; predict risk; store in RoadSegment.predicted_risk_score |
| **routing/services/dijkstra.py** | ModifiedDijkstraService | Graph weight = distance + risk×multiplier; return 3 safest routes; risk level Green/Yellow/Red |
| **core/utils/geo.py** | haversine_meters, within_radius | Distance and proximity helpers |
| **core/utils/mock_loader.py** | load_baseline_hazards, load_road_network | Load mock JSON into DB (replace with MDRRMO import) |
| **mobile_sync/services/report_service.py** | process_new_report | Create report → Naive Bayes → Consensus → save |
| **mobile_sync/services/route_service.py** | calculate_safest_routes | Build graph, run Dijkstra, return 3 routes |
| **mobile_sync/services/bootstrap_service.py** | get_bootstrap_data | Evacuation centers + baseline hazards for mobile cache |

---

## API endpoints (JSON only)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST   | /api/report-hazard/ | Token | Submit crowdsourced hazard report (runs NB + consensus) |
| GET    | /api/evacuation-centers/ | Any | List evacuation centers |
| POST   | /api/calculate-route/ | Token | Body: start_lat, start_lng, evacuation_center_id → 3 safest routes + risk level |
| GET    | /api/mdrrmo/pending-reports/ | Token + MDRRMO | List pending hazard reports |
| POST   | /api/mdrrmo/approve-report/ | Token + MDRRMO | Body: report_id, action (approve\|reject) |
| GET    | /api/bootstrap-sync/ | Any | Evacuation centers + baseline hazards for mobile cache |

---

## How to run the server

```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py load_mock_data
python manage.py seed_evacuation_centers
python manage.py runserver
```

- Create a superuser (optional): `python manage.py createsuperuser`
- Get a token for a user: use Django admin or the authtoken API to create a token; send `Authorization: Token <key>` for protected endpoints.
