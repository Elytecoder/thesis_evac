from types import SimpleNamespace

from django.test import SimpleTestCase

from apps.mobile_sync.services import route_service


class RouteHazardRiskTests(SimpleTestCase):
    """Route risk should consider only hazards near the actual route polyline."""

    @staticmethod
    def _hazard(
        hazard_id: int,
        hazard_type: str,
        lat: float,
        lng: float,
        score: float = 1.0,
    ):
        return SimpleNamespace(
            id=hazard_id,
            hazard_type=hazard_type,
            latitude=lat,
            longitude=lng,
            final_validation_score=score,
        )

    def test_far_hazards_are_excluded(self):
        # Route runs north-south near lng 123.90000.
        path = [[12.7000, 123.9000], [12.7100, 123.9000]]
        # ~1 km east of path -> should be excluded for flood radius (120 m).
        far_flood = self._hazard(1, 'flood', 12.7050, 123.9090)

        diagnostics = route_service._route_hazard_diagnostics(path, [far_flood])
        self.assertEqual(len(diagnostics), 1)
        self.assertFalse(diagnostics[0]['included'])
        self.assertGreater(diagnostics[0]['distance_to_route_meters'], 120)

        risk = route_service._path_based_hazard_risk(path, [far_flood], diagnostics=diagnostics)
        self.assertEqual(risk, 0.0)

    def test_near_hazard_is_included(self):
        path = [[12.7000, 123.9000], [12.7100, 123.9000]]
        # ~20-25 m east of path.
        near_damage = self._hazard(2, 'road_damage', 12.7050, 123.9002)

        diagnostics = route_service._route_hazard_diagnostics(path, [near_damage])
        self.assertTrue(diagnostics[0]['included'])
        self.assertLessEqual(
            diagnostics[0]['distance_to_route_meters'],
            diagnostics[0]['allowed_radius_meters'],
        )

        risk = route_service._path_based_hazard_risk(path, [near_damage], diagnostics=diagnostics)
        self.assertGreater(risk, 0.0)

        hazards = route_service._hazards_along_path(path, [near_damage], diagnostics=diagnostics)
        self.assertEqual(len(hazards), 1)
        self.assertEqual(hazards[0]['hazard_id'], 2)

    def test_road_blocked_on_route_produces_high_path_risk(self):
        path = [[12.7000, 123.9000], [12.7100, 123.9000]]
        # Directly on route centerline.
        blocked = self._hazard(3, 'road_blocked', 12.7050, 123.9000)

        diagnostics = route_service._route_hazard_diagnostics(path, [blocked])
        self.assertTrue(diagnostics[0]['included'])
        risk = route_service._path_based_hazard_risk(path, [blocked], diagnostics=diagnostics)
        self.assertGreaterEqual(risk, 0.6)

    def test_multiple_far_hazards_not_on_route_are_not_listed(self):
        path = [[12.7000, 123.9000], [12.7100, 123.9000]]
        hazards = [
            self._hazard(10, 'fallen_tree', 12.7050, 123.9080),
            self._hazard(11, 'flood', 12.7060, 123.9100),
            self._hazard(12, 'other', 12.7070, 123.9070),
        ]

        diagnostics = route_service._route_hazard_diagnostics(path, hazards)
        self.assertTrue(all(not d['included'] for d in diagnostics))

        listed = route_service._hazards_along_path(path, hazards, diagnostics=diagnostics)
        self.assertEqual(listed, [])
