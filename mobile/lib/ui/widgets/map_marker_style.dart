import 'package:flutter/material.dart';

/// Shared marker styling so hazard/evacuation icons stay consistent across maps.
class MapMarkerStyle {
  // Evacuation centers (safe destinations)
  static const Color evacuationCenterColor = Color(0xFF0F766E); // teal-700
  static const IconData evacuationCenterIcon = Icons.location_city;

  // Verified hazards (approved by MDRRMO)
  static const Color verifiedHazardColor = Color(0xFFB91C1C); // red-700
  static const IconData verifiedHazardIcon = Icons.warning_amber_rounded;

  // Pending hazards (awaiting review)
  static const Color pendingHazardColor = Color(0xFFC2410C); // orange-700
  static const IconData pendingHazardIcon = Icons.schedule;
}
