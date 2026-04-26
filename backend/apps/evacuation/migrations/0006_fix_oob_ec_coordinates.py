"""
Data migration: move any EvacuationCenter with coordinates outside the Bulan
road-graph bounding box to a safe placeholder within the network bounds.

WHY THIS IS NEEDED
------------------
The road network covers:
    lat  12.628 – 12.756
    lng 123.848 – 123.957

Any EC whose coordinates fall outside this range will cause the Dijkstra router
to snap to a node far from the intended destination, producing unrealistically
long (or broken) routes.

This migration detects such ECs at deploy time and moves them to a
reasonable placeholder inside Bulan Poblacion so routing works immediately.
The MDRRMO admin should then verify and update each affected center to its
real GPS coordinates via the admin panel.

SAFE to run multiple times — only updates ECs that are genuinely out of bounds.
"""
from django.db import migrations

# ── Road-network bounding box (matches mock_road_network.json bounds) ─────────
GRAPH_MIN_LAT = 12.6280
GRAPH_MAX_LAT = 12.7560
GRAPH_MIN_LNG = 123.8470
GRAPH_MAX_LNG = 123.9580

# ── Safe placeholder coordinates (Bulan Poblacion town centre area) ───────────
# This is a central point in Bulan town, well within the road graph.
# MDRRMO should replace this with the real GPS of each centre.
PLACEHOLDER_LAT = '12.6686400'
PLACEHOLDER_LNG = '123.8800000'

PLACEHOLDER_NOTE = ' [COORDINATES NEED VERIFICATION — auto-corrected from out-of-bounds value]'


def fix_oob_coordinates(apps, schema_editor):
    EvacuationCenter = apps.get_model('evacuation', 'EvacuationCenter')

    updated = []
    for ec in EvacuationCenter.objects.all():
        lat = float(ec.latitude)
        lng = float(ec.longitude)
        in_bounds = (
            GRAPH_MIN_LAT <= lat <= GRAPH_MAX_LAT and
            GRAPH_MIN_LNG <= lng <= GRAPH_MAX_LNG
        )
        if not in_bounds:
            old_lat, old_lng = ec.latitude, ec.longitude
            ec.latitude = PLACEHOLDER_LAT
            ec.longitude = PLACEHOLDER_LNG
            # Append a note to the description so MDRRMO knows to check it
            if PLACEHOLDER_NOTE not in (ec.description or ''):
                ec.description = (ec.description or '') + PLACEHOLDER_NOTE
            ec.save(update_fields=['latitude', 'longitude', 'description'])
            updated.append(f'  {ec.name}: ({old_lat}, {old_lng}) -> placeholder')

    if updated:
        print(
            f'\n[migration] Fixed {len(updated)} out-of-bounds evacuation center(s):\n'
            + '\n'.join(updated)
            + '\nPlease update their real GPS coordinates in the MDRRMO admin panel.\n'
        )


def reverse_fix_oob(apps, schema_editor):
    # Cannot meaningfully reverse — original bad coordinates are unknown.
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('evacuation', '0005_fix_school_gym_ec_coordinates'),
    ]

    operations = [
        migrations.RunPython(fix_oob_coordinates, reverse_fix_oob),
    ]
