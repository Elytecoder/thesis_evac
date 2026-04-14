"""
Modified Dijkstra: weight = base_distance + (predicted_risk_score × risk_multiplier).
Returns up to k distinct routes by reusing Dijkstra multiple times: run once for the best
path, then penalize edges used in that path and run again to get alternatives. No new
algorithm; only edge costs are adjusted temporarily via a penalty dict (graph is not mutated).
"""
import heapq
from collections import defaultdict
from decimal import Decimal
from typing import List, Dict, Any, Tuple, Optional

# Risk multiplier to emphasize safety over pure distance
DEFAULT_RISK_MULTIPLIER = 500.0


def _float(x) -> float:
    if isinstance(x, Decimal):
        return float(x)
    return float(x)


def _key(lat: float, lng: float) -> str:
    return f"{lat:.6f},{lng:.6f}"


class ModifiedDijkstraService:
    """
    Risk-weighted shortest path: minimizes distance + risk penalty.
    Returns top 3 safest paths with total risk and classification.
    """

    def __init__(self, risk_multiplier: float = DEFAULT_RISK_MULTIPLIER):
        self.risk_multiplier = risk_multiplier

    def build_graph(self, segments) -> Tuple[dict, set]:
        """
        segments: queryset or list of RoadSegment-like objects with
        start_lat, start_lng, end_lat, end_lng, base_distance, predicted_risk_score.
        Returns: (adjacency dict, set of node keys).
        """
        adj = defaultdict(list)
        nodes = set()
        for seg in segments:
            s_lat = _float(seg.start_lat)
            s_lng = _float(seg.start_lng)
            e_lat = _float(seg.end_lat)
            e_lng = _float(seg.end_lng)
            dist = _float(seg.base_distance)
            # Use effective_risk (base + hazard proximity) when set; else predicted_risk_score
            risk = _float(getattr(seg, 'effective_risk', getattr(seg, 'predicted_risk_score', 0)))
            weight = dist + risk * self.risk_multiplier
            sk, ek = _key(s_lat, s_lng), _key(e_lat, e_lng)
            nodes.add(sk)
            nodes.add(ek)
            adj[sk].append((ek, weight, dist, risk))
            # Bidirectional
            adj[ek].append((sk, weight, dist, risk))
        return dict(adj), nodes

    def _dijkstra_one(
        self,
        graph: dict,
        start_key: str,
        end_key: str,
        forbidden_edges: set = None,
        edge_penalty: dict = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Run Dijkstra and return a single route dict, or None if no path.
        forbidden_edges: set of (u, v) to exclude entirely.
        edge_penalty: dict (u,v) -> extra weight so next path prefers to avoid those edges (allows shared tail).
        """
        if start_key not in graph or end_key not in graph:
            return None
        forbidden_edges = forbidden_edges or set()
        edge_penalty = edge_penalty or {}
        dist = {start_key: 0}
        risk_sum = {start_key: 0}
        path_dist = {start_key: 0}
        parent = {}
        pq = [(0, start_key)]
        while pq:
            d, u = heapq.heappop(pq)
            if d > dist.get(u, float('inf')):
                continue
            if u == end_key:
                path = []
                cur = u
                while cur:
                    path.append(cur)
                    cur = parent.get(cur)
                path.reverse()
                return {
                    'path_keys': path,
                    'total_distance': path_dist.get(u, 0),
                    'total_risk': risk_sum.get(u, 0),
                    'weight': dist[u],
                    'risk_level': self._risk_level(risk_sum.get(u, 0)),
                }
            for v, w, d_edge, r_edge in graph[u]:
                if (u, v) in forbidden_edges:
                    continue
                penalty = edge_penalty.get((u, v), 0)
                new_d = dist[u] + w + penalty
                new_risk = risk_sum[u] + r_edge
                new_path_dist = path_dist[u] + d_edge
                if new_d < dist.get(v, float('inf')):
                    dist[v] = new_d
                    risk_sum[v] = new_risk
                    path_dist[v] = new_path_dist
                    parent[v] = u
                    heapq.heappush(pq, (new_d, v))
        return None

    def _path_edges(self, path_keys: list) -> set:
        """Return set of (u, v) and (v, u) edges for the path."""
        if not path_keys or len(path_keys) < 2:
            return set()
        edges = set()
        for i in range(len(path_keys) - 1):
            u, v = path_keys[i], path_keys[i + 1]
            edges.add((u, v))
            edges.add((v, u))
        return edges

    # Penalty added to each edge of a previously used path so next run prefers different edges.
    # Applied only at query time via edge_penalty dict; graph/segments are never mutated → no reset needed.
    PENALTY_VALUE = 500.0

    def dijkstra_k_routes(
        self,
        graph: dict,
        start_key: str,
        end_key: str,
        k: int = 3,
    ) -> List[Dict[str, Any]]:
        """
        Return up to k distinct routes by reusing Dijkstra: run once, penalize used edges, run again.
        Does not modify Dijkstra logic or the graph; only adjusts effective edge cost via penalty dict.
        """
        if start_key not in graph or end_key not in graph:
            return []

        # 1) RUN DIJKSTRA (FIRST ROUTE)
        routes: List[Dict[str, Any]] = []
        edge_penalty: dict = {}  # (u, v) -> extra cost; temporary, not persisted

        for _ in range(k):
            best = self._dijkstra_one(
                graph, start_key, end_key,
                edge_penalty=edge_penalty if edge_penalty else None,
            )
            if best is None:
                break
            path_keys = tuple(best.get('path_keys', []))
            if not path_keys:
                break
            # 6) ENSURE UNIQUE ROUTES: skip if identical to any previous route
            if any(tuple(r.get('path_keys', [])) == path_keys for r in routes):
                break
            routes.append(best)
            # 2) PENALIZE USED EDGES: for each edge in this path, add penalty so next run prefers alternatives
            for e in self._path_edges(best['path_keys']):
                edge_penalty[e] = self.PENALTY_VALUE
        # 5) No reset needed: graph was never mutated; edge_penalty is local to this call.
        return routes

    def _risk_level(self, total_risk: float) -> str:
        """
        Classify accumulated edge risk into a colour band.
        Green < 0.3 | Yellow 0.3–0.7 | Red >= 0.7
        (Matches route_service._risk_level_from_total thresholds.)
        """
        if total_risk < 0.3:
            return 'Green'
        if total_risk < 0.7:
            return 'Yellow'
        return 'Red'

    def get_safest_routes(
        self,
        segments,
        start_lat: float,
        start_lng: float,
        end_lat: float,
        end_lng: float,
        k: int = 3,
    ) -> List[Dict[str, Any]]:
        """
        Public API: build graph from segments, find nearest nodes to start/end,
        return k safest routes with risk level.
        """
        graph, nodes = self.build_graph(segments)
        start_key = _key(_float(start_lat), _float(start_lng))
        end_key = _key(_float(end_lat), _float(end_lng))
        if start_key not in nodes:
            start_key = self._nearest_node(start_key, nodes)
        if end_key not in nodes:
            end_key = self._nearest_node(end_key, nodes)
        routes = self.dijkstra_k_routes(graph, start_key, end_key, k=k)
        # Convert path_keys to list of [lat, lng]
        for r in routes:
            r['path'] = [self._key_to_coords(p) for p in r['path_keys']]
        return routes

    def _nearest_node(self, key: str, nodes: set) -> str:
        """Return nearest node by string key (approximate)."""
        if not nodes:
            return key
        try:
            lat, lng = map(float, key.split(','))
        except Exception:
            return next(iter(nodes))
        best = None
        best_d = float('inf')
        for n in nodes:
            try:
                la, ln = map(float, n.split(','))
                d = (lat - la) ** 2 + (lng - ln) ** 2
                if d < best_d:
                    best_d = d
                    best = n
            except Exception:
                continue
        return best or key

    def _key_to_coords(self, key: str) -> List[float]:
        try:
            lat, lng = key.split(',')
            return [float(lat), float(lng)]
        except Exception:
            return [0, 0]
