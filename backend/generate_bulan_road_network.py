#!/usr/bin/env python3
"""
generate_bulan_road_network.py
==============================
Downloads the real OSM road network for Bulan, Sorsogon from the Overpass API
and writes a new mock_road_network.json with:
  - primary, secondary, tertiary  (major through-roads)
  - residential, living_street    (neighbourhood / barangay roads)
  - service, unclassified         (access roads, small side streets)
  - track / path (if foot/motor accessible) — optional, set INCLUDE_PATHS=True

Run this from the backend/ folder:
    python generate_bulan_road_network.py

Requirements: requests (pip install requests)

Output: backend/mock_data/mock_road_network.json (overwrites the existing file)
After running, commit the new file and run:
    python manage.py migrate     (if you reset the DB; the seed migration is idempotent)
  OR:
    python manage.py shell -c "
        from apps.routing.models import RoadSegment
        import json
        from pathlib import Path
        RoadSegment.objects.all().delete()
        d = json.load(open('mock_data/mock_road_network.json'))
        from django.utils import timezone
        now = timezone.now()
        objs = [RoadSegment(start_lat=s['start_lat'], start_lng=s['start_lng'],
                            end_lat=s['end_lat'], end_lng=s['end_lng'],
                            base_distance=s['base_distance'], last_updated=now)
                for s in d['segments']]
        RoadSegment.objects.bulk_create(objs, batch_size=500)
        print('Seeded', len(objs), 'road segments')
    "
"""
import json
import math
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit('requests not installed — run: pip install requests')

# ── Configuration ─────────────────────────────────────────────────────────────
# Bounding box for Bulan, Sorsogon (slightly enlarged to capture all entry roads)
BBOX = '12.630,123.845,12.740,123.955'   # (south, west, north, east)

# Road types to include.  Add 'track' and 'path' if walking tracks are needed.
INCLUDE_HIGHWAY_TYPES = {
    'motorway', 'trunk', 'primary', 'secondary', 'tertiary',
    'motorway_link', 'trunk_link', 'primary_link', 'secondary_link', 'tertiary_link',
    'residential', 'living_street', 'service', 'unclassified',
    # 'track', 'path',   # Uncomment to include walking/farm tracks
}

INCLUDE_PATHS = False   # Set True to include tracks and paths

OUTPUT_PATH = Path(__file__).parent / 'mock_data' / 'mock_road_network.json'

# ── Overpass query ─────────────────────────────────────────────────────────────
OVERPASS_URL = 'https://overpass-api.de/api/interpreter'

QUERY = f"""
[out:json][timeout:60];
(
  way["highway"]({BBOX});
);
out body;
>;
out skel qt;
"""

# ── Helpers ───────────────────────────────────────────────────────────────────

def haversine_m(la1, ln1, la2, ln2):
    R = 6_371_000
    dlat = math.radians(la2 - la1)
    dlng = math.radians(ln2 - ln1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(la1))*math.cos(math.radians(la2))*math.sin(dlng/2)**2
    return R * 2 * math.asin(min(1.0, math.sqrt(a)))


def fetch_overpass(query):
    print('Downloading OSM data from Overpass API…')
    headers = {'User-Agent': 'HazNavThesis/1.0 (thesis routing research)'}
    # Try primary and mirror
    for url in [
        'https://overpass-api.de/api/interpreter',
        'https://lz4.overpass-api.de/api/interpreter',
        'https://z.overpass-api.de/api/interpreter',
    ]:
        try:
            resp = requests.post(url, data={'data': query}, headers=headers, timeout=120)
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            print(f'  {url} failed: {e}')
    raise Exception('All Overpass mirrors failed')


def parse_osm(osm_data, include_types, include_paths):
    """
    Convert raw Overpass JSON into a list of (start_lat, start_lng, end_lat, end_lng, dist_m)
    tuples, one per consecutive node pair in each way.

    Each OSM way is treated as BIDIRECTIONAL (the algorithm handles both directions).
    One-way restrictions are intentionally ignored — during evacuation, direction
    restrictions may not apply and bidirectionality prevents graph disconnections.
    """
    # Build node id → (lat, lng)
    nodes = {}
    for el in osm_data.get('elements', []):
        if el['type'] == 'node':
            nodes[el['id']] = (el['lat'], el['lon'])

    segments = []
    skipped = 0

    for el in osm_data.get('elements', []):
        if el['type'] != 'way':
            continue
        tags = el.get('tags', {})
        highway = tags.get('highway', '')
        if not highway:
            continue

        # Filter by road type
        if highway not in include_types:
            if include_paths and highway in ('track', 'path', 'footway', 'cycleway'):
                pass  # allow
            else:
                skipped += 1
                continue

        way_nodes = el.get('nodes', [])
        for i in range(len(way_nodes) - 1):
            nid_a = way_nodes[i]
            nid_b = way_nodes[i + 1]
            if nid_a not in nodes or nid_b not in nodes:
                continue
            la1, ln1 = nodes[nid_a]
            la2, ln2 = nodes[nid_b]
            dist = round(haversine_m(la1, ln1, la2, ln2), 1)
            if dist < 1:
                continue  # ignore degenerate 0-length edges
            segments.append({
                'start_lat': round(la1, 7),
                'start_lng': round(ln1, 7),
                'end_lat':   round(la2, 7),
                'end_lng':   round(ln2, 7),
                'base_distance': dist,
                'road_type': highway,
            })

    return segments, skipped


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print(f'Fetching Bulan road data (bbox: {BBOX})…')
    try:
        osm = fetch_overpass(QUERY)
    except requests.RequestException as e:
        sys.exit(f'Overpass request failed: {e}')

    total_nodes = sum(1 for el in osm.get('elements', []) if el['type'] == 'node')
    total_ways  = sum(1 for el in osm.get('elements', []) if el['type'] == 'way')
    print(f'  Downloaded {total_nodes:,} nodes, {total_ways:,} ways')

    segments, skipped = parse_osm(osm, INCLUDE_HIGHWAY_TYPES, INCLUDE_PATHS)
    print(f'  Kept {len(segments):,} road segments ({skipped:,} ways excluded by type)')

    if len(segments) < 500:
        print('WARNING: Very few segments generated. Check BBOX and highway type filters.')

    # Stats
    from collections import Counter
    type_counts = Counter(s['road_type'] for s in segments)
    print('\nRoad type breakdown:')
    for rtype, count in sorted(type_counts.items(), key=lambda x: -x[1]):
        print(f'  {rtype:<20} {count:>5} segments')

    lats = [s['start_lat'] for s in segments] + [s['end_lat'] for s in segments]
    lngs = [s['start_lng'] for s in segments] + [s['end_lng'] for s in segments]
    print(f'\nLat range: {min(lats):.6f} – {max(lats):.6f}')
    print(f'Lng range: {min(lngs):.6f} – {max(lngs):.6f}')

    output = {
        '_comment': (
            'Real Bulan, Sorsogon road network from OpenStreetMap. '
            f'Generated by generate_bulan_road_network.py. '
            f'{len(segments)} segments including residential/service roads.'
        ),
        'segments': segments,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as fh:
        json.dump(output, fh, indent=2, ensure_ascii=False)

    print(f'\nWrote {len(segments):,} segments -> {OUTPUT_PATH}')
    print('\nNext steps:')
    print('  1. Review the segment count -- 3,000-8,000 is normal for a municipality.')
    print('  2. Re-seed the database:')
    print('     python manage.py shell -c "...(see top of this file for the command)..."')
    print('  3. Commit mock_data/mock_road_network.json and redeploy.')


if __name__ == '__main__':
    main()
