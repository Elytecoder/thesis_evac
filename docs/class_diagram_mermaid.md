# Class Diagram (Mermaid) – Aligned with Current Implementation

Copy the code block below into [Mermaid Live Editor](https://mermaid.live) or any Markdown viewer that supports Mermaid.

```mermaid
classDiagram
    direction TB

    class User {
        -id: int
        -username: string
        -email: string
        -password: string
        -first_name: string
        -last_name: string
        -role: string
        -is_active: boolean
    }

    class Resident {
        +login()
        +viewMap()
        +searchEvacuationCenter()
        +submitHazardReport()
        +viewRecommendedRoute()
    }

    class MDRRMO {
        +login()
        +viewMapWithVerifiedReports()
        +manageEvacuationCenter()
        +viewCrowdsourcedHazards()
        +verifyHazardReport()
    }

    class HazardReport {
        -id: int
        -user_id: int
        -hazard_type: string
        -latitude: decimal
        -longitude: decimal
        -description: string
        -photo_url: string
        -video_url: string
        -status: string
        -naive_bayes_score: float
        -consensus_score: float
        -admin_comment: string
        -created_at: datetime
    }

    class EvacuationCenter {
        -id: int
        -name: string
        -latitude: decimal
        -longitude: decimal
        -address: string
        -description: string
        -created_at: datetime
    }

    class RoadSegment {
        -id: int
        -start_lat: decimal
        -start_lng: decimal
        -end_lat: decimal
        -end_lng: decimal
        -base_distance: float
        -predicted_risk_score: float
        -last_updated: datetime
    }

    class DataAccessLayer {
        +saveUser()
        +saveHazardReport()
        +saveEvacuationCenter()
        +saveRoadSegment()
        +retrieveData()
        +retrieveRoadSegments()
    }

    class ValidationAndRouting {
        +validateReport()
        +predictSegmentRisk()
        +computeSafestRoutes()
    }

    User <|-- Resident : role resident
    User <|-- MDRRMO : role mdrrmo

    Resident "1" --> "*" HazardReport : submits
    MDRRMO "1" --> "*" HazardReport : verifies
    MDRRMO "1" --> "*" EvacuationCenter : manages

    HazardReport --> DataAccessLayer : stores
    EvacuationCenter --> DataAccessLayer : stores
    RoadSegment --> DataAccessLayer : stores
    User --> DataAccessLayer : stores

    ValidationAndRouting ..> HazardReport : uses
    ValidationAndRouting ..> RoadSegment : uses
    Resident ..> ValidationAndRouting : uses
```

---

## Alternative: Show four algorithm components separately

If you prefer to show Naive Bayes, Consensus, Random Forest, and Dijkstra as separate classes:

```mermaid
classDiagram
    direction TB

    class User {
        -id: int
        -username: string
        -email: string
        -password: string
        -role: string
        -is_active: boolean
    }

    class Resident {
        +login()
        +viewMap()
        +searchEvacuationCenter()
        +submitHazardReport()
        +viewRecommendedRoute()
    }

    class MDRRMO {
        +login()
        +viewMapWithVerifiedReports()
        +manageEvacuationCenter()
        +viewCrowdsourcedHazards()
        +verifyHazardReport()
    }

    class HazardReport {
        -id: int
        -user_id: int
        -hazard_type: string
        -latitude: decimal
        -longitude: decimal
        -description: string
        -status: string
        -naive_bayes_score: float
        -consensus_score: float
        -admin_comment: string
        -created_at: datetime
    }

    class EvacuationCenter {
        -id: int
        -name: string
        -latitude: decimal
        -longitude: decimal
        -address: string
        -description: string
    }

    class RoadSegment {
        -id: int
        -start_lat: decimal
        -start_lng: decimal
        -end_lat: decimal
        -end_lng: decimal
        -base_distance: float
        -predicted_risk_score: float
        -last_updated: datetime
    }

    class DataAccessLayer {
        +saveUser()
        +saveHazardReport()
        +saveEvacuationCenter()
        +saveRoadSegment()
        +retrieveData()
    }

    class NaiveBayesValidator {
        +train()
        +validateReport()
    }

    class ConsensusScoringService {
        +count_nearby_reports()
        +combined_score()
    }

    class RoadRiskPredictor {
        +train()
        +predict_risk()
    }

    class ModifiedDijkstraService {
        +build_graph()
        +get_safest_routes()
    }

    User <|-- Resident
    User <|-- MDRRMO

    Resident "1" --> "*" HazardReport : submits
    MDRRMO "1" --> "*" HazardReport : verifies
    MDRRMO "1" --> "*" EvacuationCenter : manages

    HazardReport --> DataAccessLayer : stores
    EvacuationCenter --> DataAccessLayer : stores
    RoadSegment --> DataAccessLayer : stores
    User --> DataAccessLayer : stores

    NaiveBayesValidator ..> HazardReport : uses
    ConsensusScoringService ..> HazardReport : uses
    RoadRiskPredictor ..> RoadSegment : uses
    ModifiedDijkstraService ..> RoadSegment : uses
    Resident ..> ModifiedDijkstraService : uses
```

---

## Notes

- **User** is the single entity for both residents and MDRRMO; **Resident** and **MDRRMO** are roles (shown as subclasses with role-specific methods).
- **MDRRMO** does not submit hazard reports or get recommended routes; they verify reports and manage centers.
- **RoadSegment** replaces “Road” and uses `predicted_risk_score` (from Random Forest).
- **ValidationAndRouting** (first diagram) groups Naive Bayes, Consensus, Random Forest, and Dijkstra; the second diagram shows them as four classes.
