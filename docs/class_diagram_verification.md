# Class Diagram Verification Against Current Implementation

This document checks the initial class diagram against the actual codebase (Django models, services, and API).

---

## Summary

| Component | Verdict | Notes |
|-----------|---------|--------|
| Residents / User | Partial | Same entity as MDRRMO (User with role); attributes and methods need alignment |
| Hazard Report | Partial | Missing fields (status, scores, location as lat/lng); MDRRMO does not submit |
| MDRRMO (Admin) | Incorrect | Remove viewRecommendedRoute and submitHazardReport; keep verify and manage |
| Data Access Layer | Partial | One User table (not separate resident/personnel); add RoadSegment |
| MachineLearningModel | Misaligned | Implemented as 4 components: Naive Bayes, Random Forest, Consensus, Dijkstra |
| Road | Misaligned | Implemented as RoadSegment (geometry + predicted_risk_score); no name/safetyStatus |
| Evacuation Center | Partial | Attributes and methods match conceptually; add address, description |

---

## 1. Residents

**Diagram:** `userID`, `name`, `email`, `passwordHash` | `login()`, `viewMap()`, `searchEvacuationCenter()`, `submitHazardReport()`, `viewRecommendedRoute()`

**Implementation:** Single **User** model (Django `AbstractUser`) used for both residents and MDRRMO:
- **Attributes:** `id`, `username`, `email`, `password` (stored hashed), `first_name`, `last_name`, **`role`** (`resident` | `mdrrmo`), `is_active`
- No `userID` (use `id`); no single `name` (use `username` or `first_name`/`last_name`).

**Verdict:** **Partial.** Use one **User** class with `role` and the attributes above. Methods are app/API behavior; keeping them on the actor is fine for a conceptual diagram.

---

## 2. Hazard Report

**Diagram:** `reportID`, `hazardType`, `description`, `location`, `timestamp` | `submitReport()`, `viewReport()`

**Implementation:** **HazardReport** model:
- **Attributes:** `id`, `user` (FK to User), `hazard_type`, **`latitude`**, **`longitude`** (not a single `location` string), `description`, `photo_url`, `video_url`, **`status`** (pending/approved/rejected), **`naive_bayes_score`**, **`consensus_score`**, **`admin_comment`**, `created_at`
- Submission and viewing are in services/views, not on the model.

**Verdict:** **Partial.** Add `latitude`, `longitude` (or note “location = lat/lng”), `status`, `naive_bayes_score`, `consensus_score`, `admin_comment`; `timestamp` → `created_at`. Only **Residents** submit; **MDRRMO does not** submit hazard reports.

---

## 3. MDRRMO (Admin)

**Diagram:** `personnelID`, `name`, `email`, `passwordHash`, `role` | `login()`, `viewMap()`, `manageEvacuationCenter()`, **`submitHazardReport()`**, `viewCrowdsourcedHazards()`, **`viewRecommendedRoute()`**, `verifyHazardReport()`

**Implementation:** Same **User** model with `role = 'mdrrmo'`. No separate personnel table or `personnelID`. Admin capabilities in the app:
- View map **with verified reports** (no route computation).
- **Manage evacuation centers** (add/edit/delete).
- **View crowdsourced hazards** (pending reports list).
- **Verify hazard report** (approve/reject).
- Admin does **not** get safest route and does **not** submit hazard reports.

**Verdict:** **Incorrect for current design.**
- **Remove:** `submitHazardReport()`, `viewRecommendedRoute()`.
- **Keep:** `login()`, `viewMap()`, `manageEvacuationCenter()`, `viewCrowdsourcedHazards()`, `verifyHazardReport()`.
- **Optional:** Rename `viewMap()` to something like `viewMapWithVerifiedReports()` to be precise.
- Use same User attributes as Residents (no separate `personnelID`); distinguish by `role`.

---

## 4. Data Access Layer

**Diagram:** `saveResident()`, `savePersonnel()`, `saveHazardReport()`, `saveEvacuationCenter()`, `retrieveData()`

**Implementation:** Django ORM + models. Single **User** table (resident and MDRRMO); no separate “resident” and “personnel” tables.

**Verdict:** **Partial.**
- Replace `saveResident()` / `savePersonnel()` with **`saveUser()`** (or one generic save for User).
- Keep `saveHazardReport()`, `saveEvacuationCenter()`, `retrieveData()`.
- **Add:** **`saveRoadSegment()`** (or equivalent) and **`retrieveRoadSegments()`** for the road network.

---

## 5. MachineLearningModel

**Diagram:** `modelID`, `roadData`, `hazardData`, `weatherData` | `analyzeRoadSafety()`, `predictRoadCondition()`, `generateSafestRoute()`

**Implementation:** No single “MachineLearningModel” class. There are four separate components:
- **NaiveBayesValidator** – validates hazard reports (outputs `naive_bayes_score`).
- **ConsensusScoringService** – combines Naive Bayes score with nearby reports (`consensus_score`).
- **RoadRiskPredictor** (Random Forest) – predicts **road segment** risk (`predicted_risk_score`).
- **ModifiedDijkstraService** – computes safest routes from segment graph (distance + risk).

There is no `weatherData` in the current implementation.

**Verdict:** **Misaligned.**
- **Option A:** Replace the single class with four: **NaiveBayesValidator**, **ConsensusScoringService**, **RoadRiskPredictor**, **ModifiedDijkstraService**, with methods and relationships that match the code.
- **Option B:** Keep one conceptual “ML / routing” component but rename and adjust:
  - Attributes: e.g. `roadData` (segment list), `hazardData` (reports for validation); **drop** `weatherData` and `modelID` if not in use.
  - Methods: e.g. `validateReport()` (Naive Bayes + Consensus), `predictSegmentRisk()` (Random Forest), `computeSafestRoutes()` (Dijkstra). “Analyzes Road” and “Uses by Residents” stay; no direct link from MDRRMO to this component (admin does not get routes).

---

## 6. Road

**Diagram:** `roadID`, `name`, `safetyStatus`, `last updated` | `updateSafetyStatus()`

**Implementation:** **RoadSegment** model (edge in the road graph):
- **Attributes:** `start_lat`, `start_lng`, `end_lat`, `end_lng`, **`base_distance`**, **`predicted_risk_score`**, `last_updated`
- No `roadID` (use `id`), no `name`, no `safetyStatus` (risk is `predicted_risk_score`).
- Risk is updated by the Random Forest pipeline (e.g. `load_mock_data`), not by a method on the model.

**Verdict:** **Misaligned.**
- Rename class to **RoadSegment** (or keep “Road” and note it represents segments).
- **Attributes:** `id`, `start_lat`, `start_lng`, `end_lat`, `end_lng`, `base_distance`, `predicted_risk_score`, `last_updated` (or a shortened set for the diagram).
- **Methods:** Either omit `updateSafetyStatus()` or show it as an external operation (e.g. “risk updated by RoadRiskPredictor”), not a model method.

---

## 7. Evacuation Center

**Diagram:** `centerID`, `name`, `location` | `addCenter()`, `updateCenter()`, `deleteCenter()`

**Implementation:** **EvacuationCenter** model:
- **Attributes:** `id`, `name`, **`latitude`**, **`longitude`**, **`address`**, **`description`**, `created_at`
- Add/edit/delete are done via API or admin, not as model methods.

**Verdict:** **Partial.** Conceptually correct. For accuracy: use `id`, `name`, `latitude`, `longitude`, `address`, `description` (and optionally `created_at`). “Location” can be represented as latitude + longitude. Methods can stay as logical operations (add/update/delete center).

---

## 8. Relationships

| Diagram relationship | Implementation | Verdict |
|----------------------|----------------|---------|
| Residents **submits** Hazard Report (1 : 0..*) | User (role=resident) creates HazardReport | **Correct** |
| MDRRMO **submits** Hazard Report | MDRRMO does not submit; only verifies | **Remove** MDRRMO → submit Hazard Report |
| MDRRMO **manages** Evacuation Center | Admin manages centers (add/edit/delete) | **Correct** |
| Hazard Report **stores** in Data Access Layer | HazardReport persisted via ORM | **Correct** |
| Data Access Layer **stores** Road | RoadSegment stored via ORM | **Correct** (use RoadSegment) |
| Data Access Layer **stores** Evacuation Center | EvacuationCenter stored via ORM | **Correct** |
| MachineLearningModel **analyzes** Road | Random Forest uses segment data; Dijkstra uses RoadSegments | **Correct** (with RoadSegment) |
| MachineLearningModel uses **hazard data** | Naive Bayes + Consensus use hazard reports | **Correct** |
| Residents **use** ML output (e.g. route) | Residents get routes from Dijkstra + segment risk | **Correct** (fix typo “Uaes” → “Uses”) |
| MDRRMO **uses** ML / route | Admin does not get recommended route | **Correct** that there is no MDRRMO → ML/route link |

---

## 9. Missing from Diagram

- **RouteLog** – model that logs a user’s chosen evacuation route (user, evacuation_center, selected_route_risk, created_at). Optional to show if you want to reflect analytics.
- **BaselineHazard** – MDRRMO/official hazard data (separate from crowdsourced HazardReport). Optional for map and bootstrap.
- **Explicit link** from **HazardReport** to **validation algorithms** (Naive Bayes, Consensus) that produce `naive_bayes_score` and `consensus_score`.

---

## 10. Suggested Diagram Corrections (Checklist)

- [ ] Use one **User** entity with `role`; show Residents and MDRRMO as roles or actors that use User.
- [ ] **HazardReport:** Add `latitude`, `longitude`, `status`, `naive_bayes_score`, `consensus_score`, `admin_comment`; only **Residents** submit.
- [ ] **MDRRMO:** Remove `submitHazardReport()` and `viewRecommendedRoute()`; keep `viewMap()`, `manageEvacuationCenter()`, `viewCrowdsourcedHazards()`, `verifyHazardReport()`.
- [ ] **Data Access Layer:** Use `saveUser()` instead of separate saveResident/savePersonnel; add save/retrieve for **RoadSegment**.
- [ ] **Road → RoadSegment:** Attributes: id, start_lat, start_lng, end_lat, end_lng, base_distance, predicted_risk_score, last_updated; no `name`/`safetyStatus`; clarify that risk is updated by Random Forest.
- [ ] **MachineLearningModel:** Either split into NaiveBayesValidator, ConsensusScoringService, RoadRiskPredictor, ModifiedDijkstraService, or keep one box with methods/attributes aligned to these four (no `weatherData`).
- [ ] **Evacuation Center:** Add `address`, `description`; location = latitude + longitude.
- [ ] Remove **MDRRMO → submits → Hazard Report**; add **MDRRMO → verifies → Hazard Report**.
- [ ] Fix typo: “Uaes” → “Uses” (Residents use ML output).

After these changes, the class diagram will match the current implementation and your intended admin behavior (manage reports and evacuation centers, view map with verified reports, no route computation or report submission for admin).
