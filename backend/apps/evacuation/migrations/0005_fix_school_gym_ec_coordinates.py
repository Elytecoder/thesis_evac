"""
Data migration: correct School Gym Evacuation Center coordinates.

The record was saved with Metro Manila coordinates (14.596, 120.979) instead of
its actual Bulan, Sorsogon location. The road network graph covers
lat 12.64–12.72 / lng 123.86–123.94, so any EC outside that range causes
Dijkstra to snap to a wrong destination and return a nonsensical long route.

TODO: Replace the coordinates below with the verified GPS coordinates of the
      actual School Gym used as an evacuation center in Bulan.
      Run: python manage.py migrate  (after confirming the values)
"""
from django.db import migrations


# ── Update these with the real GPS coordinates of the school gym ──────────────
CORRECT_LATITUDE  = '12.6686400'   # placeholder – within Bulan road graph bounds
CORRECT_LONGITUDE = '123.8820000'  # placeholder – within Bulan road graph bounds
# ─────────────────────────────────────────────────────────────────────────────


def fix_school_gym_coords(apps, schema_editor):
    EvacuationCenter = apps.get_model('evacuation', 'EvacuationCenter')
    # Target the record by name; only update if it still has the wrong Manila coords.
    EvacuationCenter.objects.filter(
        name='School Gym Evacuation Center',
        latitude='14.5960000',
        longitude='120.9790000',
    ).update(
        latitude=CORRECT_LATITUDE,
        longitude=CORRECT_LONGITUDE,
    )


def reverse_fix(apps, schema_editor):
    EvacuationCenter = apps.get_model('evacuation', 'EvacuationCenter')
    EvacuationCenter.objects.filter(
        name='School Gym Evacuation Center',
        latitude=CORRECT_LATITUDE,
        longitude=CORRECT_LONGITUDE,
    ).update(
        latitude='14.5960000',
        longitude='120.9790000',
    )


class Migration(migrations.Migration):

    dependencies = [
        ('evacuation', '0004_normalize_existing_barangay'),
    ]

    operations = [
        migrations.RunPython(fix_school_gym_coords, reverse_fix),
    ]
