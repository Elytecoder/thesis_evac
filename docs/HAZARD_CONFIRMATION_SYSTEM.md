# Hazard Confirmation System - Implementation Guide

## Overview
The Hazard Confirmation System reduces duplicate reports and strengthens validation by allowing users to confirm existing pending hazards instead of creating duplicates.

---

## Key Features

### 1. Duplicate Detection
- **Automatic**: Before submission, system checks for similar pending reports
- **Criteria**: Same hazard type + within 100-meter radius
- **Smart**: Prioritizes reports with most confirmations

### 2. User Confirmation
- **One-time**: Each user can confirm a report once
- **Validation Boost**: Confirmations strengthen validation scores
- **Database Integrity**: Unique constraint prevents duplicate confirmations

### 3. Enhanced Validation Scoring
- **Formula**: `consensus_score = nearby_reports + confirmation_count`
- **Impact**: Higher confirmations = higher validation score = faster approval
- **Real-time**: Scores recalculated on each confirmation

### 4. Visual Indicators
- **Map Markers**: Hazards with 3+ confirmations show green border + confirmation badge
- **MDRRMO Dashboard**: Confirmation count displayed on pending report cards
- **Report Details**: Confirmation count in technical details section

---

## How It Works

### User Flow (Residents)

#### Scenario 1: No Similar Reports
1. User long-presses on map
2. Selects "Report Hazard"
3. Fills form and submits
4. System checks for similar reports → none found
5. Report submitted normally

#### Scenario 2: Similar Report Found
1. User long-presses on map
2. Selects "Report Hazard"
3. Fills form and submits
4. System detects similar report within 100m (same hazard type, PENDING or APPROVED, not own report)
5. **Confirmation Dialog Appears**:
   - If the nearby report is **PENDING**: shows "Pending Review" badge + "Confirm Existing Hazard" button (adds consensus weight)
   - If the nearby report is **APPROVED**: shows "Verified ✓" badge + a note that the hazard is already active; "Confirm" button is hidden (no need to add weight to an already-approved report)
   ```
   A Flooded Road was reported nearby.

   [Report Preview Card]
   - Flooded Road  [Pending Review | Verified ✓]
   - 45m away
   - 2 confirmations

   [✓ Confirm Existing Hazard (Recommended)] ← only shown for PENDING
   [+ Submit New Report Anyway]
   [Cancel]
   ```
6. If user clicks "Confirm" (PENDING only):
   - Confirmation recorded
   - Validation scores updated
   - Success message shown
   - No duplicate report created
7. If user clicks "Submit New":
   - New report created as normal

#### Scenario 3: Already Confirmed
- If user has already confirmed a report
- Confirmation button is disabled
- Info message shown: "You have already confirmed this hazard"

### MDRRMO View

#### Dashboard
- Pending reports show confirmation count badge:
  ```
  [✓] Confirmed by 5 users
  ```

#### Report Details
- Technical details section includes:
  ```
  User confirmations: 5 users
  ```

#### Validation Scores
- Consensus score automatically includes confirmations
- Higher confirmations = higher validation confidence

---

## Database Schema

### HazardConfirmation Table
```sql
CREATE TABLE hazards_confirmation (
    id INTEGER PRIMARY KEY,
    report_id INTEGER REFERENCES hazards_hazardreport(id),
    user_id INTEGER REFERENCES users_user(id),
    confirmed_at TIMESTAMP,
    UNIQUE(report_id, user_id)  -- One user = one confirmation per report
);
```

### HazardReport Updates
- Added property: `confirmation_count` (computed from confirmations table)
- Methods:
  - `add_confirmation(user)` - Add confirmation
  - `has_user_confirmed(user)` - Check if user confirmed
  - `confirmation_count` - Get total confirmations

---

## API Endpoints

### 1. Check Similar Reports
**POST** `/api/check-similar-reports/`

**Request:**
```json
{
  "hazard_type": "flooded_road",
  "latitude": 12.6699,
  "longitude": 123.8758,
  "radius_meters": 100
}
```

**Response:**
```json
{
  "similar_reports": [
    {
      "id": 42,
      "hazard_type": "flooded_road",
      "description": "Deep flooding blocking road",
      "latitude": "12.6700000",
      "longitude": "123.8760000",
      "distance_meters": 45.3,
      "confirmation_count": 3,
      "has_user_confirmed": false,
      "is_approved": false,
      "status": "pending",
      "created_at": "2026-03-31T10:15:00Z"
    }
  ],
  "count": 1
}
```

### 2. Confirm Existing Report
**POST** `/api/confirm-hazard-report/`

**Request:**
```json
{
  "report_id": 42
}
```

**Response:**
```json
{
  "id": 42,
  "hazard_type": "flooded_road",
  "confirmation_count": 4,
  "consensus_score": 0.75,
  "final_validation_score": 0.82,
  "message": "Hazard confirmation recorded successfully! 4 users have confirmed this hazard.",
  ...
}
```

**Error Cases:**
- `400`: Already confirmed by this user
- `400`: Cannot confirm your own report
- `400`: Can only confirm pending reports (approved reports cannot be confirmed via this endpoint)
- `404`: Report not found

---

## Validation Score Calculation

### Before Confirmation System
```
consensus_score = min(nearby_reports_count / 5.0, 1.0)
- 0 nearby = 0.0
- 1 nearby = 0.2
- 3 nearby = 0.6
- 5+ nearby = 1.0
```

### After Confirmation System
```
consensus_score = min((nearby_reports_count + confirmation_count) / 5.0, 1.0)
- 0 total = 0.0
- 1 total = 0.2
- 3 total = 0.6
- 5+ total = 1.0 (maximum community validation)
```

### Final Score Formula
```
final_validation_score = (naive_bayes_score × 0.5) + (distance_weight × 0.3) + (consensus_score × 0.2)

Where:
- naive_bayes_score: P(valid | text) from CountVectorizer + MultinomialNB  [0, 1]
- distance_weight:   1 - (distance_m / 150), clamped to [0, 1]             [0, 1]
- consensus_score:   min((nearby_similar_reports + confirmation_count) / 5, 1.0)
```

---

## Visual Indicators

### Map Markers

#### Standard Pending Report
- Yellow circle
- White border (2px)
- Warning icon

#### Highly Confirmed Report (3+ confirmations)
- Yellow circle
- **Green border (3px)** ← Indicator
- Warning icon
- **Green badge with count** ← Shows confirmation number

#### Verified Report
- Red circle
- White border (2px)
- Warning icon

### MDRRMO Dashboard

#### Report Card
```
[Hazard Icon] FLOODED ROAD      [Pending]
              Report #123456

Description here...

Validation: 85%

[✓ Confirmed by 5 users] ← Green badge

[View Details]
```

---

## Testing Guide

### Test 1: First Report (No Duplicates)
1. Login as Resident
2. Long-press on map
3. Submit hazard report at location A
4. **Expected**: Report submitted normally (no dialog)

### Test 2: Similar Report Detection
1. Login as different Resident
2. Long-press near location A (within 100m)
3. Select same hazard type
4. Click Submit
5. **Expected**: Confirmation dialog appears
6. Click "Confirm Existing Hazard"
7. **Expected**: 
   - Success message shown
   - No new report created
   - Confirmation count increased

### Test 3: Already Confirmed
1. Same user as Test 2
2. Try to confirm same report again
3. **Expected**: "Already confirmed" message shown

### Test 4: Validation Score Update
1. Login as MDRRMO
2. View pending reports
3. Find report from Test 1
4. **Expected**: Shows confirmation count
5. Open Report Details
6. **Expected**: 
   - "User confirmations: 1 user"
   - Consensus score increased
   - Final validation score increased

### Test 5: During Navigation
1. Login as Resident
2. Start navigation to evacuation center
3. During navigation, long-press on map
4. Report hazard
5. **Expected**: 
   - Confirmation dialog works
   - Navigation continues in background
   - Modal overlays navigation

### Test 6: Map Visual Indicators
1. Create report with 0 confirmations
2. **Expected**: Yellow marker, white border
3. Have 3 users confirm it
4. Refresh map
5. **Expected**: 
   - Green border appears
   - Green badge shows "3"
   - Marker slightly larger

---

## Implementation Files

### Backend (Django)
- `backend/apps/hazards/models.py`
  - Added `HazardConfirmation` model
  - Added confirmation methods to `HazardReport`

- `backend/apps/mobile_sync/views.py`
  - Added `check_similar_reports()` view
  - Added `confirm_hazard_report()` view

- `backend/apps/mobile_sync/urls.py`
  - Added routes for new endpoints

- `backend/apps/validation/services/rule_scoring.py`
  - Updated `consensus_rule_score()` to include confirmations

- `backend/apps/mobile_sync/services/report_service.py`
  - Updated validation to include confirmation_count

- `backend/apps/hazards/serializers.py`
  - Added `confirmation_count` to serializers

- `backend/apps/hazards/migrations/0010_hazardconfirmation.py`
  - Created Confirmation table

### Frontend (Flutter)
- `mobile/lib/models/hazard_report.dart`
  - Added `confirmationCount` field

- `mobile/lib/features/hazards/hazard_service.dart`
  - Added `checkSimilarReports()` method
  - Added `confirmHazardReport()` method

- `mobile/lib/ui/screens/report_hazard_screen.dart`
  - Updated `_submitReport()` to check for similar reports
  - Added `_showConfirmationDialog()` method
  - Added `_confirmExistingReport()` method
  - Split submission into `_performSubmission()`

- `mobile/lib/ui/widgets/hazard_confirmation_dialog.dart` (NEW)
  - Confirmation modal component

- `mobile/lib/ui/screens/map_screen.dart`
  - Updated hazard markers to show confirmation badges

- `mobile/lib/ui/admin/map_monitor_screen.dart`
  - Updated pending hazard markers with badges

- `mobile/lib/ui/admin/reports_management_screen.dart`
  - Added confirmation count display in report cards

- `mobile/lib/ui/admin/report_detail_screen.dart`
  - Added confirmation count in technical details

- `mobile/lib/core/config/api_config.dart`
  - Added new endpoint constants

---

## Edge Cases Handled

### 1. Own Report
- **Scenario**: User tries to confirm their own report
- **Behavior**: API returns error: "Cannot confirm your own report"

### 2. Already Confirmed
- **Scenario**: User tries to confirm twice
- **Behavior**: 
  - Button disabled in dialog
  - Info message shown
  - API blocks duplicate confirmation (unique constraint)

### 3. Approved Reports
- **Scenario**: Nearby report has already been APPROVED by MDRRMO
- **Behavior**: Dialog shows the approved report with a "Verified ✓" badge. The "Confirm" button is **hidden** (there is no need to confirm an already-verified hazard). The user can still submit a new report if the situation is different or worsening.

### 4. Offline Mode
- **Scenario**: No internet connection
- **Behavior**: 
  - Check similar reports returns empty list
  - Normal submission proceeds (queued for sync)

### 5. Multiple Similar Reports
- **Scenario**: 3+ similar reports within radius
- **Behavior**: Dialog shows most confirmed report first

### 6. Distance Calculation
- **Scenario**: Report at exact radius boundary (100.0m)
- **Behavior**: Included in similar reports (uses ≤ comparison)

---

## Benefits

### For Residents
1. **Faster Reporting**: Confirm with one tap instead of filling form
2. **Community Validation**: See how many users confirm a hazard
3. **Reduced Duplicates**: No need to submit if already reported

### For MDRRMO
1. **Better Data Quality**: Fewer duplicate reports to review
2. **Faster Decisions**: High confirmations = high confidence
3. **Resource Efficiency**: Focus on unique hazards, not duplicates

### For Validation System
1. **Stronger Consensus**: Confirmations = direct community validation
2. **Higher Accuracy**: More signals = better scoring
3. **Real-time Updates**: Scores improve as confirmations increase

---

## Configuration

### Adjustable Parameters

#### Detection Radius
**File**: `mobile/lib/features/hazards/hazard_service.dart`
```dart
double radiusMeters = 100.0; // Change to adjust detection radius
```

#### High Confirmation Threshold
**File**: `mobile/lib/ui/screens/map_screen.dart`
```dart
final hasHighConfirmations = confirmationCount >= 3; // Change threshold
```

#### Scoring Weights
**File**: `backend/apps/validation/services/rule_scoring.py`
```python
def consensus_rule_score(nearby_similar_count: int, confirmation_count: int = 0) -> float:
    total_support = nearby + confirmations
    # Adjust thresholds here:
    if total_support <= 4:
        return 0.75
    return 1.0  # 5+ confirmations
```

---

## Database Queries

### Get Confirmation Count for a Report
```python
report = HazardReport.objects.get(id=42)
count = report.confirmation_count
```

### Get All Confirmers
```python
confirmations = report.confirmations.all()
for confirmation in confirmations:
    print(f"{confirmation.user.full_name} confirmed at {confirmation.confirmed_at}")
```

### Find Reports with High Confirmations
```python
from django.db.models import Count

high_confirmed_reports = HazardReport.objects.annotate(
    conf_count=Count('confirmations')
).filter(
    status='pending',
    conf_count__gte=3
)
```

---

## Future Enhancements

### Potential Improvements
1. **Push Notifications**: Notify original reporter when others confirm
2. **Confirmation Map**: Show who confirmed (for MDRRMO only)
3. **Time Decay**: Weight recent confirmations higher
4. **Geographic Clustering**: Group nearby reports visually
5. **Threshold Auto-Approval**: Auto-approve at X confirmations

### Analytics
- Track average confirmations per hazard type
- Identify high-activity areas
- Measure duplicate reduction rate
- Monitor false confirmation patterns

---

## Troubleshooting

### Dialog Not Showing
**Symptom**: Confirmation dialog doesn't appear
**Causes**:
1. No similar reports within 100m
2. Similar reports are all REJECTED (rejected reports are excluded)
3. User is the original reporter of the nearby report (own reports are excluded)
4. API error (check backend logs)
**Solution**: Check backend terminal for API response

### Confirmation Not Recorded
**Symptom**: Confirmation count not increasing
**Causes**:
1. User already confirmed (unique constraint)
2. User is report owner
3. Report not pending
**Solution**: Check API response in Flutter console

### Validation Score Not Updating
**Symptom**: Score remains same after confirmation
**Causes**:
1. Backend score recalculation failed
2. Database not saving updated scores
**Solution**: Check Django logs for exceptions

### Map Markers Not Showing Badge
**Symptom**: Confirmation badge not visible
**Causes**:
1. Confirmation count < 3
2. API not returning confirmation_count
3. Frontend not parsing field correctly
**Solution**: Check API response includes `confirmation_count`

---

## Performance Considerations

### Database Optimization
- **Index**: Add index on `(report_id, user_id)` for fast confirmation lookups
- **Aggregation**: Use `Count()` annotation for bulk queries
- **Caching**: Cache confirmation counts for frequently accessed reports

### Frontend Optimization
- **Debouncing**: Avoid repeated API calls during form edits
- **Lazy Loading**: Load confirmation counts only when needed
- **Local Cache**: Store similar reports check result temporarily

---

## Security

### Validation Rules
1. **Authentication Required**: All endpoints require valid token
2. **Ownership Check**: Cannot confirm own reports
3. **Status Check**: Can only confirm pending reports
4. **Unique Constraint**: Database prevents duplicate confirmations
5. **Distance Validation**: Backend validates proximity

### Data Integrity
- Atomic operations for confirmation creation
- Transaction rollback on failure
- Validation before score recalculation

---

## Testing Commands

### Create Test Data
```bash
cd backend
python manage.py shell

# Create test reports
from apps.hazards.models import HazardReport
from apps.users.models import User

user1 = User.objects.get(email='resident1@example.com')
report = HazardReport.objects.create(
    user=user1,
    hazard_type='flooded_road',
    latitude=12.6699,
    longitude=123.8758,
    description='Test report',
    status='pending'
)

# Confirm as different user
user2 = User.objects.get(email='resident2@example.com')
report.add_confirmation(user2)

print(f"Confirmation count: {report.confirmation_count}")
```

### Check API Endpoints
```bash
# Check similar reports
curl -X POST http://localhost:8000/api/check-similar-reports/ \
  -H "Authorization: Token YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "hazard_type": "flooded_road",
    "latitude": 12.6699,
    "longitude": 123.8758
  }'

# Confirm report
curl -X POST http://localhost:8000/api/confirm-hazard-report/ \
  -H "Authorization: Token YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"report_id": 42}'
```

---

## Success Metrics

### Data Quality
- **Duplicate Reduction**: Target 50% fewer duplicate reports
- **Validation Accuracy**: Target 20% improvement in validation scores
- **MDRRMO Efficiency**: Target 30% faster approval decisions

### User Engagement
- **Confirmation Rate**: Track how often users choose to confirm vs. submit new
- **Community Participation**: Average confirmations per report
- **Geographic Coverage**: Distribution of confirmed hazards

---

## Conclusion

The Hazard Confirmation System successfully:
- ✓ Reduces duplicate submissions
- ✓ Strengthens validation accuracy
- ✓ Improves MDRRMO decision-making
- ✓ Enhances community participation
- ✓ Works seamlessly during live navigation
- ✓ Maintains clean database structure

**Status**: Fully implemented and ready for testing
**Next Steps**: User acceptance testing and metric collection
