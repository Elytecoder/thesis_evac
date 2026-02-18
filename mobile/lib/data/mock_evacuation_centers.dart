import '../models/evacuation_center.dart';

/// Mock Evacuation Centers for Development
/// 
/// These are temporary mock data for UI development.
/// Coordinates are based on Bulan, Sorsogon, Philippines.
/// 
/// FUTURE IMPLEMENTATION:
/// - Replace with API call to backend: GET /api/evacuation-centers/
/// - Store in Hive for offline access
/// - Sync periodically via /api/bootstrap-sync/

List<EvacuationCenter> getMockEvacuationCenters() {
  return [
    EvacuationCenter(
      id: 1,
      name: 'Bulan Gymnasium',
      latitude: 12.6699, // Bulan, Sorsogon approximate coordinates
      longitude: 123.8758,
      description:
          'Main evacuation center. Large capacity with medical facilities and emergency supplies.',
    ),
    EvacuationCenter(
      id: 2,
      name: 'Bulan National High School',
      latitude: 12.6720,
      longitude: 123.8770,
      description:
          'Secondary evacuation center. School buildings converted to shelter with adequate space.',
    ),
    EvacuationCenter(
      id: 3,
      name: 'Barangay Hall Zone 1',
      latitude: 12.6680,
      longitude: 123.8740,
      description:
          'Community center serving as tertiary evacuation point. Basic facilities available.',
    ),
  ];
}
