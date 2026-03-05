# Evacuation Center Management Improvements

## ✅ COMPLETED (Phase 1)

### 1. Model Updates
- **File**: `mobile/lib/models/evacuation_center.dart`
- ✅ Added `isOperational` boolean field (default: true)
- ✅ Added `deactivatedAt` DateTime field (nullable)
- ✅ Added structured address fields: `province`, `municipality`, `barangay`, `street`, `contactNumber`
- ✅ Added `fullAddress` getter for formatted display
- ✅ Added `operationalStatus` text getter
- ✅ Added `copyWith()` method for immutable updates
- ✅ Updated `fromJson()` and `toJson()` to include all new fields

### 2. Philippine Address Data
- **File**: `mobile/lib/core/constants/philippine_address_data.dart`
- ✅ Created structured address constants
- ✅ Added Sorsogon province data
- ✅ Added all 15 municipalities in Sorsogon
- ✅ Added complete barangay lists for Bulan (60+ barangays)
- ✅ Added barangays for Sorsogon City, Barcelona, Casiguran
- ✅ Implemented cascading dropdown helpers
- ✅ Added address validation logic

### 3. Reverse Geocoding Service
- **File**: `mobile/lib/features/admin/reverse_geocoding_service.dart`
- ✅ Integrated Nominatim OpenStreetMap API
- ✅ Converts GPS coordinates to structured address
- ✅ Extracts province, municipality, barangay, street
- ✅ Handles multiple field name variations
- ✅ 10-second timeout with error handling
- ✅ Philippines and Sorsogon bounds checking

### 4. Admin Mock Service Updates
- **File**: `mobile/lib/features/admin/admin_mock_service.dart`
- ✅ Updated `getEvacuationCenters()` with all new fields
- ✅ Added mock data showing operational/deactivated centers
- ✅ Updated `addEvacuationCenter()` to accept structured address params
- ✅ Updated `updateEvacuationCenter()` to accept structured address params
- ✅ Added `toggleCenterStatus()` method for activation/deactivation
- ✅ Mock center #3 set as deactivated for testing

### 5. Add Evacuation Center Screen (Complete Rewrite)
- **File**: `mobile/lib/ui/admin/add_evacuation_center_screen.dart`
- ✅ Replaced manual address field with cascading dropdowns
- ✅ Province → Municipality → Barangay dropdown chain
- ✅ Automatic reset of dependent dropdowns when parent changes
- ✅ Integrated reverse geocoding on map picker selection
- ✅ Auto-fills province, municipality, barangay, street from GPS
- ✅ Loading indicator during geocoding
- ✅ User-friendly success/warning messages
- ✅ Proper validation (all fields required)
- ✅ Clean, structured layout

---

## 🔄 IN PROGRESS (Phase 2)

### 6. Edit Evacuation Center Screen
- **Next**: Update similar to Add screen
- **Tasks**:
  - Replace manual address with cascading dropdowns
  - Pre-populate dropdowns with existing center data
  - Integrate reverse geocoding for map picker
  - Update save handler to pass structured address params

### 7. Evacuation Center List UI
- **File**: `mobile/lib/ui/admin/evacuation_centers_management_screen.dart`
- **Tasks**:
  - Update operational status badge (green "Operational" / red "Not Operational")
  - Display structured address instead of description
  - Show contact number in card

### 8. Evacuation Center Map View
- **File**: `mobile/lib/ui/admin/evacuation_center_map_view_screen.dart`
- **Tasks**:
  - Update info card to show structured address
  - Display operational status badge
  - Show formatted full address

### 9. Deactivation/Reactivation Modals
- **New Files Needed**:
  - Create confirmation dialogs
  - Implement deactivate confirmation modal
  - Implement reactivate confirmation modal
  - Update center detail screen to show toggle button
  - Call `toggleCenterStatus()` API method

### 10. Routing Exclusion Logic
- **File**: `mobile/lib/features/routing/routing_service.dart`
- **Tasks**:
  - Filter out `isOperational == false` centers
  - Add explanatory comments
  - Ensure resident UI doesn't show deactivated centers

---

## 📋 TESTING CHECKLIST

### Cascading Dropdowns
- [ ] Province selection enables municipality dropdown
- [ ] Municipality selection enables barangay dropdown
- [ ] Changing province resets municipality and barangay
- [ ] Changing municipality resets barangay
- [ ] Cannot save without all address fields

### Reverse Geocoding
- [ ] Map picker opens correctly
- [ ] Selecting location triggers geocoding
- [ ] Loading indicator shows during geocoding
- [ ] Address fields auto-fill successfully
- [ ] Error handled gracefully if geocoding fails
- [ ] Manual editing still works after auto-fill

### Operational Status
- [ ] Green badge shows for operational centers
- [ ] Red badge shows for non-operational centers
- [ ] Deactivation modal confirms action
- [ ] Reactivation modal confirms action
- [ ] Status changes reflect in list immediately

### Routing Exclusion
- [ ] Deactivated centers don't appear in resident routing options
- [ ] Only operational centers available as destinations
- [ ] Route calculation skips deactivated centers

---

## 🔧 TECHNICAL NOTES

### Dependencies Required
- `http` package (for reverse geocoding API)
- Already included in `pubspec.yaml`

### API Integration Points
When connecting to real backend:

1. **GET /api/evacuation-centers/**
   - Returns centers with `is_operational`, `deactivated_at`, address fields

2. **POST /api/evacuation-centers/**
   - Send structured address: `province`, `municipality`, `barangay`, `street`

3. **PATCH /api/evacuation-centers/{id}/toggle-status/**
   - Toggles `is_operational` status

4. **GET /api/routing/centers/?operational_only=true**
   - Used by routing service to get only operational centers

### Database Migration (Backend)
```python
# Add to EvacuationCenter model
is_operational = models.BooleanField(default=True)
deactivated_at = models.DateTimeField(null=True, blank=True)
province = models.CharField(max_length=100)
municipality = models.CharField(max_length=100)
barangay = models.CharField(max_length=100)
street = models.TextField()
contact_number = models.CharField(max_length=50)
```

---

## 🎯 NEXT STEPS

1. Update Edit Evacuation Center Screen
2. Update list and map view UI components
3. Create deactivation/reactivation modals
4. Update routing service exclusion logic
5. Test all functionality end-to-end
6. Create backend migration script
7. Update API documentation

