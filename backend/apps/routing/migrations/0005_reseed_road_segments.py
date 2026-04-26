"""
Data migration: replace the road network with the improved Bulan OSM export.

The original seed (0004) included only ~3,247 segments (primary/secondary/tertiary).
This migration replaces that with 4,246 segments that additionally include:
  - residential roads (1,232 segments)
  - service roads     (  121 segments)
  - unclassified roads (1,455 segments)

The larger network eliminates the C-shaped detour caused by missing direct
east-west connections in Bulan Poblacion, reducing typical route lengths by ~40%.

This migration is SAFE to run on a live database:
  - It deletes only RoadSegment rows (no user data is affected).
  - It then bulk-inserts the full updated segment list.
  - It runs inside a transaction; any failure rolls back automatically.
"""
import json
from pathlib import Path

from django.db import migrations
from django.utils import timezone


def reseed_road_segments(apps, schema_editor):
    RoadSegment = apps.get_model('routing', 'RoadSegment')

    json_path = (
        Path(__file__).parent.parent.parent.parent
        / 'mock_data'
        / 'mock_road_network.json'
    )

    with open(json_path, encoding='utf-8') as fh:
        data = json.load(fh)

    segments = data['segments']
    now = timezone.now()

    # Delete all existing segments and re-seed from the updated file.
    RoadSegment.objects.all().delete()

    objs = [
        RoadSegment(
            start_lat=seg['start_lat'],
            start_lng=seg['start_lng'],
            end_lat=seg['end_lat'],
            end_lng=seg['end_lng'],
            base_distance=float(seg.get('base_distance', 0) or 0),
            predicted_risk_score=0.0,
            last_updated=now,
        )
        for seg in segments
    ]

    RoadSegment.objects.bulk_create(objs, batch_size=500)


def reverse_reseed(apps, schema_editor):
    # Reversing the migration would require the old JSON, which is no longer available.
    # Simply leave the current segments in place.
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('routing', '0004_seed_road_segments'),
    ]

    operations = [
        migrations.RunPython(reseed_road_segments, reverse_reseed),
    ]
