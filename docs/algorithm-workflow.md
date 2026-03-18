# Full Algorithm Workflow: From Report to Safer Routes

This document describes the end-to-end flow of how **resident hazard reports** become **approved hazards** that influence **evacuation route recommendations**. The system prioritizes **real approved hazard data** for routing while keeping Naive Bayes for validation and Random Forest as a base risk fallback.

---

## High-Level Flow

```text
Resident Report
    → Proximity check (>1 km → auto-reject)
    → Naive Bayes validation (score stored)
    → Status: PENDING (MDRRMO review)
    → MDRRMO approves or rejects
    → Approved hazard reports
    → Affect road segment risk (proximity-based)
    → Modified Dijkstra
    → Top 3 routes
    → Risk evaluation layer (thresholds 0.7 / 0.9)
    → No-safe-route detection, labels, alternative centers
    → Safer route suggestions + warnings when all routes high-risk
```

---

## 1. Resident Submits a Hazard Report

- The resident submits: hazard type, location (lat/lng), description, optional photo/video, and optionally their current GPS (user_lat, user_lng).
- **Proximity rule:** If the user is **more than 1 km** from the reported hazard location, the report is **auto-rejected** and never stored as PENDING. No Naive Bayes run.
- If within 1 km, the report is stored with status **PENDING**.

---

## 2. Naive Bayes Validation (Report Quality)

- **Purpose:** Assess how likely the report is to be authentic; used for MDRRMO insight and scoring, **not** for auto-approving.
- **Inputs (features):** hazard_type, description length, distance category (very_near / near / moderate / far), nearby similar report count (within 50 m, 1 hour), etc.
- **Output:** A probability score stored in `naive_bayes_score`. Report status remains **PENDING** until MDRRMO acts.
- **Important:** The system does **not** auto-approve or auto-reject based on Naive Bayes alone; MDRRMO makes the final decision.

---

## 3. MDRRMO Approval or Rejection

- MDRRMO reviews **pending** reports and can **approve** or **reject**.
- **Approved** reports become the **verified hazards** shown on the map and, as of the routing update, are used to **influence route computation**.
- Rejected reports do not affect routing or the verified-hazards list.

---

## 4. Approved Hazard Reports in Routing

- **Data source:** All approved hazard reports are loaded:

  ```python
  approved_hazards = HazardReport.objects.filter(status=HazardReport.Status.APPROVED)
  ```

- These hazards are **real data** (resident-reported, MDRRMO-approved). The routing system **prioritizes** them over mock or historical data when computing risk.

---

## 5. Proximity-Based Risk for Road Segments

For each **road segment** (edge in the graph), an **effective risk** is computed:

1. **Base risk:** `predicted_risk_score` from Random Forest (or from mock training data if no RF scores exist). This is the fallback so routing still works with no approved hazards.

2. **Dynamic risk from approved hazards:** For each approved hazard, we check if it is within **100 meters** of the segment. Distance is taken as the minimum of:
   - distance from hazard to segment start node,
   - distance from hazard to segment end node,
   - distance from hazard to segment midpoint.

   If `distance ≤ 100 m`, that hazard counts as “nearby” for this segment.

3. **Formula:**

   ```text
   effective_risk = base_risk + min(nearby_count × 0.2, 1.0)
   ```

   - More hazards nearby → higher risk.
   - The dynamic part is capped at 1.0 so that a single segment does not dominate the graph.

4. **Fallback:** If there are **no approved hazards**, `effective_risk = base_risk` (Random Forest or mock). The system behaves as before and still returns routes.

---

## 6. Modified Dijkstra (Cost and Paths)

- **Edge cost:** Each edge (road segment) is weighted by:

  ```text
  cost = segment.base_distance + (effective_risk × 500)
  ```

  So:
  - **segment_risk** = base risk + hazard-based (proximity) risk.
  - Higher risk → higher cost → the algorithm tends to **avoid** dangerous segments.

- **Algorithm:** Modified Dijkstra finds paths that minimize this cost (i.e. safest routes, not only shortest).
- **Output:** Up to 3 route alternatives with total distance, total risk, and risk level (Green / Yellow / Red).

---

## 7. Risk Evaluation Layer (After Dijkstra)

After Modified Dijkstra returns the top 3 routes, a **safety layer** evaluates them without changing the algorithms:

1. **Thresholds:** `HIGH_RISK_THRESHOLD = 0.7`, `EXTREME_RISK_THRESHOLD = 0.9`.

2. **Per route:**
   - **risk_label:** "High Risk" if total_risk ≥ 0.7, else "Safer Route".
   - **possibly_blocked:** true when total_risk > 0.9 (shown as "Possibly Blocked" in the UI).
   - **contributing_factors:** List of hazards affecting the route (from approved HazardReports near the path): hazard_type, severity (from type), location (e.g. "Near Km 2.1").

3. **No-safe-route:** If *all* returned routes have total_risk ≥ 0.7:
   - Set `no_safe_route = true`, `message` (e.g. "All routes are high risk"), `recommended_action` (e.g. "Try another evacuation center or wait").
   - Compute **alternative_centers:** for other operational evacuation centers (excluding the selected one), run routing with `include_alternative_centers = false` and return for each: center_name, has_safe_route (any route < 0.7), best_route_risk.

4. **API response** includes: `routes`, `no_safe_route`, `message`, `recommended_action`, `alternative_centers`. Routes are always returned and displayed; the UI shows a warning modal when `no_safe_route` is true, with options "View Routes Anyway" and "Try Other Evacuation Centers."

---

## 8. End-to-End Data Flow Summary

| Stage              | Data / Logic |
|--------------------|--------------|
| Report submission  | Resident; proximity check (>1 km → auto-reject). |
| Validation         | Naive Bayes score stored; status remains PENDING. |
| Verification       | MDRRMO approves or rejects. |
| Routing input      | Approved hazard reports + road segments (base risk from RF/mock). |
| Segment risk       | Base risk + min(nearby_count × 0.2, 1.0) for hazards within 100 m. |
| Pathfinding        | Modified Dijkstra with cost = distance + (effective_risk × 500). |
| Risk evaluation    | Thresholds 0.7 / 0.9; risk_label, possibly_blocked, contributing_factors; no_safe_route + alternative_centers when all routes high-risk. |
| Result             | Routes + warnings + alternatives; UI shows labels and optional warning modal. |

---

## 9. Design Notes

- **No full dependency on mock data:** Mock training data is used only as a **fallback** for base segment risk when Random Forest has not produced scores. **Real approved hazard reports** drive the dynamic part of routing.
- **Naive Bayes and structure unchanged:** Naive Bayes remains the validation algorithm; the routing structure (Modified Dijkstra, road graph) is unchanged. Only routing is **enhanced** by injecting real hazard data via proximity-based risk.
- **Dynamic and real-time:** As MDRRMO approves more reports, new hazards immediately affect segment risk and thus route suggestions, without requiring a separate “historical” or batch update step for this part of the logic.

---

## 10. Related Documentation

- **Algorithms_How_They_Work.md** — Detailed description of Naive Bayes, Random Forest, and Modified Dijkstra.
- **README.md** — Project overview, setup, and API summary.
