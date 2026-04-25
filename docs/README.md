# Documentation index — HAZNAV

**Project:** HAZNAV (Hazard-Aware Evacuation Navigator) · Bulan, Sorsogon

| Document | Description |
|----------|-------------|
| **[FOLDER_STRUCTURE.md](FOLDER_STRUCTURE.md)** | **Start here** for repository layout: database file, algorithms (Dijkstra, Naive Bayes, Random Forest), Django apps, Flutter `lib/` map |
| [Algorithms_How_They_Work.md](Algorithms_How_They_Work.md) | Detailed algorithm explanations with formulas (NB, rule scoring, RF, Dijkstra, risk evaluation layer) |
| [algorithm-workflow.md](algorithm-workflow.md) | End-to-end workflow narrative: report → validation → MDRRMO → routing → safer routes |
| [ML_IMPLEMENTATION.md](ML_IMPLEMENTATION.md) | ML pipeline reference: datasets, training commands, how to replace synthetic data |
| [OFFLINE_MODE.md](OFFLINE_MODE.md) | Full offline mode documentation: architecture, Hive boxes, connectivity detection, queue lifecycle, auto-sync, UI indicator |
| [HAZARD_CONFIRMATION_SYSTEM.md](HAZARD_CONFIRMATION_SYSTEM.md) | Hazard confirmation flow: duplicate detection, scoring, API endpoints, UI indicators |
| [PROXIMITY_AND_MEDIA_UPDATES.md](PROXIMITY_AND_MEDIA_UPDATES.md) | Proximity gate (150 m auto-reject) and media upload handling |
| [SRS_Software_Requirements_Specification.md](SRS_Software_Requirements_Specification.md) | Software Requirements Specification |
| [Test_Case_Document.md](Test_Case_Document.md) | Test cases |
| [class_diagram_mermaid.md](class_diagram_mermaid.md) / [class_diagram_verification.md](class_diagram_verification.md) | Class diagrams |

**Repository entry points**

- Root **[../README.md](../README.md)** — Install, API overview, features, environment variables
- **[../backend/README.md](../backend/README.md)** — Django setup, email config, deploy, management commands
- **[../mobile/README.md](../mobile/README.md)** — Flutter setup, `api_config`, build

Additional narrative `*.md` files at the repo root (e.g. `COMPLETE_SYSTEM_DOCUMENTATION.md`) are supplementary thesis/project notes. The `archive_unused_files/` folder contains older implementation notes that are superseded by the documents above.
