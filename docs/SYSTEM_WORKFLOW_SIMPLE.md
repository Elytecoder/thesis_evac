# System Workflow — Quick Reference

**Project:** Hazard-Aware Evacuation Route Advisory System · Bulan, Sorsogon  
**Stack:** Django 5 · Flutter 3 · SQLite · OSRM (turn hints only)

---

## Roles

| Role | Can Do |
|------|--------|
| **Resident** | Report hazards, view map, request routes, navigate, confirm reports |
| **MDRRMO** | Everything above + review reports, manage centers, view analytics & logs |

---

## 1. Registration & Login

1. Resident enters email → server sends a **6-digit OTP** (expires in 5 min)
2. Resident fills the form (name, address, password) and submits OTP
3. Account is activated immediately → **token** returned and saved on device
4. Login checks: email verified, not suspended, correct password

---

## 2. Reporting a Hazard

1. Resident pins a hazard on the map, selects type, writes description, attaches photo (optional)
2. App sends the report **with the resident's current GPS location**
3. **GPS is required** — the server returns HTTP 400 if it is missing
4. If offline, the report is **queued locally** and submitted when connectivity restores

---

## 3. Automatic Validation (runs immediately on submission)

```
Distance check
  Reporter > 150 m from pin?  →  Auto-rejected (eyewitness rule)

If within 150 m, run 3 scoring layers:

  NB Score (0–1)       = Naïve Bayes on hazard type + description text
  Distance Weight (0–1) = 1 – (distance_m / 150)
  Consensus Score (0–1) = nearby same-type reports + confirmations (within 100 m, last 1 hr) / 5

  Final Score = 0.5 × NB  +  0.3 × Distance  +  0.2 × Consensus
```

Report stays **PENDING** — scores guide MDRRMO, not auto-approve.

---

## 4. MDRRMO Review

| Action | Effect |
|--------|--------|
| **Approve** | Report goes public on map; feeds routing engine; notifies reporter |
| **Reject** | Hidden from map; notifies reporter with reason |
| **Restore** | Rejected → Pending (re-enters queue) |
| **Delete** | Soft-delete; hidden everywhere; excluded from routing |

---

## 5. Hazard Confirmation (Residents)

Any resident near an existing report can **confirm** it. Each confirmation:
- Increments the confirmation count
- Recalculates the consensus score and final score on the report

---

## 6. Route Calculation

```
POST /api/calculate-route/  {start_lat, start_lng, evacuation_center_id}

1. Load all road segments (3,247 edges covering Bulan)
2. Update each segment's base risk via Random Forest
   (9 features: nearby approved hazard counts, types, scores, distances)
3. For each segment, calculate dynamic risk from live hazards:
   - Perpendicular distance from hazard to road edge
   - Per-type influence radius + decay curve (sharp / moderate / gradual)
   - road_blocked within radius → segment impassable (risk = 1.0)
4. effective_risk = 0.6 × RF_base  +  0.4 × dynamic
5. edge_cost = base_distance_m  +  effective_risk × 500
6. Modified Dijkstra (Yen's k=3) → 3 safest paths

Risk labels:
  GREEN   total_risk < 0.3
  YELLOW  0.3 ≤ total_risk < 0.7
  RED     total_risk ≥ 0.7
```

Resident picks a route → backend polyline is passed directly to navigation.

---

## 7. Live Navigation

- **The backend route polyline is the navigation path** — it is never recalculated by OSRM
- OSRM is called only for **turn-instruction text** ("Turn left at…")
- If OSRM fails, turn hints are generated from bearing changes along the polyline
- GPS heading is a blend of magnetometer + GPS course bearing (low-pass filtered)
- **Rerouting:** calls the backend first (hazard-aware); falls back to OSRM only if backend fails

---

## 8. Offline Mode

| State | Behavior |
|-------|----------|
| **Goes offline** | Banner shown; cached centers + hazards still displayed |
| **Submits report offline** | Queued in local storage (Hive) |
| **Comes back online** | Queued reports submitted → centers + hazards refreshed |

---

## 9. Key Data Rules

- Reporter must be **≤ 150 m** from the pinned hazard (enforced server-side)
- User GPS coordinates are **required** to submit a report
- Only **PENDING** reports can be deleted by the resident
- Soft-deleted reports are **excluded from routing and the map**
- All timestamps stored in **UTC**, displayed in **Asia/Manila** time
- Each user has a **6-digit public ID** for MDRRMO display (no PII exposed)

---

## 10. Other Features

| Feature | Summary |
|---------|---------|
| **Notifications** | In-app alerts for approved, rejected, and restored reports |
| **Analytics** | Pie chart of hazard types; road risk breakdown (High/Moderate/Low) from live segment scores |
| **Dashboard** | MDRRMO summary: pending count, verified hazards, high-risk roads, center status |
| **System Logs** | Every significant action logged in background (auth, reports, navigation, etc.) |
| **Evacuation Centers** | MDRRMO can create, update, deactivate, and reactivate centers |
| **User Management** | MDRRMO can view, suspend, and delete resident accounts |

---

## Full Detail

For in-depth technical documentation see:

| Document | Contents |
|----------|----------|
| `SYSTEM_WORKFLOW.md` | Full workflow with all formulas, rules, and API tables |
| `Algorithms_How_They_Work.md` | Deep-dive: NB, RF features, Dijkstra, decay profiles |
| `algorithm-workflow.md` | Decision flow diagrams and scoring step-by-step |
| `SRS_Software_Requirements_Specification.md` | Functional requirements (REQ-001 – REQ-160) |
| `Test_Case_Document.md` | Test cases for all features |
