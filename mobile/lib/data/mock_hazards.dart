import '../models/baseline_hazard.dart';

/// Mock baseline hazard data (MDRRMO data).
/// 
/// FUTURE: Replace with real API call to /api/bootstrap-sync/
List<BaselineHazard> getMockBaselineHazards() {
  return [
    // Flood hazards in Bulan area
    BaselineHazard(
      id: 1,
      hazardType: 'flood',
      latitude: 12.6700,
      longitude: 123.8760,
      severity: 0.75,
      source: 'MDRRMO',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    BaselineHazard(
      id: 2,
      hazardType: 'flood',
      latitude: 12.6685,
      longitude: 123.8745,
      severity: 0.65,
      source: 'MDRRMO',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
    ),
    
    // Landslide hazards
    BaselineHazard(
      id: 3,
      hazardType: 'landslide',
      latitude: 12.6715,
      longitude: 123.8775,
      severity: 0.80,
      source: 'MDRRMO',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    
    // Fire hazards
    BaselineHazard(
      id: 4,
      hazardType: 'fire',
      latitude: 12.6695,
      longitude: 123.8750,
      severity: 0.55,
      source: 'MDRRMO',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    
    // Storm surge hazards (coastal)
    BaselineHazard(
      id: 5,
      hazardType: 'storm_surge',
      latitude: 12.6680,
      longitude: 123.8735,
      severity: 0.70,
      source: 'MDRRMO',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
  ];
}
