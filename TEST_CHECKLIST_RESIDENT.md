# RESIDENT BUGS TEST CHECKLIST

Quick manual testing guide for demo verification.

---

## PRE-TEST SETUP

### Test Accounts
- **Resident A:** alice@test.com / password123
- **Resident B:** bob@test.com / password123  
- **MDRRMO:** admin@mdrrmo.com / admin123

### Test Location
- Use a real location in Ormoc City area
- Example: Around Ormoc City Hall (12.6699, 123.8758)

---

## TEST 1: Optimistic UI - Instant Pending Report ⚡

**Goal:** Verify own pending report appears IMMEDIATELY after submission

**Steps:**
1. Login as **Resident A**
2. Long-press any location on map
3. Click "Report Hazard"
4. Select hazard type: "Fallen Tree"
5. Add description: "Large tree blocking road"
6. Take a photo (or select from gallery)
7. Click "Submit Report"
8. ⏱️ **START TIMER** when you click Submit

**Expected Result:**
- ✅ Success dialog appears (~500ms)
- ✅ After closing dialog, pending marker appears IMMEDIATELY (<50ms)
- ✅ No visible delay or loading spinner
- ✅ Marker is orange (pending status)
- ✅ Click marker → full details + photo visible

**Before Fix:** 2-5 seconds delay
**After Fix:** <50ms (instant)

---

## TEST 2: Privacy - Other User Pending Hidden 🔒

**Goal:** Verify other residents cannot see your pending report

**Steps:**
1. Login as **Resident A**
2. Submit pending report at Location X: "Flooded Road"
3. Note the exact coordinates
4. Logout
5. Login as **Resident B**
6. Navigate to Location X (same coordinates)
7. Zoom in to street level

**Expected Result:**
- ✅ Resident B does NOT see any pending marker at Location X
- ✅ Only approved hazards visible (if any)
- ✅ No orange pending markers from other users

**Violation Check:**
- ❌ If you see orange pending marker → BUG (privacy violation)

---

## TEST 3: Duplicate Detection (Hidden Pending) 🔍

**Goal:** Verify duplicate detection works even though pending reports are hidden

**Steps:**
1. Still logged in as **Resident B**
2. Long-press near Location X (~50m away from A's pending report)
3. Click "Report Hazard"
4. Select SAME hazard type: "Flooded Road"
5. Click "Check Similar Reports" or Submit

**Expected Result:**
- ✅ Modal appears: "A similar hazard has already been reported nearby"
- ✅ Shows: hazard type, distance (~50m), status: "Pending verification"
- ✅ Does NOT show: description, photo, reporter name
- ✅ Option to "Confirm Existing Report" or "Submit New Report Anyway"

**Privacy Check:**
- ❌ If modal shows description/photo/name → BUG (privacy leak)

**Confirm Flow:**
1. Click "Confirm Existing Report"
2. ✅ Success message: "Your confirmation has been recorded"
3. ✅ No duplicate report created
4. Login as MDRRMO
5. ✅ Alice's pending report shows confirmation_count = 1

---

## TEST 4: Media Attachments in Own Pending 📷

**Goal:** Verify attached media displays in own pending report

**Steps:**
1. Login as **Resident A**
2. Submit report with both photo AND video
3. Wait for marker to appear (should be instant)
4. Click own pending marker

**Expected Result:**
- ✅ Dialog shows full details
- ✅ "Attachments" section visible
- ✅ Photo thumbnail displays correctly
- ✅ Video thumbnail displays
- ✅ Click photo → opens fullscreen view
- ✅ Supports base64 data URIs and regular URLs

**Before Fix:** No media displayed
**After Fix:** Media displays correctly

---

## TEST 5: Approved Hazard Privacy 👀

**Goal:** Verify approved hazards show only public-safe info to other residents

**Steps:**
1. Login as **Resident A**
2. Submit report: "Road Damage" with description "Large pothole near intersection" + photo
3. Logout, login as **MDRRMO**
4. Approve Resident A's report
5. Logout, login as **Resident B**
6. Navigate to the approved hazard location
7. Click the verified hazard marker (green/red, not orange)

**Expected Result - Resident B sees:**
- ✅ Hazard type: "Road Damage"
- ✅ General location: "Barangay XYZ"
- ✅ Status badge: "Verified"
- ✅ Generic safety message

**Expected Result - Resident B does NOT see:**
- ❌ Original description ("Large pothole near intersection")
- ❌ Attached photo
- ❌ Reporter name (Resident A)
- ❌ Exact submission timestamp

**Owner Check:**
1. Logout, login as **Resident A** (original reporter)
2. Go to "My Reports" tab
3. Find the approved report
4. ✅ Resident A sees FULL details (description + photo)

---

## TEST 6: Route Risk Labels 🚦

**Goal:** Verify routes show correct Green/Yellow/Red risk based on approved hazards

### Scenario A: No Hazards (Green)
1. Login as any resident
2. Select area with no approved hazards
3. Calculate route from Point A to Point B
4. **Expected:** Route shows GREEN label
5. **Verify:** No hazards near route path

### Scenario B: Moderate Risk (Yellow)
1. MDRRMO approves "Road Damage" hazard ~30m from a road
2. Calculate route that passes near this hazard
3. **Expected:** Route shows YELLOW label
4. **Verify:** total_risk between 0.3 and 0.7

### Scenario C: High Risk (Red)
1. MDRRMO approves "Road Blocked" hazard directly on a road
2. Calculate route through this road
3. **Expected:** Route shows RED label or "Possibly Blocked"
4. **Verify:** total_risk ≥ 0.7 or = 1.0

### Scenario D: Pending Does NOT Affect (Critical!)
1. Resident A submits pending "Fallen Tree" on a road
2. **Verify pending marker shows for Resident A only**
3. Calculate route through that road
4. **Expected:** Route risk does NOT increase
5. **Critical:** Only approved hazards affect routing

**Before Fix:** All routes showed HIGH RISK
**After Fix:** Correct Green/Yellow/Red based on actual approved hazards

---

## TEST 7: Offline Queue (Bonus)

**Goal:** Verify offline reports queue correctly and sync when online

**Steps:**
1. Login as **Resident A**
2. Turn on airplane mode
3. Submit hazard report
4. **Expected:** "Saved Offline" dialog
5. **Expected:** Marker appears on map (orange, offline badge)
6. Turn off airplane mode
7. Wait a few seconds
8. **Expected:** Report syncs automatically
9. **Expected:** Marker updates with real server ID

---

## QUICK SMOKE TEST (5 minutes)

If you're in a hurry, run this minimal test:

1. ✅ **Optimistic UI:** Submit report → marker appears INSTANTLY
2. ✅ **Privacy:** Login as different user → pending marker HIDDEN
3. ✅ **Media:** Click own pending marker → photo displays
4. ✅ **Route Risk:** Calculate route → correct GREEN/YELLOW/RED label

All 4 pass = **DEMO READY** ✅

---

## COMMON ISSUES

### Issue: Marker takes 2-5 seconds to appear
- **Cause:** Optimistic UI fix not applied
- **Fix:** Check commit f03555b

### Issue: Other user sees my pending marker  
- **Cause:** Privacy violation
- **Check:** Backend `/verified-hazards/` endpoint
- **Should:** Only return status='approved'

### Issue: All routes show HIGH RISK
- **Cause:** Path format conversion missing
- **Fix:** Check backend views.py:366-369

### Issue: No photo/video in pending marker dialog
- **Cause:** Media array not being read
- **Fix:** Check map_screen.dart:1171-1188

---

## SUCCESS CRITERIA

All tests must pass for demo readiness:

- [x] Optimistic UI (<50ms display)
- [x] Privacy enforcement (pending hidden)
- [x] Duplicate detection (works on hidden)
- [x] Media display (photo/video)
- [x] Public-safe view (approved hazards)
- [x] Route risk (correct labels)

**Status: ✅ READY FOR FINAL DEMO**
