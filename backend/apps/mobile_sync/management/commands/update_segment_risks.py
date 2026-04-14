"""
Django management command: update_segment_risks

Force-recomputes predicted_risk_score for every road segment using the
trained Random Forest model (ml_service).

Features per segment are derived from nearby approved HazardReports:
    flooded_road_count, landslide_count, fallen_tree_count, road_damage_count,
    fallen_electric_post_count, road_blocked_count, bridge_damage_count,
    storm_surge_count, avg_severity

Run this after:
  - Training or retraining the RF model (python manage.py train_ml_models)
  - New hazard reports are approved (to reflect updated risk)
  - Initial data load (mock or real road network)

Usage:
    python manage.py update_segment_risks

# Using synthetic training data (temporary)
# Replace with MDRRMO historical data when available
"""
import time
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = (
        'Recompute predicted_risk_score for all road segments using the '
        'Random Forest model. Run after training or after new hazards are approved.'
    )

    def handle(self, *args, **options):
        from apps.routing.models import RoadSegment
        from apps.hazards.models import HazardReport
        from apps.mobile_sync.services.route_service import (
            recompute_all_segment_risks,
            _compute_segment_rf_features,
        )
        from apps.risk_prediction.services.random_forest import RoadRiskPredictor

        seg_count = RoadSegment.objects.count()
        hazard_count = HazardReport.objects.filter(status='approved').count()

        self.stdout.write(
            f'\n=== Update Segment Risk Scores ===\n'
            f'Road segments : {seg_count}\n'
            f'Approved hazards : {hazard_count}\n'
            '# Using synthetic training data (temporary)\n'
            '# Replace with MDRRMO historical data when available\n'
        )

        if seg_count == 0:
            self.stderr.write(self.style.WARNING(
                'No road segments found. Run: python manage.py load_mock_data'
            ))
            return

        t0 = time.monotonic()
        recompute_all_segment_risks()
        elapsed = time.monotonic() - t0

        # Show a quick sample of resulting scores
        from apps.routing.models import RoadSegment
        import statistics
        scores = list(RoadSegment.objects.values_list('predicted_risk_score', flat=True))
        float_scores = [float(s or 0) for s in scores]
        low  = sum(1 for s in float_scores if s < 0.3)
        mid  = sum(1 for s in float_scores if 0.3 <= s < 0.7)
        high = sum(1 for s in float_scores if s >= 0.7)
        mn   = min(float_scores) if float_scores else 0
        mx   = max(float_scores) if float_scores else 0
        avg  = statistics.mean(float_scores) if float_scores else 0

        self.stdout.write(self.style.SUCCESS(
            f'\n[OK] {seg_count} segments updated in {elapsed:.1f}s\n'
            f'  Risk distribution:\n'
            f'    Low  (< 0.3)  : {low} segments\n'
            f'    Mid  (0.3-0.7): {mid} segments\n'
            f'    High (>= 0.7) : {high} segments\n'
            f'  Range  : {mn:.3f} - {mx:.3f}\n'
            f'  Average: {avg:.3f}'
        ))
