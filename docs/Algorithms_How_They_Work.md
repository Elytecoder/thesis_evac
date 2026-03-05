# How the Algorithms Work

This document explains the three main algorithms in the AI-Powered Mobile Evacuation Routing Application: **Naive Bayes** (report validation), **Random Forest** (road risk prediction), and **Modified Dijkstra** (safest-path routing).

---

## Overview

| Algorithm | Purpose | When It Runs |
|-----------|---------|--------------|
| **Naive Bayes** | Decide if a hazard report is real or fake | When a resident submits a hazard report |
| **Random Forest** | Predict how dangerous each road segment is | When building/updating road risk; used during routing |
| **Modified Dijkstra** | Find the safest route (not the shortest) | When a user requests directions to an evacuation center |

Validation uses **one** algorithm (Naive Bayes) with proximity and nearby-report count as **features**. There is no separate consensus formula.

---

## 1. Naive Bayes (Report Validation)

**Role:** Single validation algorithm. It outputs a probability that a submitted hazard report is authentic. That probability alone drives the decision: auto-approve, pending, or reject.

### Inputs (features)

- **hazard_type** — e.g. flooded_road, landslide, bridge_damage
- **description_length** — bucketed as short (&lt;20 chars), medium (20–60), long (&gt;60)
- **distance_category** — how far the reporter was from the hazard:
  - `very_near`: 0–50 m  
  - `near`: 50–100 m  
  - `moderate`: 100–200 m  
  - `far`: 200 m–1 km  
  (If user is **&gt; 1 km** away, the report is **auto-rejected** before Naive Bayes runs.)
- **nearby_similar_report_count_category** — count of other reports within **50 m** and **1 hour**:
  - `none`: 0  
  - `few`: 1–2  
  - `moderate`: 3–5  
  - `many`: 6+
- **time_of_report** (optional) — e.g. hour or day/night

### How it works

1. The model is trained on historical MDRRMO-verified reports (valid vs invalid) with the same features.
2. For a new report, features are extracted and the classifier computes **P(valid | features)** using Bayes’ rule with Laplace smoothing.
3. Output is a single number in **[0, 1]** (no separate consensus score or weighted formula).

### Decision rules (after Naive Bayes)

- **Probability ≥ 0.8** → Auto-approve (status: Approved)
- **0.5 ≤ probability &lt; 0.8** → Pending (MDRRMO review)
- **Probability &lt; 0.5** → Reject

### Proximity rule (before Naive Bayes)

- If the distance between the user’s GPS (at submit time) and the reported hazard location is **&gt; 1 km**, the report is **auto-rejected** (extreme misuse). No Naive Bayes run.
- For distance ≤ 1 km, distance is only used as the **distance_category** feature; there is no hard 200 m cutoff.

---

## 2. Random Forest (Road Risk Prediction)

**Role:** Predict a **risk score (0–1)** for each road segment. These scores are used for “most dangerous barangays” and as edge weights in routing.

### Inputs (features per segment)

- **Nearby hazard count** — number of (verified) hazards within **100 m** of the segment
- **Average hazard severity** — average severity (0–1) of those hazards
- **Historical flooding frequency** (if available)
- **Road elevation** (if available)

### How it works

1. The model is trained on historical road segments with known hazard counts and severity; the label is a risk score (0 = safe, 1 = very dangerous).
2. At runtime, for each segment we compute the features (e.g. count hazards in 100 m, average severity) and the Random Forest regressor outputs a **predicted_risk_score** in [0, 1].
3. Segments are classified for display: **Green** (0–0.3), **Yellow** (0.3–0.7), **Red** (0.7–1.0).

### When it updates

- When a new hazard report is **approved**, road risk is updated for affected segments (and optionally in a batch/nightly job).

**No change in this refactor:** Random Forest is unchanged; only validation was simplified.

---

## 3. Modified Dijkstra (Safest-Path Routing)

**Role:** Find routes that minimize **risk-weighted cost**, not plain distance. It uses the road network and segment risk scores from Random Forest.

### Inputs

- **Road graph** — nodes and edges from the road network (e.g. OSRM/OpenStreetMap)
- **Edge weights** — for each edge:  
  **cost = distance + (segment_risk × 500)**  
  The factor 500 makes safety dominate over distance.

### How it works

1. OSRM (or similar) provides road-following geometry and graph structure.
2. Each edge is assigned a weight = distance + (predicted_risk × 500) using Random Forest’s segment risk.
3. Dijkstra’s algorithm (or a k-shortest-paths variant) finds the path with **minimum total cost**, i.e. the **safest** route. The system returns the top 3 such routes.

### Output

- Up to 3 routes from user location to the chosen evacuation center, ranked by safety (lowest risk-weighted cost first).

**No change in this refactor:** Modified Dijkstra is unchanged.

---

## End-to-end flows

### Report submission (validation)

```
User submits report (with optional user_lat, user_lng)
        ↓
Compute distance: user location ↔ hazard location
        ↓
If distance > 1 km  →  Auto-reject, stop
        ↓
Else: distance_category = category(distance)
      nearby_count = count reports within 50 m, 1 hour
      nearby_category = category(nearby_count)
        ↓
Naive Bayes(hazard_type, description_length, distance_category, nearby_category, …)
        ↓
Probability  →  Apply threshold (≥0.8 approve, 0.5–0.8 pending, <0.5 reject)
        ↓
Save report; if approved, road risk (Random Forest) can be updated
```

### Route request (routing)

```
User requests route to evacuation center
        ↓
Check cache; if miss → OSRM for road geometry/graph
        ↓
Backend: assign edge weight = distance + (segment_risk × 500)
         (segment_risk from Random Forest)
        ↓
Modified Dijkstra  →  Top 3 safest paths
        ↓
Return routes (distance, risk, ETA); display on map
```

---

## Summary table

| Algorithm      | Inputs                                      | Output              | Used for                    |
|----------------|---------------------------------------------|---------------------|-----------------------------|
| Naive Bayes    | hazard_type, description, distance_category, nearby_category, optional time | Probability 0–1     | Report validation only      |
| Random Forest  | nearby hazard count, severity, optional history/elevation per segment       | Risk score 0–1 per segment | Barangay risk, route weights |
| Modified Dijkstra | Graph + edge cost = distance + (risk × 500) | Top 3 paths         | Safest route to evacuation center |

---

*Document reflects the refactored validation architecture: single Naive Bayes with integrated proximity and nearby-report features; Random Forest and Modified Dijkstra unchanged.*
