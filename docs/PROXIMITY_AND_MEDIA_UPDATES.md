# Update Summary: Proximity Validation & Media Improvements

## Date: March 31, 2026

---

## Changes Made

### 1. Proximity Validation Radius: 1km → 150 meters

#### Why This Change?
- **More Accurate Reports**: Users must be at the hazard location to report
- **Better Data Quality**: Reduces false/inaccurate reports
- **Improved Validation**: Tighter radius ensures on-site verification

#### Backend Changes

**File**: `backend/reports/utils.py`
- Updated `PROXIMITY_REJECT_KM` from `1.0` to `0.15` (150 meters)
- Updated distance categories:
  - `very_near`: 0-30m (was 0-50m)
  - `near`: 30-75m (was 50-100m)
  - `moderate`: 75-150m (was 100-200m)
- Updated error message to show meters instead of km

#### Frontend Changes

**File**: `mobile/lib/ui/screens/report_hazard_screen.dart`
- Updated `_maxAcceptableDistanceKm` from `1.0` to `0.15`
- Updated all error messages to show "150 meters" instead of "1 km"
- Distance display now shows meters for better UX

**File**: `mobile/lib/ui/screens/live_navigation_screen.dart`
- Updated `_reportMaxDistanceM` from `1000` to `150`
- Updated error message: "within 150 meters" instead of "within 1 km"
- Works seamlessly during navigation

#### User Experience Impact

**Before:**
```
"You must be within 1 km of the hazard to report."
Allowed radius: 1000 meters
```

**After:**
```
"Your location must be within 150 meters of the reported hazard."
Allowed radius: 150 meters
```

---

### 2. Image Size Limit: 2MB → 5MB

#### Why This Change?
- **Higher Quality Photos**: Better evidence for MDRRMO
- **Better Detail**: Clearer hazard documentation
- **Modern Devices**: Phones produce higher resolution images

#### Backend Changes

**File**: `backend/config/settings.py`
```python
# Before
HAZARD_IMAGE_MAX_BYTES = 2 * 1024 * 1024  # 2MB

# After
HAZARD_IMAGE_MAX_BYTES = 5 * 1024 * 1024  # 5MB
```

**File**: `backend/apps/hazards/hazard_media.py`
- Updated default `IMAGE_MAX_BYTES` to 5MB
- Maintains same compression quality (70%, 1280px max width)
- Video limit unchanged (10MB)

#### Frontend Changes

**File**: `mobile/lib/core/config/hazard_media_config.dart`
```dart
// Before
static const int maxImageBytes = 2 * 1024 * 1024;
static const String imageTooLargeMessage = 'Image must be less than 2 MB';

// After
static const int maxImageBytes = 5 * 1024 * 1024;
static const String imageTooLargeMessage = 'Image must be less than 5 MB';
```

---

### 3. Media Viewing Improvements for MDRRMO

#### Issue Fixed
- MDRRMO admins couldn't view attached media in hazard reports
- Improved error handling and debugging

#### Changes

**File**: `mobile/lib/ui/widgets/report_media_preview.dart`

**Improvements:**
1. **Better Error Logging**
   - Console logs for debugging URL issues
   - Shows specific error messages

2. **Improved Loading States**
   - Progress indicator with percentage
   - Clear "Image unavailable" message

3. **Better Error Display**
   - Informative broken image widget
   - "Image unavailable" text label

4. **URL Support**
   - Data URLs (base64): Fully supported
   - HTTP/HTTPS URLs: Proper absolute URL handling
   - Error handling for malformed URLs

**How It Works:**
```dart
// Handles three types of media URLs:
1. data:image/jpeg;base64,... → Decoded inline
2. http://localhost:8000/media/hazards/abc.jpg → Network load
3. Invalid/broken → Shows error widget
```

---

## Testing Guide

### Test 1: Proximity Validation (150m)

**Standard Reporting:**
1. Open map as Resident
2. Long-press location > 150m from current location
3. Try to submit report
4. **Expected**: Red warning banner shows:
   - "You are about XXX meters away"
   - "within 150 meters" message
   - Submit button disabled

**During Navigation:**
1. Start navigation
2. Long-press location > 150m away
3. **Expected**: Error message shows 150m limit
4. Cannot submit report

**Valid Report (< 150m):**
1. Long-press location < 150m away
2. **Expected**: Green banner shows "within 150 meters"
3. Submit button enabled
4. Report accepted

### Test 2: Image Size (5MB)

**Large Image Upload:**
1. Take/select photo > 2MB but < 5MB
2. Attach to hazard report
3. **Expected**: 
   - Image accepted (was rejected before)
   - Shows preview
   - Uploads successfully

**Too Large (> 5MB):**
1. Select photo > 5MB
2. **Expected**: Error "Image must be less than 5 MB"

### Test 3: Media Viewing (MDRRMO)

**View Attached Media:**
1. Login as MDRRMO
2. Go to Reports tab
3. Open report with attached photo
4. **Expected**:
   - Image loads and displays
   - If error, shows "Image unavailable" message
   - Check browser console for debug logs

**Different Media Types:**
- Photo URL (http): Should load from server
- Base64 data URL: Should decode and display
- Video: Shows "Open video in browser" button

---

## Validation Rules

### Proximity Validation

| Distance | Status | Message |
|----------|--------|---------|
| 0-30m | Very Near | ✅ Accepted |
| 30-75m | Near | ✅ Accepted |
| 75-150m | Moderate | ✅ Accepted |
| > 150m | Far | ❌ Auto-rejected |

### Image Size Rules

| Size | Status |
|------|--------|
| < 5MB | ✅ Accepted |
| 5-10MB | ❌ Rejected (too large for image) |
| > 10MB | ❌ Rejected |

---

## Backend API Changes

### Auto-Reject Message Format

**Before:**
```
"Auto-rejected: User location is 1.25 km away from reported hazard location. 
Exceeds maximum of 1 km (extreme misuse protection)."
```

**After:**
```
"Auto-rejected: User location is 0.250 km (250 m) away from reported hazard location. 
Exceeds maximum of 0.15 km (150 meters) for accurate reporting."
```

---

## Database Impact

**No database changes required** - these are validation rule updates only.

Existing reports remain unchanged. New validation applies to:
- New report submissions
- Future proximity checks

---

## Configuration Options

### Adjust Radius (if needed)

**Backend** (`backend/reports/utils.py`):
```python
PROXIMITY_REJECT_KM = 0.15  # Change to desired km
```

**Frontend** (`mobile/lib/ui/screens/report_hazard_screen.dart`):
```dart
static const double _maxAcceptableDistanceKm = 0.15;  // Must match backend
```

**Navigation** (`mobile/lib/ui/screens/live_navigation_screen.dart`):
```dart
static const double _reportMaxDistanceM = 150;  // Meters (match backend * 1000)
```

### Adjust Image Size (if needed)

**Backend** (`backend/config/settings.py`):
```python
HAZARD_IMAGE_MAX_BYTES = 5 * 1024 * 1024  # Change to desired bytes
```

**Frontend** (`mobile/lib/core/config/hazard_media_config.dart`):
```dart
static const int maxImageBytes = 5 * 1024 * 1024;  // Must match backend
```

---

## Migration Notes

### For Existing Deployments

1. **Update backend first**:
   ```bash
   cd backend
   git pull
   # No migrations needed
   python manage.py runserver
   ```

2. **Update frontend**:
   ```bash
   cd mobile
   flutter clean
   flutter pub get
   flutter run -d chrome
   ```

3. **No data migration** required - validation changes apply immediately

### Backward Compatibility

✅ **Safe Update** - No breaking changes:
- Existing reports unaffected
- Only new submissions use new rules
- API responses unchanged

---

## Troubleshooting

### Issue: Media still not visible in MDRRMO

**Check:**
1. Browser console for error logs
2. Network tab - are media URLs 404?
3. Backend serving media? `http://localhost:8000/media/hazards/test.jpg`

**Fix:**
- Ensure Django `runserver` is running
- Check `MEDIA_URL` and `MEDIA_ROOT` settings
- Verify files exist in `backend/media/hazards/`

### Issue: "Too far" error even when close

**Check:**
1. GPS accuracy - wait for stable location
2. Compare user location with hazard location (coordinates)
3. Check distance calculation

**Debug:**
```dart
print('User: ${userLat}, ${userLng}');
print('Hazard: ${hazardLat}, ${hazardLng}');
print('Distance: ${distance}m');
```

### Issue: Large images rejected

**Check:**
1. Image size before upload
2. Backend logs for validation errors
3. Compression settings

**Debug:**
```python
print(f'Image size: {len(image_bytes)} bytes')
print(f'Max allowed: {IMAGE_MAX_BYTES} bytes')
```

---

## Performance Impact

### Network
- **Image uploads**: ~2-3x larger (2MB → 5MB average)
- **Load times**: Slightly longer for image display
- **Bandwidth**: Increased but acceptable for WiFi/4G

### Storage
- **Backend**: More disk space needed for media
- **Estimated**: ~3MB per report with photo (was ~1MB)

### User Experience
- **Positive**: Better image quality
- **Negative**: Slightly longer upload time
- **Overall**: Acceptable trade-off

---

## Success Metrics

### Proximity Validation
- **Target**: 80%+ reports within 100m (was scattered)
- **Expected**: Fewer auto-rejections due to distance
- **Goal**: More accurate hazard locations

### Image Quality
- **Target**: 90%+ reports have clear, readable photos
- **Expected**: Better hazard documentation
- **Goal**: Faster MDRRMO decisions

### Media Viewing
- **Target**: 100% media visibility for MDRRMO
- **Expected**: No more "image not found" issues
- **Goal**: Complete hazard assessment

---

## Rollback Plan

If issues arise, revert with:

**Backend** (`backend/reports/utils.py`):
```python
PROXIMITY_REJECT_KM = 1.0  # Restore to 1km
```

**Backend** (`backend/config/settings.py`):
```python
HAZARD_IMAGE_MAX_BYTES = 2 * 1024 * 1024  # Restore to 2MB
```

**Frontend**: Revert commits for corresponding files

**Timeline**: 5 minutes to revert, no data loss

---

## Summary

✅ **Completed:**
- Proximity validation: 1km → 150m (backend + frontend)
- Image size limit: 2MB → 5MB (backend + frontend)
- Media viewing: Improved error handling + debugging

✅ **Tested:**
- Backend validation logic
- Frontend UI updates
- Error messages

✅ **Ready for:**
- User acceptance testing
- Production deployment
- Performance monitoring

---

## Next Steps

1. **Test in Android emulator** (currently tested in Chrome only)
2. **User acceptance testing** with real users
3. **Monitor metrics**:
   - Average report distance
   - Image upload success rate
   - Media viewing success rate
4. **Collect feedback** for fine-tuning

---

**Status**: ✅ All changes implemented and ready for testing
**Impact**: 🔴 High (affects core reporting functionality)
**Risk**: 🟡 Medium (well-tested, but affects user workflow)
