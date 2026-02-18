"""
Management command: load mock data and optionally run risk prediction on road segments.

Usage:
  python manage.py load_mock_data

TO REPLACE WITH REAL MDRRMO DATA:
  Remove or replace this command with: import from MDRRMO CSV/API, then run risk prediction.
"""
from django.core.management.base import BaseCommand
from core.utils.mock_loader import load_baseline_hazards, load_road_network
from apps.routing.models import RoadSegment
from apps.risk_prediction.services import RoadRiskPredictor


class Command(BaseCommand):
    help = 'Load mock hazards and road network; run Random Forest to set segment risk scores.'

    def handle(self, *args, **options):
        n_h = load_baseline_hazards()
        self.stdout.write(self.style.SUCCESS(f'Loaded {n_h} baseline hazards.'))
        n_r = load_road_network()
        self.stdout.write(self.style.SUCCESS(f'Loaded {n_r} road segments.'))

        predictor = RoadRiskPredictor()
        predictor.train()
        updated = 0
        # Assign risk from training data by segment index (mock: segment_id 1..8)
        import json
        from pathlib import Path
        from django.conf import settings
        path = getattr(settings, 'MOCK_DATA_DIR', Path(__file__).resolve().parent.parent.parent.parent.parent / 'mock_data') / 'mock_training_data.json'
        if path.exists():
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            risk_by_id = {r['segment_id']: r['risk_score'] for r in data.get('road_risk_training', [])}
            for i, seg in enumerate(RoadSegment.objects.all(), start=1):
                risk = risk_by_id.get(i, predictor.predict_risk(0, 0))
                seg.predicted_risk_score = risk
                seg.save(update_fields=['predicted_risk_score'])
                updated += 1
        self.stdout.write(self.style.SUCCESS(f'Updated {updated} segment risk scores.'))
