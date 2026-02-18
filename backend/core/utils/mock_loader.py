"""
Load mock data into DB (baseline hazards, road network).
TO REPLACE WITH REAL MDRRMO DATA:
1. Remove or bypass this module.
2. Import official MDRRMO CSV/JSON in a management command or script.
3. Validate coordinates and normalize hazard types.
4. Re-run Random Forest training and update RoadSegment.predicted_risk_score.
"""
import json
from pathlib import Path
from django.conf import settings


def get_mock_data_dir() -> Path:
    return getattr(settings, 'MOCK_DATA_DIR', Path(__file__).resolve().parent.parent.parent / 'mock_data')


def load_baseline_hazards():
    """
    Load mock_hazards.json into BaselineHazard table.
    TO REPLACE: Use MDRRMO API/CSV import.
    """
    from apps.hazards.models import BaselineHazard
    path = get_mock_data_dir() / 'mock_hazards.json'
    if not path.exists():
        return 0
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    created = 0
    for item in data.get('baseline_hazards', []):
        _, c = BaselineHazard.objects.get_or_create(
            hazard_type=item['hazard_type'],
            latitude=item['latitude'],
            longitude=item['longitude'],
            defaults={
                'severity': item.get('severity', 0),
                'source': 'MDRRMO',
            },
        )
        if c:
            created += 1
    return created


def load_road_network():
    """
    Load mock_road_network.json into RoadSegment table.
    TO REPLACE: Import OSM or official road network; then run risk prediction.
    """
    from apps.routing.models import RoadSegment
    path = get_mock_data_dir() / 'mock_road_network.json'
    if not path.exists():
        return 0
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    created = 0
    for item in data.get('segments', []):
        seg, c = RoadSegment.objects.get_or_create(
            start_lat=item['start_lat'],
            start_lng=item['start_lng'],
            end_lat=item['end_lat'],
            end_lng=item['end_lng'],
            defaults={'base_distance': item.get('base_distance', 0), 'predicted_risk_score': 0},
        )
        if c:
            created += 1
    return created
