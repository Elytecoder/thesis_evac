"""
Data migration: seed the Bulan road network from mock_data/mock_road_network.json.

The JSON file contains 3,247 real OpenStreetMap road segments for Bulan, Sorsogon.
This migration runs exactly ONCE per database (Django records it in django_migrations).
If road segments already exist the migration is a no-op.
"""
import json
from pathlib import Path

from django.db import migrations
from django.utils import timezone


def seed_road_segments(apps, schema_editor):
    RoadSegment = apps.get_model('routing', 'RoadSegment')

    # No-op if already seeded (prevents re-inserting on every fresh DB if run twice)
    if RoadSegment.objects.exists():
        return

    # Locate JSON: this file is at backend/apps/routing/migrations/
    # Four .parent calls → backend/ directory
    json_path = (
        Path(__file__).parent.parent.parent.parent
        / 'mock_data'
        / 'mock_road_network.json'
    )

    with open(json_path, encoding='utf-8') as fh:
        data = json.load(fh)

    segments = data['segments']
    now = timezone.now()

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

    # batch_size keeps individual INSERT statements small (avoids huge SQL strings)
    RoadSegment.objects.bulk_create(objs, batch_size=500)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('routing', '0003_roadsegment_last_updated'),
    ]

    operations = [
        migrations.RunPython(seed_road_segments, noop),
    ]
