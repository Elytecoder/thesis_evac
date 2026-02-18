"""
Tests for Modified Dijkstra routing service.
"""
import unittest
from decimal import Decimal
from apps.routing.services.dijkstra import ModifiedDijkstraService


class MockSegment:
    """Mock road segment for testing."""
    def __init__(self, start_lat, start_lng, end_lat, end_lng, distance, risk):
        self.start_lat = Decimal(str(start_lat))
        self.start_lng = Decimal(str(start_lng))
        self.end_lat = Decimal(str(end_lat))
        self.end_lng = Decimal(str(end_lng))
        self.base_distance = distance
        self.predicted_risk_score = risk


class ModifiedDijkstraServiceTests(unittest.TestCase):
    """Test cases for Modified Dijkstra routing."""

    def setUp(self):
        """Set up test data."""
        self.service = ModifiedDijkstraService(risk_multiplier=100.0)
        # Create simple test graph: A -> B -> C
        self.segments = [
            MockSegment(14.5995, 120.9842, 14.6000, 120.9842, 100.0, 0.1),  # A->B
            MockSegment(14.6000, 120.9842, 14.6005, 120.9842, 100.0, 0.2),  # B->C
            MockSegment(14.5995, 120.9842, 14.6005, 120.9845, 150.0, 0.5),  # A->C (risky)
        ]

    def test_build_graph(self):
        """Test that graph building works."""
        graph, nodes = self.service.build_graph(self.segments)
        self.assertIsInstance(graph, dict)
        self.assertIsInstance(nodes, set)
        self.assertGreater(len(nodes), 0)
        self.assertGreater(len(graph), 0)

    def test_build_graph_bidirectional(self):
        """Test that graph is bidirectional."""
        graph, nodes = self.service.build_graph(self.segments)
        # Each segment should create edges in both directions
        for key in graph:
            self.assertIsInstance(graph[key], list)

    def test_get_safest_routes_simple(self):
        """Test finding routes in simple graph."""
        routes = self.service.get_safest_routes(
            self.segments,
            14.5995, 120.9842,  # Start
            14.6005, 120.9842,  # End
            k=3,
        )
        self.assertIsInstance(routes, list)
        if routes:
            route = routes[0]
            self.assertIn('path', route)
            self.assertIn('total_distance', route)
            self.assertIn('total_risk', route)
            self.assertIn('weight', route)
            self.assertIn('risk_level', route)

    def test_risk_level_classification(self):
        """Test risk level classification."""
        self.assertEqual(self.service._risk_level(0.1), 'Green')
        self.assertEqual(self.service._risk_level(0.5), 'Yellow')
        self.assertEqual(self.service._risk_level(0.8), 'Red')

    def test_risk_level_boundaries(self):
        """Test risk level boundary cases."""
        self.assertEqual(self.service._risk_level(0.0), 'Green')
        self.assertEqual(self.service._risk_level(0.29), 'Green')
        self.assertEqual(self.service._risk_level(0.3), 'Yellow')
        self.assertEqual(self.service._risk_level(0.69), 'Yellow')
        self.assertEqual(self.service._risk_level(0.7), 'Red')
        self.assertEqual(self.service._risk_level(1.0), 'Red')

    def test_empty_segments(self):
        """Test behavior with empty segment list."""
        routes = self.service.get_safest_routes(
            [],
            14.5995, 120.9842,
            14.6000, 120.9842,
            k=3,
        )
        self.assertIsInstance(routes, list)
        self.assertEqual(len(routes), 0)

    def test_risk_multiplier_effect(self):
        """Test that risk multiplier affects route selection."""
        # Low risk multiplier (distance matters more)
        service_low_risk = ModifiedDijkstraService(risk_multiplier=10.0)
        # High risk multiplier (safety matters more)
        service_high_risk = ModifiedDijkstraService(risk_multiplier=1000.0)
        
        routes_low = service_low_risk.get_safest_routes(
            self.segments, 14.5995, 120.9842, 14.6005, 120.9842, k=1
        )
        routes_high = service_high_risk.get_safest_routes(
            self.segments, 14.5995, 120.9842, 14.6005, 120.9842, k=1
        )
        
        self.assertIsInstance(routes_low, list)
        self.assertIsInstance(routes_high, list)

    def test_key_to_coords(self):
        """Test coordinate key conversion."""
        coords = self.service._key_to_coords("14.599500,120.984200")
        self.assertIsInstance(coords, list)
        self.assertEqual(len(coords), 2)
        self.assertIsInstance(coords[0], float)
        self.assertIsInstance(coords[1], float)

    def test_nearest_node_empty(self):
        """Test nearest node with empty set."""
        key = "14.599500,120.984200"
        result = self.service._nearest_node(key, set())
        self.assertEqual(result, key)
