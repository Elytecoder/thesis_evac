"""
Modified Dijkstra: weight = base_distance + (predicted_risk_score × risk_multiplier).
Returns up to k distinct routes by reusing Dijkstra multiple times: run once for the best
path, then penalize edges used in that path and run again to get alternatives. No new
algorithm; only edge costs are adjusted temporarily via a penalty dict (graph is not mutated).

Component bridging: OSM road data often has small gaps that split the graph into
disconnected sub-graphs. After building the main adjacency list, _bridge_components()
detects all components, then stitches each isolated component to the nearest node in the
growing connected set via a synthetic edge. This is done once per get_safest_routes() call
and ensures Dijkstra can always find a path as long as the road network is geographically
continuous (even if the raw segment data has minor coverage gaps).
"""
import heapq
import math
from collections import defaultdict, deque
from decimal import Decimal
from typing import List, Dict, Any, Tuple, Optional

# Risk multiplier to emphasize safety over pure distance.
# 150 = each risk unit adds 150 m of effective cost; a 100 m segment at risk=1.0
# costs 250 m (2.5×), so Dijkstra avoids truly dangerous roads without routing
# kilometres out of the way to avoid moderate-risk segments (old value 500 caused
# 4-6× detours for segments with risk≈0.5-0.7).
DEFAULT_RISK_MULTIPLIER = 150.0


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
    # 100 m: penalized edges cost ~2× a typical 100 m segment — enough to encourage a different path
    # without routing kilometres out of the way (old value 500 created 15 km alternatives on a 9 km route).
    PENALTY_VALUE = 100.0

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

    # Risk assigned to synthetic bridge edges that fill OSM coverage gaps.
    # 0.0 = no artificial penalty: bridge edges cost only their haversine distance,
    # so Dijkstra treats them like any real road segment. This ensures the shortest
    # valid path is always selected when no real hazards are present, keeping routing
    # consistent with what the road risk layer shows on the map.
    BRIDGE_RISK = 0.0

    def _bridge_components(self, graph: dict, nodes: set) -> dict:
        """
        Detect disconnected graph components and stitch each one to the nearest node
        in the growing connected set via a synthetic bidirectional bridge edge.

        OSM exports of Bulan produce ~65 isolated sub-graphs due to minor data gaps
        (missing junction nodes, slightly offset coordinates).  Without this step,
        Dijkstra returns empty routes whenever the user's snapped start node and the
        evacuation centre's snapped end node lie in different components.

        Algorithm (O(V²) in the number of graph nodes, fast for ≤ ~3 000 nodes):
          1. BFS to discover all components; sort largest-first.
          2. Keep a "connected set" initialised with the main (largest) component.
          3. For each remaining component, find the closest pair of nodes
             (one from the component, one from the connected set) using squared
             lat-lng distance as a cheap proxy.
          4. Add a bidirectional bridge edge with haversine distance and BRIDGE_RISK.
          5. Merge the newly connected component into the connected set.

        Returns a NEW adjacency dict; the original is never mutated.
        """
        def _bfs_comp(start: str) -> set:
            comp: set = set()
            q = deque([start])
            while q:
                n = q.popleft()
                if n in comp:
                    continue
                comp.add(n)
                for v, *_ in graph.get(n, []):
                    if v not in comp:
                        q.append(v)
            return comp

        def _hav_m(la1: float, ln1: float, la2: float, ln2: float) -> float:
            dlat = math.radians(la2 - la1)
            dlng = math.radians(ln2 - ln1)
            a = (math.sin(dlat / 2) ** 2
                 + math.cos(math.radians(la1)) * math.cos(math.radians(la2))
                 * math.sin(dlng / 2) ** 2)
            return 6_371_000.0 * 2.0 * math.asin(min(1.0, math.sqrt(a)))

        # 1. Discover all components
        visited: set = set()
        components: list = []
        for nd in nodes:
            if nd not in visited:
                comp = _bfs_comp(nd)
                visited.update(comp)
                components.append(comp)

        if len(components) <= 1:
            return graph  # already fully connected — nothing to do

        components.sort(key=lambda c: -len(c))

        # 2. Shallow-copy adjacency lists so we can append bridge edges
        bridged: dict = {k: list(v) for k, v in graph.items()}

        connected_set: set = set(components[0])

        # Pre-cache (lat, lng) tuples to avoid repeated string splits
        _coords_cache: dict = {}

        def _coords(key: str):
            if key not in _coords_cache:
                la, ln = key.split(',')
                _coords_cache[key] = (float(la), float(ln))
            return _coords_cache[key]

        # Preload coords for the initial connected set
        for k in connected_set:
            _coords(k)

        # Spatial grid over the connected set for fast nearest-neighbour lookup.
        # Cell size ~2 km so each query searches ≤ a handful of cells.
        GRID_DEG = 0.02
        conn_grid: dict = defaultdict(list)
        for mn in connected_set:
            mla, mln = _coords(mn)
            conn_grid[(int(mla / GRID_DEG), int(mln / GRID_DEG))].append(mn)

        def _nearest_in_connected(query_key: str):
            """Return (nearest_key, dist_sq) from the connected set using grid lookup."""
            qla, qln = _coords(query_key)
            qr = int(qla / GRID_DEG)
            qc = int(qln / GRID_DEG)
            best_d_sq = float('inf')
            best_mn = None
            # Expand search radius until we find at least one candidate
            for radius in range(1, 12):
                for dr in range(-radius, radius + 1):
                    for dc in range(-radius, radius + 1):
                        if abs(dr) != radius and abs(dc) != radius:
                            continue  # only the outer ring of this radius
                        for mn in conn_grid.get((qr + dr, qc + dc), []):
                            mla, mln = _coords(mn)
                            d_sq = (qla - mla) ** 2 + (qln - mln) ** 2
                            if d_sq < best_d_sq:
                                best_d_sq = d_sq
                                best_mn = mn
                # Stop expanding once we've found a node inside the current ring's bbox
                if best_mn is not None:
                    # Ensure we've searched far enough (node could be just outside a ring)
                    if best_d_sq <= (radius * GRID_DEG) ** 2:
                        break
            return best_mn, best_d_sq

        # 3-5. Bridge each isolated component to the connected set
        for comp in components[1:]:
            best_d_sq = float('inf')
            best_cn = best_mn = None

            for cn in comp:
                mn_candidate, d_sq = _nearest_in_connected(cn)
                if mn_candidate is not None and d_sq < best_d_sq:
                    best_d_sq = d_sq
                    best_cn = cn
                    best_mn = mn_candidate

            if best_cn is None:
                continue

            cla, cln = _coords(best_cn)
            mla, mln = _coords(best_mn)
            bridge_dist = _hav_m(cla, cln, mla, mln)
            bridge_w = bridge_dist + self.BRIDGE_RISK * self.risk_multiplier

            if best_cn not in bridged:
                bridged[best_cn] = []
            if best_mn not in bridged:
                bridged[best_mn] = []
            bridged[best_cn].append((best_mn, bridge_w, bridge_dist, self.BRIDGE_RISK))
            bridged[best_mn].append((best_cn, bridge_w, bridge_dist, self.BRIDGE_RISK))

            # Cache coords for newly connected nodes and add them to the spatial grid
            for k in comp:
                kla, kln = _coords(k)
                conn_grid[(int(kla / GRID_DEG), int(kln / GRID_DEG))].append(k)
            connected_set.update(comp)

        return bridged

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
        Public API: build graph from segments, bridge disconnected components,
        find nearest nodes to start/end, return k safest routes with risk level.
        """
        graph, nodes = self.build_graph(segments)
        # Bridge isolated sub-graphs caused by OSM data gaps so Dijkstra can
        # always find a path regardless of which component start/end snap to.
        graph = self._bridge_components(graph, nodes)
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
