"""
Service for route calculation: load segments, run Modified Dijkstra, return 3 safest routes.
"""
from apps.evacuation.models import EvacuationCenter
from apps.routing.models import RoadSegment
from apps.routing.services import ModifiedDijkstraService


def calculate_safest_routes(start_lat, start_lng, evacuation_center_id: int, k: int = 3):
    """
    Return list of up to k safest routes from (start_lat, start_lng) to the evacuation center.
    Each route has path, total_risk, total_distance, risk_level (Green/Yellow/Red).
    """
    try:
        ec = EvacuationCenter.objects.get(pk=evacuation_center_id)
    except EvacuationCenter.DoesNotExist:
        return None
    segments = RoadSegment.objects.all()
    dijkstra = ModifiedDijkstraService()
    routes = dijkstra.get_safest_routes(
        segments,
        float(start_lat), float(start_lng),
        float(ec.latitude), float(ec.longitude),
        k=k,
    )
    return {
        'evacuation_center_id': ec.id,
        'evacuation_center_name': ec.name,
        'routes': routes,
    }
