// Re-export of the canonical Sorsogon address data.
//
// All screens — registration, admin evacuation center management — should
// ultimately converge on the same dataset. This file keeps the import path
// `lib/data/philippine_address_data.dart` working for the registration screen
// while delegating all data to the single canonical file in core/constants/.
export '../core/constants/philippine_address_data.dart';
