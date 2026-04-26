"""
Management command: audit all EvacuationCenter records against the Bulan road graph.

For each center it prints:
  - Name, lat, lng
  - Distance (meters) to the nearest road-graph node
  - Whether the snap distance is ACCEPTABLE (<= 500 m) or PROBLEM (> 500 m)
  - The nearest node coordinates so you can verify the routing destination

An EC whose nearest-node snap distance is large will produce unrealistically
long (or short) routes because Dijkstra snaps to the wrong part of the graph.

Usage:
    python manage.py check_ec_coordinates
"""
import json
import math
from pathlib import Path

from django.core.management.base import BaseCommand

from apps.evacuation.models import EvacuationCenter


def _haversine_m(la1, ln1, la2, ln2):
    R = 6_371_000
    dlat = math.radians(la2 - la1)
    dlng = math.radians(ln2 - ln1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(la1)) * math.cos(math.radians(la2)) * math.sin(dlng / 2) ** 2
    return R * 2 * math.asin(min(1.0, math.sqrt(a)))


def _load_nodes():
    """Load all unique road-graph node coordinates from mock_road_network.json."""
    json_path = (
        Path(__file__).parent.parent.parent.parent.parent
        / 'mock_data'
        / 'mock_road_network.json'
    )
    with open(json_path, encoding='utf-8') as fh:
        data = json.load(fh)

    nodes = {}
    for seg in data['segments']:
        k1 = (round(seg['start_lat'], 6), round(seg['start_lng'], 6))
        k2 = (round(seg['end_lat'], 6), round(seg['end_lng'], 6))
        nodes[k1] = True
        nodes[k2] = True

    graph_lats = [la for la, ln in nodes]
    graph_lngs = [ln for la, ln in nodes]
    bounds = {
        'min_lat': min(graph_lats), 'max_lat': max(graph_lats),
        'min_lng': min(graph_lngs), 'max_lng': max(graph_lngs),
    }
    return list(nodes.keys()), bounds


def _nearest_node(ec_lat, ec_lng, nodes):
    best_key = None
    best_d = float('inf')
    for la, ln in nodes:
        d = _haversine_m(ec_lat, ec_lng, la, ln)
        if d < best_d:
            best_d = d
            best_key = (la, ln)
    return best_key, best_d


class Command(BaseCommand):
    help = 'Audit EvacuationCenter coordinates against the Bulan road graph.'

    def handle(self, *args, **options):
        try:
            nodes, bounds = _load_nodes()
        except FileNotFoundError as e:
            self.stderr.write(self.style.ERROR(f'Cannot load road network: {e}'))
            return

        self.stdout.write(self.style.SUCCESS(
            f'\nRoad graph bounds: lat {bounds["min_lat"]:.5f}–{bounds["max_lat"]:.5f}, '
            f'lng {bounds["min_lng"]:.5f}–{bounds["max_lng"]:.5f} '
            f'({len(nodes)} unique nodes)\n'
        ))
        self.stdout.write(f'{"Name":<45} {"Lat":>11} {"Lng":>12} {"Snap(m)":>9} {"Status":<12} Nearest node')
        self.stdout.write('-' * 120)

        centers = EvacuationCenter.objects.all().order_by('name')
        problems = []

        for ec in centers:
            ec_lat = float(ec.latitude)
            ec_lng = float(ec.longitude)
            nearest, snap_m = _nearest_node(ec_lat, ec_lng, nodes)

            # Is EC inside the road-graph bounding box?
            in_bounds = (
                bounds['min_lat'] <= ec_lat <= bounds['max_lat'] and
                bounds['min_lng'] <= ec_lng <= bounds['max_lng']
            )

            if snap_m > 500:
                status = self.style.ERROR('! PROBLEM')
                problems.append(ec)
            elif not in_bounds:
                status = self.style.WARNING('! OOB')
                problems.append(ec)
            else:
                status = self.style.SUCCESS('OK')

            nearest_str = f'({nearest[0]:.6f}, {nearest[1]:.6f})' if nearest else 'N/A'
            self.stdout.write(
                f'{ec.name[:44]:<45} {ec_lat:>11.7f} {ec_lng:>12.7f} '
                f'{snap_m:>9.1f} {status:<12} {nearest_str}'
            )

        self.stdout.write('')
        if problems:
            self.stdout.write(self.style.ERROR(
                f'{len(problems)} evacuation center(s) have incorrect / out-of-bounds coordinates.\n'
                'Fix them in the MDRRMO admin panel → Evacuation Centers.\n'
                f'The road graph covers Bulan, Sorsogon: '
                f'lat {bounds["min_lat"]:.5f}–{bounds["max_lat"]:.5f}, '
                f'lng {bounds["min_lng"]:.5f}–{bounds["max_lng"]:.5f}\n'
                'Correct coordinates should place the EC inside or very close to this area.\n'
            ))
        else:
            self.stdout.write(self.style.SUCCESS('All evacuation centers look correct.'))
