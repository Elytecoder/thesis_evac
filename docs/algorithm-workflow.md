# Full Algorithm Workflow: From Report to Safer Routes

This document describes the end-to-end flow of how **resident hazard reports** become **approved hazards** that influence **evacuation route recommendations**. The system prioritizes **real approved hazard data** for routing while keeping Naive Bayes for validation and Random Forest as a base risk predictor.

---

## High-Level Flow

```
Resident Report
    -> Proximity check (> 150 m -> auto-reject)
    -> Naive Bayes (full text) + rule scores (distance, consensus) -> final_validation_score
    -> Status: PENDING (MDRRMO review)
    -> MDRRMO approves or rejects
    -> Approved hazard reports
    -> Feed road segment risk (RF features computed per segment)
    -> Modified Dijkstra
    -> Top 3 routes
    -> Risk evaluation layer (thresholds 0.7 / 0.9)
    -> No-safe-route detection, labels, alternative centers
    -> Safer route suggestions + warnings when all routes high-risk
```

---

## 1. Resident Submits a Hazard Report

- The resident submits: hazard type, location (lat/lng), description, optional photo/video, and their current GPS (user_lat, user_lng).
- **Proximity rule:** If the user is **more than 150 m** from the reported hazard location, the report is **auto-rejected** and never stored as PENDING. No Naive Bayes or rule scoring runs.
- If within 150 m, the report proceeds to validation.

---

## 2. Validation (Naive Bayes + rules)

- **Naive Bayes (text only):** `hazard_type` + `description` (full text, CountVectorizer + MultinomialNB via `ml_service`) -> `naive_bayes_score` = P(valid | text). Model loaded from `ml_data/models/naive_bayes_model.pkl`.
- **Rule scoring (separate):**
  - reporter-hazard distance -> `distance_weight = 1 - (distance_m / 150)` clamped to [0, 1]
  - same-type nearby reports within 100 m (status PENDING or APPROVED) -> `consensus_score = min((confirmations + similar_nearby) / 5.0, 1.0)`
- **Combined:**
  ```
  final_validation_score = (naive_bayes_score x 0.5) + (distance_weight x 0.3) + (consensus_score x 0.2)
  ```
- **Purpose:** MDRRMO insight; **not** auto-approve. Status stays **PENDING** until MDRRMO acts.

---

## 3. MDRRMO Approval or Rejection

- MDRRMO reviews **pending** reports and can **approve** or **reject**.
- **Approved** reports become the **verified hazards** shown on the map and are used to **influence route computation**.
- Rejected reports do not affect routing or the verified-hazards list.

---

## 4. Approved Hazard Reports in Routing

- **Data source:** All approved hazard reports are loaded:

  ```python
  approved_hazards = HazardReport.objects.filter(status=HazardReport.Status.APPROVED)
  ```

- These hazards are **real data** (resident-reported, MDRRMO-approved). The routing system **prioritizes** them over base RF scores when computing effective risk.

---

## 5. Road Segment Risk (Two-layer model)

For each **road segment** (edge in the graph), an **effective risk** is computed:

```
effective_risk = (base_risk x 0.6) + (dynamic_risk x 0.4)
```

**Base risk** (`predicted_risk_score`) — from Random Forest:
- Computed per segment using 9 features: per-type hazard counts (8 types) + `avg_severity` of nearby approved reports within 200 m.
- Stored in the DB via `python manage.py update_segment_risks`.
- Auto-updated after RF model retraining (`python manage.py train_ml_models`).

**Dynamic risk** — computed live at route time from approved hazards within 100 m:
- Each nearby hazard contributes `type_weight x validation_impact` to dynamic risk.
- Type weights: `road_blocked=0.7`, `bridge_damage=0.5`, `landslide=0.5`, `storm_surge=0.5`, `fallen_electric_post=0.4`, `flooded_road=0.3`, `road_damage=0.3`, `fallen_tree=0.2`.
- **Road block override:** If any nearby hazard is `road_blocked`, `effective_risk = 1.0` immediately (fully impassable, Dijkstra avoids this edge).

**Fallback:** If no approved hazards exist, `effective_risk = base_risk` (RF prediction). System still returns valid routes.

---

## 6. Modified Dijkstra (Cost and Paths)

- **Edge cost:**
  ```
  cost = segment.base_distance + (effective_risk x 500)
  ```
  Higher risk -> higher cost -> algorithm tends to **avoid** dangerous segments.

- **Algorithm:** Modified Dijkstra finds paths that minimize this cost (safest routes, not only shortest).
- **Output:** Up to 3 route alternatives with total distance, total risk, and risk level.

---

## 7. Risk Evaluation Layer (After Dijkstra)

After Modified Dijkstra returns the top 3 routes, a **safety layer** evaluates them without changing the algorithms:

1. **Thresholds:** `HIGH_RISK_THRESHOLD = 0.7`, `EXTREME_RISK_THRESHOLD = 0.9`.

2. **Per route:**
   - **risk_label:** "High Risk" if total_risk >= 0.7, else "Safer Route".
   - **possibly_blocked:** true when total_risk > 0.9.
   - **contributing_factors:** List of hazards affecting the route from approved HazardReports near the path.

3. **No-safe-route:** If *all* returned routes have total_risk >= 0.7:
   - Set `no_safe_route = true`, `message`, `recommended_action`.
   - Compute **alternative_centers** for other operational evacuation centers.

4. **API response** includes: `routes`, `no_safe_route`, `message`, `recommended_action`, `alternative_centers`.

---

## 8. End-to-End Data Flow Summary

| Stage | Data / Logic |
|----|---|
| Report submission | Resident; proximity check (> 150 m -> auto-reject) |
| Validation | `naive_bayes_score` (CountVectorizer + MultinomialNB), `distance_weight` (150 m limit), `consensus_score` (same-type, 100 m, /5), `final_validation_score` (weighted 0.5/0.3/0.2) |
| Verification | MDRRMO approves or rejects |
| Segment risk (base) | RF with 9 features (8 hazard type counts + avg_severity, 200 m radius) |
| Segment risk (effective) | base x 0.6 + dynamic x 0.4 (live from approved hazards at route time) |
| Pathfinding | Modified Dijkstra: cost = distance + (effective_risk x 500) |
| Risk evaluation | Thresholds 0.7 / 0.9; risk_label, possibly_blocked, contributing_factors; no_safe_route + alternative_centers |
| Result | Routes + warnings + alternatives; UI shows labels and warning modal |

---

## 9. Design Notes

- **No full dependency on mock data:** Synthetic training data is used only as a placeholder. The system is designed to accept real MDRRMO data with no code changes — only CSV replacement and model retraining.
- **Separation of roles:** NB is text-only; distance and consensus are rules; Random Forest predicts base road risk; Dijkstra finds routes.
- **Dynamic and real-time:** As MDRRMO approves more reports, segment risks update via `update_segment_risks` and new hazards immediately affect dynamic risk at route time.
- **AI assists, not decides:** MDRRMO always makes the final approve/reject decision.

---

## 10. Related Documentation

- **ML_IMPLEMENTATION.md** — Complete ML pipeline reference (datasets, training, management commands, how to replace synthetic data)
- **Algorithms_How_They_Work.md** — Detailed description of each algorithm with formulas
- **README.md** — Project overview, setup, and API summary
