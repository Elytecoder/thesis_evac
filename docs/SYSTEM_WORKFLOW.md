# HAZNAV — Full System Workflow

**Document Version:** 1.1  
**Date:** April 2026  
**Project:** HAZNAV — Hazard-Aware Evacuation Navigator for Bulan, Sorsogon  
**Stack:** Django 5 (backend) · Flutter 3 (mobile) · SQLite · OSRM (turn hints)

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [User Roles](#3-user-roles)
4. [Authentication & Registration](#4-authentication--registration)
5. [Hazard Reporting Workflow](#5-hazard-reporting-workflow)
6. [Hazard Validation Pipeline](#6-hazard-validation-pipeline)
7. [MDRRMO Review Workflow](#7-mdrrmo-review-workflow)
8. [Hazard Confirmation by Residents](#8-hazard-confirmation-by-residents)
9. [Map Display & Hazard Visibility Rules](#9-map-display--hazard-visibility-rules)
10. [Road Segment Risk Scoring](#10-road-segment-risk-scoring)
11. [Route Calculation — Modified Dijkstra](#11-route-calculation--modified-dijkstra)
12. [Live Navigation](#12-live-navigation)
13. [Offline Mode & Sync](#13-offline-mode--sync)
14. [Evacuation Center Management](#14-evacuation-center-management)
15. [Notifications](#15-notifications)
16. [Analytics Dashboard](#16-analytics-dashboard)
17. [System Logs](#17-system-logs)
18. [Data Integrity Rules](#18-data-integrity-rules)
19. [API Endpoint Reference](#19-api-endpoint-reference)
20. [End-to-End Data Flow](#20-end-to-end-data-flow)

---

## 1. System Overview

The system is a mobile-first evacuation route advisory tool designed for the residents and MDRRMO (Municipal Disaster Risk Reduction and Management Office) of **Bulan, Sorsogon, Philippines**. Its core purpose is to:

- Allow residents to **report road hazards** in real time (floods, landslides, fallen trees, road blockages, etc.)
- **Validate** those reports automatically using machine learning (Naïve Bayes + consensus scoring)
- Allow MDRRMO personnel to **review, approve, or reject** reports
- Use approved hazard data to **calculate the safest evacuation route** from a resident's location to an operational evacuation center using a **Modified Dijkstra algorithm** backed by a **Random Forest** risk predictor
- **Guide residents through live turn-by-turn navigation** along that hazard-aware route
- Function **partially offline** — queuing reports and serving cached data when connectivity is unavailable

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   Flutter Mobile App                        │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────┐ │
│  │  Resident UI  │  │   MDRRMO UI    │  │  Shared/Core    │ │
│  │  MapScreen    │  │  Dashboard     │  │  ApiClient      │ │
│  │  ReportHazard │  │  PendingReports│  │  StorageService │ │
│  │  LiveNav      │  │  Analytics     │  │  SyncService    │ │
│  │  Settings     │  │  UserMgmt      │  │  ConnectService │ │
│  └──────────────┘  └────────────────┘  └─────────────────┘ │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS (REST / JSON + Token Auth)
┌───────────────────────────▼─────────────────────────────────┐
│               Django 5 REST API  (Render / Local)           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐  │
│  │  users   │ │  hazards │ │ routing  │ │ mobile_sync   │  │
│  │  auth    │ │  reports │ │ segments │ │ views/services│  │
│  │  profile │ │  confirm │ │ route log│ │ report_service│  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐  │
│  │validation│ │evacuation│ │notificat.│ │ system_logs   │  │
│  │naive_bayes│ │ centers │ │  model   │ │  background   │  │
│  │consensus │ │  CRUD    │ │          │ │  thread log   │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────────┘  │
│                      SQLite  db.sqlite3                      │
└─────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────▼──────────────┐
              │  OSRM  (external service)  │
              │  turn-by-turn hints only   │
              └────────────────────────────┘
```

**Key design principles:**
- All business logic lives in the **Django backend** — the Flutter app is a thin client
- The **backend Modified Dijkstra route is authoritative** in navigation; OSRM only provides turn-instruction text
- Hazard data flows: submitted → auto-scored → MDRRMO-reviewed → approved → feeds routing engine
- The system is **offline-tolerant**: reports are queued locally; evacuation centers and verified hazards are cached at launch

---

## 3. User Roles

| Role | Access | Description |
|------|--------|-------------|
| **Resident** | Map, hazard reporting, route calculation, live navigation, notifications, profile settings | Standard end-user; submits and confirms hazard reports, requests evacuation routes |
| **MDRRMO** | All resident features + admin dashboard, report management, evacuation center CRUD, user management, analytics, system logs | Authorized disaster office personnel; reviews reports and manages the system |

Role assignment is done server-side. A user cannot self-escalate to MDRRMO.

---

## 4. Authentication & Registration

### 4.1 Registration Flow (Residents only)

```
Resident enters email ──► POST /api/auth/send-verification-code/
                           Server sends 6-digit OTP via Brevo email API
                           Code expires in 5 minutes
                           ▼
Resident fills form  ──► POST /api/auth/register/
(email, password ×2,      Server validates:
 full_name,                 • OTP correct + unused + not expired
 province/municipality/     • Email not already registered
 barangay/street,           • Password ≥ 8 chars, upper+lower+digit
 verification_code)         • Full name: letters only, 2–60 chars
                            • Address fields required
                           ▼
                       Account created (is_active=True, email_verified=True)
                       Token returned → stored in FlutterSecureStorage
                       → Navigate to MapScreen
```

- MDRRMO accounts are created server-side; they cannot register through the app
- Username is auto-generated from the email prefix (de-duped with counter suffix)
- Each user has a **public_display_id** (unique 6-digit non-sequential number) for safe MDRRMO display

### 4.2 Login Flow

```
POST /api/auth/login/  { email, password }
  ▼
Server checks:
  • email_verified = True
  • is_active = True
  • is_suspended = False
  • password correct
  ▼
Returns { user: {...}, token: "abc..." }
  ▼
Flutter stores token → subsequent requests send Authorization: Token <token>
```

### 4.3 Session Management

- `ApiClient.onUnauthorized` — if any request returns 401, session is cleared and the app navigates to `WelcomeScreen`
- `keepLoggedIn=true` by default; session token persists across app restarts
- Logout: `POST /api/auth/logout/` deletes the token server-side

### 4.4 Profile Management

- Residents can update only their **street** field (address barangay/province cannot change after registration)
- Password change: `POST /api/auth/change-password/` — issues a new token
- Account deletion: `POST /api/auth/delete-account/` — residents only; MDRRMO accounts blocked

---

## 5. Hazard Reporting Workflow

### 5.1 Submitting a Report

A resident taps **"Report Hazard"** on the map screen:

```
1. App collects:
   • hazard_type  (flood, landslide, fallen_tree, road_blocked,
                   bridge_damage, road_damage, storm_surge,
                   fallen_electric_post, etc.)
   • latitude / longitude  (pinned on map)
   • description  (optional text)
   • photo        (optional — JPEG, compressed, stored as base64 data URL in DB)
   • user_latitude / user_longitude  (current GPS position — REQUIRED)

2. Offline check:
   • ConnectivityService detects no connection
   → Report serialized to local Hive queue
   → Shown to resident as "Pending (offline)" on their map
   → SyncService submits when connection restores

3. Online path:
   POST /api/report-hazard/
   Content-Type: application/json  OR  multipart/form-data
   
   Server validates:
   • user_latitude and user_longitude must be present (HTTP 400 otherwise)
   • hazard_type must be a valid choice
   • latitude / longitude must be valid floats
```

### 5.2 Automatic Distance Rejection

Immediately after the report is received, the server measures the **Haversine distance** between the **hazard pin** (latitude/longitude) and the **reporter's GPS location** (user_latitude/user_longitude):

```
distance_m = haversine(user_lat, user_lng, hazard_lat, hazard_lng)

IF distance_m > 150 m:
    report.status       = PENDING
    report.auto_rejected = True
    report.admin_comment = "Auto-rejected: reporter too far from hazard location"
    Save and RETURN early — no validation scores, no MDRRMO queue
```

This enforces the **eyewitness rule**: only those physically near a hazard can report it.

### 5.3 Report after Submission

```
Resident's view after submission:
• Report appears on their map with a yellow pin (pending)
• Only their own PENDING reports are shown on the resident map
• APPROVED reports from all users appear as colored markers for all users
• REJECTED / deleted reports are hidden from the resident map
```

---

## 6. Hazard Validation Pipeline

For reports that pass the distance check, the server runs three validation layers automatically:

### 6.1 Naïve Bayes Scorer (Text Credibility)

```
Input:  hazard_type  +  description text
Output: naive_bayes_score ∈ [0, 1]

Primary path (sklearn):
  CountVectorizer (bigrams, min_df=2) + MultinomialNB (alpha=0.5)
  → trained on synthetic mock_training_data.json
  → predicts P(credible | text)

Fallback (manual Bayes):
  Prior P(credible | hazard_type) × P(description_length_bucket)
  from the same training data, computed manually
  (activates if sklearn model unavailable)
```

**What NB evaluates:** plausibility of the text description given the hazard type  
**What NB ignores:** distance, confirmations, nearby reports — those are handled separately

### 6.2 Distance Weight (Reporter Proximity)

```
distance_weight = 1 - (distance_m / 150)   clamped to [0, 1]

reporter_at_hazard  (0 m)   → weight = 1.00  (very credible)
reporter_75 m away          → weight = 0.50
reporter_149 m away         → weight = 0.007
reporter_≥150 m away        → AUTO-REJECTED before this point
```

### 6.3 Consensus Scoring (Nearby Corroboration)

```
nearby_reports = HazardReport.objects.filter(
    hazard_type = same type,
    status IN [PENDING, APPROVED],
    location WITHIN 100 m,
    created_at WITHIN last 1 hour,
    id != this report          # exclude self
)
confirmations = HazardConfirmation count for this report

consensus_score = min((nearby_count + confirmations) / 5, 1.0)
```

### 6.4 Combined Final Score

```
final_validation_score =
    0.5 × naive_bayes_score
  + 0.3 × distance_weight
  + 0.2 × consensus_score
                                           clamped to [0, 1]
```

All four scores are saved on the `HazardReport` record. A human-readable `validation_breakdown` JSON and an explanation text (for MDRRMO) are also saved.

### 6.5 Score Interpretation (MDRRMO Guidance)

| Final Score | Tier | Guidance |
|-------------|------|----------|
| ≥ 0.75 | HIGH credibility | Likely genuine — fast-track approval |
| 0.50–0.74 | MEDIUM credibility | Requires review |
| < 0.50 | LOW credibility | Scrutinize carefully; may be false alarm |

Reports remain **PENDING** until MDRRMO manually acts on them. The AI scores assist human judgment — they do not auto-approve.

---

## 7. MDRRMO Review Workflow

### 7.1 Pending Queue

`GET /api/mdrrmo/pending-reports/`

MDRRMO sees all pending reports sorted by submission time. Each entry shows:
- Hazard type, location, description, photo
- Reporter's public_display_id (6-digit reference — no personally identifiable info)
- Submission timestamp (converted to Philippine time — Asia/Manila)
- All four validation scores + explanation text

### 7.2 Approving / Rejecting

```
POST /api/mdrrmo/approve-report/
Body: { report_id, action: "approve"|"reject", admin_comment? }

On APPROVE:
  report.status = APPROVED
  → Hazard now visible on the public map
  → Hazard feeds the routing engine (Dijkstra + RF risk)
  → Notification created: type=REPORT_APPROVED sent to reporter
  → SystemLog written

On REJECT:
  report.status = REJECTED
  report.admin_comment = reason text
  → Report hidden from public map
  → Notification created: type=REPORT_REJECTED sent to reporter
  → SystemLog written
```

### 7.3 Restoring a Rejected Report

```
POST /api/mdrrmo/restore-report/  { report_id }
  → report.status = PENDING (re-enters review queue)
  → restoration fields updated
  → Notification: type=RESTORED sent to reporter
```

### 7.4 Deleting a Report

```
DELETE /api/mdrrmo/reports/<id>/
  Soft-delete: report.is_deleted = True, report.deleted_at = now
  (Only non-PENDING reports can be deleted this way)
  → Report excluded from all queries
  → Routing engine ignores soft-deleted reports
```

---

## 8. Hazard Confirmation by Residents

Other residents who observe a reported hazard can confirm it:

```
POST /api/confirm-hazard-report/  { report_id }
  ▼
Server creates HazardConfirmation(report, user) — unique pair
  ▼
Recalculates consensus_score:
  consensus_score = min((nearby_count + new_confirmation_count) / 5, 1.0)
  ▼
Recalculates final_validation_score:
  0.5×NB + 0.3×distance + 0.2×new_consensus
  ▼
Saves updated scores on report
```

Prior to confirming, the app calls:
```
POST /api/check-similar-reports/  { hazard_type, latitude, longitude, radius_meters? }
→ Returns list of nearby reports of the same type
→ UI shows "X similar reports nearby" — user selects which to confirm
```

---

## 9. Map Display & Hazard Visibility Rules

| Scenario | What the resident sees |
|----------|------------------------|
| Their own PENDING report | Yellow marker (own pin) |
| Their own REJECTED report | Hidden |
| Any APPROVED report | Colored marker by hazard type |
| Soft-deleted report | Hidden |
| Auto-rejected report | Hidden |

MDRRMO sees all pending reports in their management dashboard, not on the resident map.

Approved hazard markers are **clickable** — tapping shows: hazard type, description, photo (if any), timestamp.

---

## 10. Road Segment Risk Scoring

### 10.1 Road Graph

The road network for Bulan, Sorsogon is stored as **3,247 directed `RoadSegment` edges** in the database:

```
RoadSegment:
  start_lat, start_lng, end_lat, end_lng  — Bulan coordinates (~12.66°N, 123.89°E)
  base_distance     — meters
  predicted_risk_score — [0, 1] from Random Forest
  last_updated      — auto-set on save
```

### 10.2 Random Forest Base Risk (Pre-trained, static)

Each segment's `predicted_risk_score` is produced by a **pre-trained Random Forest** model (`random_forest_model.pkl`).  The model is **loaded once at startup** and never retrained during a route request.  Scores are updated explicitly via `python manage.py update_segment_risks` or after model retraining.

The model uses **9 features** computed from **approved, non-deleted hazards** within **200 m** of the segment midpoint (using recency × type-severity weighting, not raw integer counts):

```
RF Features per segment  (source: _compute_segment_rf_features):
  1.  flooded_road_count          (flood + flooded_road hazards within 200 m)
  2.  landslide_count
  3.  fallen_tree_count
  4.  road_damage_count
  5.  fallen_electric_post_count  (fallen_electric_post + fallen_electric_post_wires)
  6.  road_blocked_count          (road_blocked + road_block)
  7.  bridge_damage_count
  8.  storm_surge_count
  9.  avg_severity                (mean final_validation_score of all nearby hazards)

Each type count is weighted by:
  recency_factor   (1.0 < 6 h, 0.8 < 24 h, 0.6 < 3 days, 0.4 < 7 days, 0.2 otherwise)
× type_severity    (normalised HAZARD_TYPE_RISK_WEIGHT — serious types count more)
```

Training data: 300-row **synthetic** dataset (temporary placeholder). Replace with real MDRRMO road incident data and retrain with `python manage.py train_ml_models --rf-only --force`.

### 10.3 Dynamic Hazard Risk (Graduated Influence)

At route calculation time, **approved, non-deleted hazards** are overlaid on the graph in real time using graduated proximity:

#### Per-Hazard Influence Radius and Decay Profile

| Hazard Type | Influence Radius | Decay Profile |
|-------------|-----------------|---------------|
| road_blocked | 25 m | sharp |
| fallen_tree | 15 m | sharp |
| flood | 80 m | gradual |
| storm_surge | 150 m | gradual |
| landslide | 60 m | moderate |
| bridge_damage | 30 m | moderate |
| road_damage | 20 m | moderate |
| fallen_electric_post | 20 m | moderate |
| fallen_electric_post_wires | 45 m | moderate |
| *other* | 40 m | moderate |

#### Decay Profiles

```
sharp    → factor = 1 − t²                (t = distance / radius)
moderate → factor = 1 − t
gradual  → factor = 1 − √t
```

All factors clamped to [0, 1].

#### Impact Calculation per Hazard per Segment

```python
perpendicular_distance, on_segment = _perpendicular_distance_m(
    hazard_lat, hazard_lng,
    segment_start_lat, segment_start_lng,
    segment_end_lat, segment_end_lng
)

IF perpendicular_distance > influence_radius:
    impact = 0  # hazard is too far away

ELSE:
    t = perpendicular_distance / influence_radius
    decay = _decay_factor(t, profile)             # sharp / moderate / gradual

    position_bonus = 1.2 if on_segment else 1.0   # on-road vs beside-road
    severity = hazard.final_validation_score       # AI-scored credibility weight

    type_weight = HAZARD_TYPE_RISK_WEIGHT[hazard_type]

    impact = decay × position_bonus × severity × type_weight
```

#### Road-Blocked Override

```
IF hazard_type ∈ {road_blocked, road_block} AND perpendicular_distance ≤ influence_radius (25 m):
    segment effective_risk = 1.0  (impassable — route will avoid completely)
    skip all other hazards for this segment
```

Note: `fallen_tree` does **not** force impassability; it uses the graduated `sharp` decay profile within its 15 m radius, contributing to dynamic risk but not an automatic full block.

### 10.4 Final Effective Risk per Segment

```
dynamic_risk = sum of all hazard impacts, capped at 1.0

effective_risk = 0.6 × base_predicted_risk  +  0.4 × dynamic_risk
```

---

## 11. Route Calculation — Modified Dijkstra

### 11.1 Trigger

```
Resident taps "Find Evacuation Route" on a selected center
  ▼
POST /api/calculate-route/
Body: { start_lat, start_lng, evacuation_center_id }
```

### 11.2 Graph Construction

```
1. Load all RoadSegment edges from DB
2. Update predicted_risk_score for each segment (RF model)
3. Load all approved, non-deleted HazardReport records
4. For each edge, calculate effective_risk (§10.4)
5. Edge cost = base_distance + effective_risk × 500
```

The **500 multiplier** converts risk [0,1] into a distance-equivalent penalty (a risk-1.0 segment costs 500 m more than its physical length).

### 11.3 K-Alternative Routes (Repeated Dijkstra with Edge Penalties)

The system finds up to **3 distinct route alternatives** by running Modified Dijkstra multiple times — **not** Yen's algorithm:

```
1. Run Dijkstra → best (safest) route found.
2. Penalize all edges used by that route (add PENALTY_VALUE = 500 to each).
3. Run Dijkstra again with penalized edges → second route prefers different paths.
4. Repeat for a third route.
5. Duplicate routes are discarded.
```

The graph is **never mutated** — penalties live in a local dict for this call only.
This produces up to 3 meaningfully different, hazard-aware route options ranked by total risk.

### 11.4 Post-Processing and Risk Labels

```
For each route:
  risk_level = GREEN   if total_risk < 0.3
  risk_level = YELLOW  if 0.3 ≤ total_risk < 0.7
  risk_level = RED     if total_risk ≥ 0.7
```

Special cases:
- If ALL routes have `total_risk ≥ 0.9`: `no_safe_route = True` flag is set
- If no path exists to the selected center: system suggests `alternative_centers` list (nearest other operational centers)

### 11.5 Response Shape

```json
{
  "routes": [
    {
      "path":         [{"latitude": ..., "longitude": ...}, ...],
      "total_distance": 1450.0,
      "total_risk":     0.23,
      "risk_level":    "green",
      "segments":      [...risk per sub-segment...]
    }
  ],
  "no_safe_route": false,
  "alternative_centers": []
}
```

### 11.6 Route Selection Screen

The Flutter app displays the 3 routes with:
- Color-coded risk label (green / yellow / red)
- Estimated distance and walking time
- Number of hazards on path
- Hazard type tags

The resident selects a route → the selected `Route` object (backend polyline) is passed to `LiveNavigationScreen`.

---

## 12. Live Navigation

### 12.1 Route Fidelity Principle

> **The backend Modified Dijkstra route is the authoritative navigation path. OSRM never replaces it.**

| Source | Role |
|--------|------|
| Django Modified Dijkstra | Polyline geometry (route path on map) |
| OSRM | Turn-instruction text only (e.g., "Turn left onto…") |
| OSRM | Full route fallback if no backend route available |

### 12.2 Navigation Start

```
LiveNavigationScreen receives selectedRoute (backend Route object)
  ▼
_calculateRoute():
  IF selectedRoute != null:
    polyline = selectedRoute.path  (backend geometry — not recalculated)
    steps = await _getOsrmStepsOnly(start, destination)
      └─ If OSRM fails: fallback = _generateStepsFromPolyline()
             (analyzes bearing changes along polyline → "Turn left", "Continue")
    segments = _buildSegmentsFromBackendRoute(selectedRoute)
    estimatedTime = totalDistance / 1.4 m/s  (walking speed)
  ELSE:
    route = await calculateSafestRoute()  (OSRM full geometry — offline fallback)
```

### 12.3 GPS Tracking & Compass

`GPSTrackingService` (singleton):
- Streams user **position** from `geolocator` (high accuracy, 5 m displacement threshold)
- Streams **heading** as a blend of:
  - `FlutterCompass.events` (magnetometer) — used when stationary or slow
  - `Position.heading` (GPS course bearing) — used when speed > 0.5 m/s
  - Low-pass filter (α = 0.2) to smooth sudden jumps
  - 2° threshold to suppress noise updates
- The map user-arrow rotates with the fused heading; the **map itself never rotates**

### 12.4 Turn-by-Turn Guidance

```
Each navigation step has:
  instruction    ("Turn left at…")
  distance_to_step_m

App continuously updates distance_to_step from GPS position
  → Visual proximity banner at 50 m
  → Visual imminent banner at 15 m
  → Advance to next step
```

Note: Voice navigation is **not implemented** in the current version. Turn instructions are visual only (top banner).

### 12.5 Rerouting

```
User deviates from route polyline (minimum perpendicular distance > threshold m):
  ▼
_reroute():
  Step 1: POST /api/calculate-route/ from current GPS to destination
          (backend Modified Dijkstra — hazard-aware reroute)
  Step 2: If backend call fails or returns no routes:
          Fallback to OSRM full-route calculation
  ▼
Navigation continues on new route
```

### 12.6 Hazard Display During Navigation

- **Verified (approved) hazards** near the route are displayed as markers on the navigation map
- **Own pending reports** submitted during this session are also shown
- Hazard markers are **tappable** — shows type, description, photo

---

## 13. Offline Mode & Sync

### 13.1 Connectivity Detection

`ConnectivityService` uses `connectivity_plus` to detect network state changes. It broadcasts an `onConnectionChange` stream. The state is derived from `ConnectivityResult` — if all results are `none`, the device is considered offline.

> Note: this detects network connectivity, not true internet reachability (no HTTPS probe).

### 13.2 Offline Banner

When offline, an `OfflineBanner` widget is shown at the top of the screen to indicate that real-time data is unavailable and cached data is in use.

### 13.3 Data Cached at App Launch

On app startup, `SyncService.startListening()` begins and `bootstrap-sync` data is pre-loaded:

| Data | Cache Store |
|------|------------|
| Evacuation centers | Hive (local DB) |
| Verified hazards | Hive (local DB) |
| User token | FlutterSecureStorage |
| User profile | SharedPreferences |

### 13.4 Offline Report Queuing

```
Resident submits hazard while offline:
  ▼
HazardService serializes report → Hive queue (pending_reports key)
  ▼
SyncService.onConnectionChange (online event):
  ▼
_flushPendingReports():
  For each queued report:
    POST /api/report-hazard/
    On success: remove from queue
    On failure: keep in queue, retry next sync cycle
```

### 13.5 Full Sync on Reconnect

```
SyncService._syncAll():
  1. _flushPendingReports()   — submit queued hazard reports
  2. _refreshEvacuationCenters()  — GET /api/evacuation-centers/
  3. _refreshVerifiedHazards()    — GET /api/verified-hazards/
  4. Save last_sync_time to SharedPreferences
```

---

## 14. Evacuation Center Management

### 14.1 Data Model

```
EvacuationCenter:
  name, latitude, longitude
  province, municipality, barangay, street, address
  contact information
  is_operational  (bool — only operational centers are shown to residents)
  deactivated_at  (timestamp)
  description
```

### 14.2 Resident View

`GET /api/evacuation-centers/` returns only `is_operational=True` centers by default.  
Optional: `?include_inactive=true` returns all.

### 14.3 MDRRMO CRUD

| Action | Endpoint |
|--------|----------|
| Create | `POST /api/mdrrmo/evacuation-centers/` |
| Read detail | `GET /api/mdrrmo/evacuation-centers/<id>/` |
| Update | `PUT /api/mdrrmo/evacuation-centers/<id>/update/` |
| Delete | `DELETE /api/mdrrmo/evacuation-centers/<id>/delete/` |
| Deactivate | `POST /api/mdrrmo/evacuation-centers/<id>/deactivate/` |
| Reactivate | `POST /api/mdrrmo/evacuation-centers/<id>/reactivate/` |

Deactivating a center removes it from the resident-facing list and routing options. A `CENTER_DEACTIVATED` notification can be sent to relevant users.

---

## 15. Notifications

### 15.1 Notification Types

| Type | Triggered by | Recipient |
|------|-------------|-----------|
| `REPORT_APPROVED` | MDRRMO approves a report | Report submitter |
| `REPORT_REJECTED` | MDRRMO rejects a report | Report submitter |
| `REPORT_RESTORED` | MDRRMO restores a rejected report | Report submitter |
| `CENTER_DEACTIVATED` | MDRRMO deactivates a center | Affected users |
| `SYSTEM_ALERT` | Admin-triggered broadcast | Specified users |

### 15.2 Notification Model

```
Notification:
  user (FK)
  type
  title, message
  related_object_type, related_object_id  (for deep-linking to report or center)
  is_read, read_at
  metadata (JSON — extra context)
```

### 15.3 Mobile Flow

```
GET /api/notifications/               — fetch all notifications for current user
GET /api/notifications/unread-count/  — badge count
POST /api/notifications/mark-all-read/ — mark all as read
```

Tapping a notification for an approved/rejected report navigates to the location on the map. If the report has since been deleted, a "Report Unavailable" dialog is shown instead of crashing.

---

## 16. Analytics Dashboard

Available to MDRRMO only. `GET /api/mdrrmo/analytics/`

### 16.1 Hazard Type Distribution

```
Source: HazardReport WHERE status=APPROVED AND is_deleted=False
Output: { "flood": 12, "landslide": 3, "fallen_tree": 7, ... }
Displayed as: pie chart with color-coded legend
```

### 16.2 Road Risk Distribution

```
Source: RoadSegment.predicted_risk_score
Output:
  high_risk     = count WHERE score ≥ 0.7
  moderate_risk = count WHERE 0.3 ≤ score < 0.7
  low_risk      = count WHERE score < 0.3
Displayed as: color-coded row summary (Red / Orange / Green)
```

### 16.3 Dashboard Stats

`GET /api/mdrrmo/dashboard-stats/` provides summary cards:

| Metric | Source |
|--------|--------|
| Total reports | Non-deleted, non-auto-rejected |
| Pending reports | Status=PENDING, non-deleted |
| Verified hazards | Status=APPROVED, non-deleted |
| High-risk roads | RoadSegment score ≥ 0.7 |
| Total evacuation centers | All centers |
| Non-operational centers | is_operational=False |
| Recent activity | Last 10 events (submitted/approved/rejected) |

---

## 17. System Logs

All significant actions are logged asynchronously (background thread to avoid blocking API responses) in the `SystemLog` table.

### 17.1 Logged Actions

```
Module:  AUTH, REPORTS, EVACUATION_CENTERS, NAVIGATION, USERS, SYSTEM
Action:  LOGIN, LOGOUT, REGISTER, REPORT_SUBMITTED, REPORT_APPROVED,
         REPORT_REJECTED, ROUTE_CALCULATED, CENTER_CREATED, USER_SUSPENDED, ...
Status:  SUCCESS, FAILURE, WARNING
```

### 17.2 Log Fields

```
user (FK, optional)     user_role, user_name (cached strings)
description             human-readable summary
ip_address, user_agent  from HTTP request headers
related_object_type, related_object_id
metadata (JSON)         extra context
```

### 17.3 MDRRMO Access

```
GET /api/mdrrmo/system-logs/        — paginated log list (MDRRMO only)
POST /api/mdrrmo/system-logs/clear/ — clear old entries
```

---

## 18. Data Integrity Rules

| Rule | Where Enforced |
|------|----------------|
| Reporter must be within 150 m of pinned hazard | `report_service.py` — auto-reject |
| GPS location (user_lat/lng) required to submit | `views.py` — HTTP 400 |
| Only PENDING reports can be resident-deleted | `delete_my_report` view check |
| Only non-PENDING reports can be MDRRMO soft-deleted | `mdrrmo_delete_report` view check |
| Soft-deleted reports excluded from routing & RF training | `_get_approved_hazards()` filter |
| Soft-deleted reports excluded from all resident map queries | `getVerifiedHazards()` filter |
| Hazard confirmations are unique per (report, user) | DB unique constraint on `HazardConfirmation` |
| MDRRMO cannot self-delete account | `delete_account` view blocks role=mdrrmo |
| Backend route polyline is not replaced by OSRM | `RiskAwareRoutingService.buildFromBackendRoute()` |
| Reroute calls backend first; OSRM only on failure | `_reroute()` in `live_navigation_screen.dart` |
| Evacuation center barangay normalized on save | `EvacuationCenter.save()` |
| User barangay normalized on save | `User.save()` |
| 6-digit public IDs are unique and non-sequential | `allocate_unique_six_digit()` utility |
| All timestamps stored in UTC, displayed in Asia/Manila | `USE_TZ=True`, `TIME_ZONE='Asia/Manila'`, `.toLocal()` in Flutter |

---

## 19. API Endpoint Reference

**Base URL:** `https://thesis-evac.onrender.com/api`  
**Authentication:** `Authorization: Token <token>` (all except AllowAny)

### Auth Endpoints (`/auth/`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/send-verification-code/` | None | Send OTP to email |
| POST | `/auth/register/` | None | Register new resident |
| POST | `/auth/login/` | None | Login; returns token |
| POST | `/auth/logout/` | Token | Invalidate token |
| GET | `/auth/profile/` | Token | Get current user |
| PUT | `/auth/profile/update/` | Token | Update street |
| POST | `/auth/change-password/` | Token | Change password |
| POST | `/auth/delete-account/` | Token | Resident self-delete |

### Resident Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/report-hazard/` | Token | Submit hazard report |
| POST | `/check-similar-reports/` | Token | Find nearby same-type reports |
| POST | `/confirm-hazard-report/` | Token | Confirm an existing report |
| GET | `/my-reports/` | Token | Own reports |
| DELETE | `/my-reports/<id>/` | Token | Delete own pending report |
| GET | `/verified-hazards/` | Token | Approved hazards for map |
| GET | `/evacuation-centers/` | None | Operational centers |
| POST | `/calculate-route/` | Token | Get 3 safest routes |
| GET | `/bootstrap-sync/` | Token | Initial cache load |
| GET | `/notifications/` | Token | User notifications |
| GET | `/notifications/unread-count/` | Token | Unread badge count |
| POST | `/notifications/mark-all-read/` | Token | Mark all read |

### MDRRMO Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/mdrrmo/dashboard-stats/` | MDRRMO | Summary counters |
| GET | `/mdrrmo/analytics/` | MDRRMO | Hazard + road risk distributions |
| GET | `/mdrrmo/pending-reports/` | MDRRMO | Reports awaiting review |
| GET | `/mdrrmo/rejected-reports/` | MDRRMO | Rejected reports |
| POST | `/mdrrmo/approve-report/` | MDRRMO | Approve or reject a report |
| POST | `/mdrrmo/restore-report/` | MDRRMO | Restore rejected → pending |
| DELETE | `/mdrrmo/reports/<id>/` | MDRRMO | Soft-delete a report |
| POST | `/mdrrmo/evacuation-centers/` | MDRRMO | Create center |
| GET | `/mdrrmo/evacuation-centers/<id>/` | MDRRMO | Get center detail |
| PUT | `/mdrrmo/evacuation-centers/<id>/update/` | MDRRMO | Update center |
| DELETE | `/mdrrmo/evacuation-centers/<id>/delete/` | MDRRMO | Delete center |
| POST | `/mdrrmo/evacuation-centers/<id>/deactivate/` | MDRRMO | Deactivate |
| POST | `/mdrrmo/evacuation-centers/<id>/reactivate/` | MDRRMO | Reactivate |
| GET | `/users/` | MDRRMO | List all registered users |
| GET | `/users/<id>/` | MDRRMO | User detail |
| POST | `/users/<id>/suspend/` | MDRRMO | Suspend user |
| POST | `/users/<id>/activate/` | MDRRMO | Reactivate suspended user |
| DELETE | `/users/<id>/delete/` | MDRRMO | Admin-delete user |
| GET | `/mdrrmo/system-logs/` | MDRRMO | System event log |
| POST | `/mdrrmo/system-logs/clear/` | MDRRMO | Clear old logs |

---

## 20. End-to-End Data Flow

### 20.1 Hazard Report Lifecycle

```
RESIDENT
  │
  │ (1) submit report + GPS proof
  ▼
/api/report-hazard/
  │
  ├─► distance check > 150 m? ──► auto_rejected = True → STOP
  │
  ├─► NaiveBayesValidator.validate_report()  → naive_bayes_score
  ├─► reporter_proximity_weight()            → distance_weight
  ├─► ConsensusScoringService.count_nearby() → consensus_score
  ├─► combine_validation_scores()            → final_validation_score
  │
  └─► HazardReport saved (status=PENDING)
           │
           ▼
      MDRRMO reviews dashboard
           │
     ┌─────┴─────┐
     │ APPROVE   │ REJECT
     ▼           ▼
  status=       status=
  APPROVED      REJECTED
     │
     ▼
  Appears on   Feeds routing    Triggers
  public map   engine (RF +    notification
               Dijkstra)       to reporter
```

### 20.2 Route Calculation & Navigation

```
RESIDENT
  │
  │ (1) selects evacuation center on map
  ▼
/api/calculate-route/
  │
  ├─► RoadSegment.predicted_risk_score updated by RF model
  │       (9 features from approved hazards within 200 m)
  │
  ├─► For each edge: effective_risk = 0.6×base + 0.4×dynamic
  │       dynamic = Σ graduated hazard impacts (perpendicular dist + decay)
  │
  ├─► edge_cost = base_distance + effective_risk × 500
  │
  ├─► Modified Dijkstra (repeated with edge penalties, k=3) → up to 3 paths
  │
  └─► Routes returned with polylines + risk labels (GREEN/YELLOW/RED)
           │
           ▼
    RESIDENT selects route
           │
           ▼
    LiveNavigationScreen
           │
    selectedRoute.path = backend polyline (authoritative)
           │
    OSRM called for turn-instruction text only
    (fallback: bearing-analysis on polyline)
           │
    GPSTrackingService streams position + fused heading
           │
    Deviation detected? ──► backend reroute → OSRM fallback
           │
    Arrival at center ──► navigation ends
```

### 20.3 Offline Scenario

```
ConnectivityService detects OFFLINE
  │
  ▼
OfflineBanner shown
  │
HazardService.submitReport()
  ├─ Queued to Hive
  └─ Shown as pending on local map

ConnectivityService detects ONLINE
  │
SyncService._syncAll():
  ├─ flushPendingReports()      → submit queued reports
  ├─ refreshEvacuationCenters() → update center cache
  └─ refreshVerifiedHazards()   → update hazard cache
```

---

## Related Documents

| Document | Description |
|----------|-------------|
| `docs/algorithm-workflow.md` | Algorithm decision diagrams and scoring formulas |
| `docs/Algorithms_How_They_Work.md` | Technical deep-dive: NB, RF, Dijkstra, decay profiles |
| `docs/SRS_Software_Requirements_Specification.md` | Functional and non-functional requirements |
| `docs/Test_Case_Document.md` | Test cases for all features |
| `docs/OFFLINE_MODE.md` | Offline behavior details |
| `docs/HAZARD_CONFIRMATION_SYSTEM.md` | Confirmation flow detail |
| `docs/PROXIMITY_AND_MEDIA_UPDATES.md` | Media handling and proximity rules |
