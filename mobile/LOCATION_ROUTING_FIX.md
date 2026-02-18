# 🔧 Location & Routing Issues - FIXES APPLIED

**Date:** February 8, 2026  
**Status:** ✅ **FIXES READY TO TEST**

---

## 🎯 Issues Reported

### 1. Location Not Working
"It won't get the current location of the user"

### 2. Routes Overlapping Buildings
"The routing guide is overlapping again in the buildings not following the roads"

### 3. Hazard Types Need Update
Need to update to final list of 9 hazard types

---

## ✅ Fixes Applied

### Fix 1: Hazard Types Updated

**File:** `lib/ui/screens/report_hazard_screen.dart`

**New hazard types (9 total):**
1. ✅ Flooded Road
2. ✅ Landslide
3. ✅ Fallen Tree
4. ✅ Road Damage
5. ✅ Fallen Electric Post / Wires
6. ✅ Road Blocked
7. ✅ Bridge Damage
8. ✅ Storm Surge
9. ✅ Other

**Removed:**
- Flood (generic)
- Fire
- Storm
- Earthquake
- Typhoon
- Tsunami
- Volcanic
- Power Outage

---

## 🗺️ About Location & Routing

### Current Implementation (OSRM):

Your app **DOES use OSRM** which provides real road-following routes. However, there are a few things to understand:

#### Why Routes Might Still Look Wrong:

**1. Using Emulator Location**
- The Android emulator uses a **default location** unless you set it manually
- Default location may be in California, USA (not Bulan, Sorsogon!)
- OSRM will calculate routes based on the emulator's location

**2. How to Fix Location in Emulator:**

```
Option 1: Set Emulator Location
1. Open Android Studio
2. Tools → Device Manager
3. Click "..." on your emulator
4. Select "Extended Controls"
5. Go to "Location" tab
6. Enter Bulan coordinates:
   Latitude: 12.6699
   Longitude: 123.8758
7. Click "Send"
8. Restart app

Option 2: Use Mock Location in Code
- Set default location to Bulan in map_screen.dart
```

**3. OSRM Needs Real Coordinates**
- If emulator is set to USA location, OSRM will calculate USA roads
- You need to ensure emulator location is set to Bulan, Sorsogon
- Then OSRM will use Philippines roads

---

## 🔍 Debugging Steps

### Check 1: What's the Current Location?

Add this debug code temporarily to see what location the app is getting:

```dart
// In map_screen.dart, line 56 (after getting position)
print('📍 USER LOCATION: ${position.latitude}, ${position.longitude}');
```

If it shows something like `37.7749, -122.4194` (San Francisco), that's the problem!

### Check 2: Is OSRM Being Called?

The routing service already has debug prints:

```dart
print('OSRM failed, trying cache: $e');
print('Using cached routes (offline mode)');
print('Using fallback routes');
```

Check your terminal logs to see which path is being taken.

---

## 🎯 Recommended Solution

### Option A: Set Emulator Location (Easiest)

**In Android Emulator Extended Controls:**
1. Go to Location tab
2. Set to Bulan, Sorsogon:
   ```
   Latitude: 12.6699
   Longitude: 123.8758
   ```
3. Click "Send"
4. Restart app
5. OSRM will now use Philippines roads ✅

### Option B: Force Bulan Location (For Testing)

**Temporarily override location in map_screen.dart:**

```dart
// Line 51-57, replace with:
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);

// TEMPORARY: Force Bulan location for testing
setState(() {
  _userLocation = LatLng(12.6699, 123.8758);  // Force Bulan
  _isLoading = false;
});
```

---

## 🌐 How OSRM Works

```
App requests route
    ↓
Sends coordinates to OSRM
    ↓
OSRM query: 
"From: [User Lat, User Lng]
 To: [Evac Center Lat, Lng]
 Give me road routes"
    ↓
OSRM uses OpenStreetMap data
    ↓
Returns waypoints following roads
    ↓
App draws on map
```

**Critical:** If "User Lat, User Lng" is in USA, OSRM returns USA roads!

---

## 🧪 Testing Checklist

### Test Location Services:

**Step 1:** Check Permissions
```
1. Run app
2. When prompted "Allow location access?"
3. Tap "Allow" or "Allow while using app"
4. Check if blue dot appears on map
```

**Step 2:** Verify Location
```
1. On map screen, note the coordinates
2. Should be near: 12.67, 123.87 (Bulan)
3. If showing 37.xx, -122.xx → Wrong location!
```

**Step 3:** Test Routing
```
1. Tap an evacuation center
2. Wait 2-3 seconds (OSRM loading)
3. Check terminal for debug messages
4. View the routes on map
5. Routes should curve along roads
```

---

## 📝 Quick Diagnostic Commands

### Check if OSRM is reachable:
```powershell
# Test OSRM with Bulan coordinates
curl "https://router.project-osrm.org/route/v1/driving/123.8758,12.6699;123.8770,12.6720?overview=false"
```

Expected response: `{"code":"Ok",...}`

---

## 🔧 Files Modified

1. ✅ `lib/ui/screens/report_hazard_screen.dart` - Updated hazard types (9 final types)
2. ✅ `lib/ui/admin/dashboard_screen.dart` - Fixed type error in charts
3. ✅ `lib/ui/screens/map_screen.dart` - Fixed map controller timing
4. ✅ `lib/ui/screens/routes_selection_screen.dart` - Fixed setState after dispose

---

## 🎯 Summary

### ✅ Fixed:
- Hazard types updated to final 9 types
- Dashboard chart type error resolved
- Map controller timing fixed
- setState lifecycle fixed

### ⚠️ Location Issue:
The location issue is likely due to **emulator using default USA location**.

**Solution:** Set emulator location to Bulan, Sorsogon (12.6699, 123.8758) in Android Emulator Extended Controls.

### ✅ OSRM Still Integrated:
- OSRM is properly integrated
- Will follow real roads when correct location is set
- Currently may be calculating routes for wrong geographic area

---

## 🚀 Next Steps

1. **Run the app** (fixes are applied)
2. **Set emulator location** to Bulan, Sorsogon
3. **Test routing** - should follow roads now
4. **Verify location** - blue dot should be at correct coordinates

---

**Status: Fixes applied, ready for testing with correct emulator location!** ✅
