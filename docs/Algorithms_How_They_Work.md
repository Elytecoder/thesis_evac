# How the Algorithms Work — HAZNAV

This document explains the three main algorithms in **HAZNAV** (Hazard-Aware Evacuation Navigator): **Naive Bayes** (report validation), **Random Forest** (road risk prediction), and **Modified Dijkstra** (safest-path routing).

---

## Overview

| Algorithm | Purpose | When It Runs |
|-----------|---------|--------------|
| **Naive Bayes** | Decide if a hazard report is credible or spam | When a resident submits a hazard report |
| **Random Forest** | Predict how dangerous each road segment is | When building/updating road risk; used during routing |
| **Modified Dijkstra** | Find the safest route (not the shortest) | When a user requests directions to an evacuation center |

Validation keeps **roles separate**: **Naive Bayes** uses **text features only** (hazard type + description). **Distance weight** (reporter proximity) and **consensus** (nearby report count) are **rule-based** and combined with the NB score for a **final validation score**. **MDRRMO** approves or rejects; there is no auto-approve from the model.

---

## 1. Naive Bayes (Report Validation — text only)

**Role:** Estimate **P(valid | text features)** for a submitted report. Not used for routing directly; combined with rule scores for MDRRMO review context.

### Inputs (features — NB only)

Text input is `hazard_type + " " + description` (combined and vectorized with CountVectorizer):

| Feature | Type | Examples |
|---|---|---|
| `hazard_type` | categorical | `flooded_road`, `landslide`, `fallen_tree`, `road_damage`, `fallen_electric_post`, `road_blocked`, `bridge_damage`, `storm_surge`, `other` |
| `description` | free text | "Road flooded knee deep, vehicles cannot pass" |

**Explicitly NOT NB features:**
- `time_of_report` — removed; hazards occur day and night, time adds no validity signal
- Reporter-hazard distance — handled separately by `rule_scoring.reporter_proximity_weight`
- Nearby report count — handled separately by `rule_scoring.consensus_rule_score`

### How it works

1. **CountVectorizer** (bigrams, `ngram_range=(1,2)`) converts text to word-count vectors.
2. **MultinomialNB** (`alpha=0.5` Laplace smoothing) classifies as valid (1) or invalid (0).
3. `predict_proba(X)[0][1]` gives P(valid | text) -> **`naive_bayes_score`** in **[0, 1]**.
4. Model loaded from `ml_data/models/naive_bayes_model.pkl` (trained on 201 synthetic examples).
5. Fallback: if model not yet trained, uses classic manual Bayes on hazard_type + description length bucket.

Replace training data: add rows to `ml_data/naive_bayes_dataset.csv`, then run `python manage.py train_ml_models --nb-only --force`.

### Hard proximity gate (before scoring)

- If user GPS is **> 150 m** from the reported hazard location -> **auto-reject**; no NB or rule scoring runs.

---

## 1b. Rule-based scoring (separate from Naive Bayes)

**Role:** Add structured signals that must not be merged into the NB likelihood tables.

- **Distance weight** — from reporter-hazard distance (within 150 m):
  ```
  distance_weight = 1 - (distance_m / 150)   clamped to [0, 1]
  ```
  Reporter at the hazard = 1.0. Reporter at 150 m = 0.0. Beyond 150 m = auto-rejected.

- **Consensus rule score** — from corroboration by other users:
  ```
  consensus_score = min((confirmation_count + similar_nearby_reports) / 5.0, 1.0)
  ```
  "Similar" = **same `hazard_type`**, within **100 m**, status `PENDING` or `APPROVED`.

**Final validation score** — weighted blend:
```
final_validation_score =
    (naive_bayes_score  x 0.5)
  + (distance_weight    x 0.3)
  + (consensus_score    x 0.2)
```

| Component | Weight | Role |
|---|---|---|
| Naive Bayes | 50% | Text credibility (AI) |
| Distance weight | 30% | Physical validation (reporter must be close) |
| Consensus | 20% | Community corroboration |

### After validation

Validated reports are **Pending** until **MDRRMO** approves or rejects. Only approved reports feed map display, dynamic segment/path risk, and routing hazard impact.

---

## 2. Random Forest (Road Risk Prediction)

**Role:** Predict a **risk score (0-1)** for each road segment based on the types of nearby approved hazards. Used as the **base risk** in routing.

### Inputs (features per segment — one per hazard type)

Computed from approved `HazardReport` records within **200 m** of the segment midpoint:

| Feature | Description |
|---|---|
| `flooded_road_count` | Nearby approved flooded_road reports |
| `landslide_count` | Nearby approved landslide reports |
| `fallen_tree_count` | Nearby approved fallen_tree reports |
| `road_damage_count` | Nearby approved road_damage reports |
| `fallen_electric_post_count` | Nearby approved fallen_electric_post reports |
| `road_blocked_count` | Nearby approved road_blocked reports |
| `bridge_damage_count` | Nearby approved bridge_damage reports |
| `storm_surge_count` | Nearby approved storm_surge reports |
| `avg_severity` | Mean final_validation_score of all nearby reports |

### How it works

1. Trained on synthetic data (300 rows, 9 features) using `RandomForestRegressor` (150 trees, max_depth=10, R2=0.988).
2. Model stored in `ml_data/models/random_forest_model.pkl`.
3. At runtime, features are computed per segment from nearby approved `HazardReport` objects.
4. RF predicts `predicted_risk_score` in [0, 1] per segment — stored in the database.

### When it updates

```bash
python manage.py train_ml_models --rf-only   # retrain + auto-updates all segment scores
python manage.py update_segment_risks        # refresh segments from current model only
```

RF provides **base risk** (weight 0.6 in effective risk formula); approved hazards add **dynamic risk** (weight 0.4) at route time.

---

## 3. Modified Dijkstra (Safest-Path Routing)

**Role:** Find routes that minimize **risk-weighted cost**, not plain distance. Uses the road network and segment risk scores.

### Inputs

- **Road graph** — nodes and edges from the road network (OpenStreetMap data)
- **Edge weights** — for each edge:
  ```
  cost = distance + (segment_risk x 500)
  ```
  The factor 500 makes safety dominate over distance.

### How it works

1. Road graph loaded from `RoadSegment` records.
2. Each edge is assigned `cost = distance + (effective_risk x 500)`.
3. Modified Dijkstra finds paths with minimum total cost (safest routes).
4. Returns up to 3 route alternatives.

### Effective risk per segment

```
effective_risk = (base_risk x 0.6) + (dynamic_risk x 0.4)
```

- **base_risk** = `predicted_risk_score` from RF (stored in DB)
- **dynamic_risk** = live accumulation from approved hazards at route time, using **graduated proximity** (not a binary radius)

#### Graduated hazard-to-road influence (dynamic risk)

Each approved hazard contributes impact based on five factors:

1. **True perpendicular distance** from the hazard to the segment centerline (flat-earth projection — accurate for road-length segments).
2. **Per-type influence radius** — tight for physical blockers, wide for spreading hazards:

| Hazard type | Radius | Reason |
|---|---|---|
| `road_blocked` / `road_block` | **25 m** | Must physically block the carriageway |
| `fallen_tree` | **15 m** | Trunk must cross the road |
| `road_damage` | **20 m** | Surface-bound |
| `bridge_damage` | **30 m** | Bridge is a narrow point |
| `flood` / `flooded_road` | **80 m** | Water spreads laterally |
| `storm_surge` | **150 m** | Large-area inundation |
| `landslide` | **60 m** | Debris field |
| `fallen_electric_post_wires` | **45 m** | Wire trailing radius |

3. **Decay profile** — controls how fast impact falls with distance:

| Profile | Formula | Used for |
|---|---|---|
| `sharp` | `1 − t²` | Blockers — must be on/near the road |
| `moderate` | `1 − t` | Debris, surface damage |
| `gradual` | `1 − √t` | Fluid hazards maintain wide impact |

4. **On-segment bonus** — when the hazard's perpendicular projection falls in the *interior* of the segment (flanks this specific road), the decay is multiplied ×1.2.
5. **Severity multiplier** — `final_validation_score` (NB + distance + consensus) scales each contribution.

**Road-block override:** If any `road_blocked` hazard is within 25 m of the centerline, `effective_risk = 1.0` immediately — segment is fully impassable and Dijkstra avoids it entirely.

### Output

Up to 3 routes ranked by safety (lowest risk-weighted cost first).

### Live navigation — routing consistency

When the user selects a route on the route-selection screen and starts navigation, the **exact polyline from Modified Dijkstra is preserved** through to the navigation screen:

- `LiveNavigationScreen` receives the selected backend `Route` object and builds its `NavigationRoute` directly from `Route.path`.
- **OSRM is never used as the primary navigation polyline.** Its role is limited to extracting turn-by-turn instruction hints (start → destination, road-snapped). If OSRM is unavailable, instructions are generated from bearing analysis of the backend polyline.
- **On rerouting**, the system calls the Django backend (Modified Dijkstra) again from the user's current position. OSRM is only the fallback when the backend is unreachable.
- This guarantees the route displayed on the selection screen is exactly the route followed during navigation — including all hazard-aware risk weighting.

---

## 4. Risk Evaluation Layer (After Routing)

**Role:** A safety layer applied *after* routes are generated. Does not replace or modify Naive Bayes, Random Forest, or Dijkstra. Adds warnings, labels, and alternatives.

### Thresholds

- **HIGH_RISK_THRESHOLD = 0.7** — Routes >= 0.7 labeled "High Risk"; if *all* routes meet this, `no_safe_route = true`.
- **EXTREME_RISK_THRESHOLD = 0.9** — Routes > 0.9 tagged "Possibly Blocked".

### Logic

1. **Per route:** Assign `risk_label`; set `possibly_blocked` if total_risk > 0.9.
2. **Contributing factors:** List of nearby approved hazards affecting the route.
3. **No-safe-route:** If all routes >= 0.7, set `no_safe_route = true` + `message` + `recommended_action`.
4. **Alternative centers:** Compute routes to other evacuation centers and return `has_safe_route`, `best_route_risk`.

---

## End-to-end flows

### Report submission (validation)

```
User submits report (hazard_type, description, location, optional user GPS)
        |
        v
Compute distance: user GPS <-> hazard location
        |
If distance > 150 m  -->  Auto-reject, stop
        |
        v
Naive Bayes(hazard_type + description)  -->  naive_bayes_score  [0,1]
distance_weight = 1 - (distance_m / 150)                        [0,1]
consensus_score = min((confirmations + nearby_same_type) / 5, 1)[0,1]
        |
        v
final_validation_score = (NB x 0.5) + (dist x 0.3) + (consensus x 0.2)
        |
        v
Save report as PENDING; MDRRMO reviews + approves or rejects
        |
If approved --> map display, routing risk, segment risk (via update_segment_risks)
```

### Route request (routing)

```
User requests route to evacuation center
        |
        v
Load road segments with predicted_risk_score (from RF model)
Load all approved hazard reports
        |
        v
Per segment: effective_risk = (base_risk x 0.6) + (dynamic_risk x 0.4)
             Dynamic risk uses graduated proximity:
               - True perpendicular distance to centerline
               - Per-type influence radius (road_blocked=25m, flood=80m, ...)
               - Per-type decay profile (sharp/moderate/gradual)
               - On-segment bonus x1.2
             If road_blocked within 25m: effective_risk = 1.0
        |
        v
Modified Dijkstra: cost = distance + (effective_risk x 500)
        |
        v
Top 3 safest paths → Risk evaluation: labels, possibly_blocked, no_safe_route
        |
        v
Return routes to mobile app
        |
User selects route → exact backend polyline used in live navigation
        |
OSRM used only for turn instructions (start→destination, road-snapped)
On reroute: backend Modified Dijkstra called first; OSRM is fallback only
```

---

## Summary table

| Component | Inputs | Output | Used for |
|---|---|---|---|
| Naive Bayes | hazard_type + description (full text, CountVectorizer) | `naive_bayes_score` 0-1 | Text credibility signal for MDRRMO |
| Rule scoring | reporter distance (150 m); same-type nearby reports (100 m) | `distance_weight`, `consensus_score` | Combined with NB -> `final_validation_score` |
| MDRRMO workflow | Human review | Approved / Rejected / Pending | Only approved hazards affect map and routing |
| Random Forest | Per-type hazard counts (8 types) + avg_severity within 200 m | `predicted_risk_score` 0-1 per segment | Base road risk for Dijkstra edge weights |
| Modified Dijkstra | Graph + cost = distance + (effective_risk x 500) | Top 3 paths | Safest route to evacuation center; exact polyline used in live navigation |
| Risk evaluation layer | Top 3 routes (total_risk, hazards along route) | `risk_label`, `possibly_blocked`, `no_safe_route`, `alternative_centers` | UI warnings and labels |
| Graduated hazard impact | Perpendicular distance + type radius + decay profile + severity | Dynamic risk contribution per segment | Replaces binary 100 m check; closer/on-road hazards have stronger influence |
| OSRM (turn hints) | Start + destination coordinates | Turn-by-turn step instructions | Navigation prompts only; backend polyline is never replaced by OSRM geometry |

---

## Related documentation

- **ML_IMPLEMENTATION.md** — Complete ML pipeline reference (datasets, training, commands, how to replace with real data)
- **algorithm-workflow.md** — End-to-end flow from report submission to routing
- **OFFLINE_MODE.md** — Offline mode architecture and data flows
- **HAZARD_CONFIRMATION_SYSTEM.md** — Confirmation/consensus system details
