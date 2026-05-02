# Notification System Setup Guide

## Issue Diagnosis

The notification system has **two layers**:

1. **Database Notifications** ✅ WORKING
   - Created when MDRRMO approves/rejects reports
   - Stored in PostgreSQL
   - Displayed in the Notifications screen
   - Residents can view them anytime

2. **Push Notifications (FCM)** ❌ NOT WORKING
   - Real-time push alerts to residents' devices
   - Requires Firebase Cloud Messaging (FCM) configuration
   - **Currently disabled because `FIREBASE_CREDENTIALS` is not set on Render**

## Current Status

**Database notifications ARE working:**
- When MDRRMO approves/rejects a report, a notification is saved to the database
- Residents can see these in the Notifications screen
- The notification includes report details, type, and timestamp

**Push notifications ARE NOT working:**
- Residents do not receive real-time push alerts
- The backend logs: `⚠️  FIREBASE_CREDENTIALS not set — FCM push notifications disabled`
- The FCM code is written and ready, but Firebase Admin SDK is not initialized

## How to Fix: Enable Push Notifications

### Step 1: Get Firebase Service Account Credentials

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create one if you haven't)
3. Click the gear icon ⚙️ → **Project Settings**
4. Go to **Service Accounts** tab
5. Click **Generate New Private Key**
6. Save the downloaded JSON file (e.g., `firebase-credentials.json`)

### Step 2: Encode the Credentials

The credentials must be base64-encoded to store as an environment variable.

**On Windows (PowerShell):**
```powershell
$json = Get-Content firebase-credentials.json -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
[Convert]::ToBase64String($bytes) | Set-Clipboard
```
The encoded string is now in your clipboard.

**On Linux/Mac:**
```bash
base64 -w 0 firebase-credentials.json | pbcopy
```

### Step 3: Set Environment Variable on Render

1. Go to your Render dashboard
2. Select your backend service (thesis-evac)
3. Go to **Environment** section
4. Click **Add Environment Variable**
5. Add:
   - **Key:** `FIREBASE_CREDENTIALS`
   - **Value:** (paste the base64 string from Step 2)
6. Click **Save Changes**
7. Render will automatically redeploy your backend

### Step 4: Verify It's Working

After the redeploy:

1. Check backend logs on Render:
   - Should see: `Firebase Admin SDK initialised successfully.`
   - Should NOT see: `FIREBASE_CREDENTIALS not set`

2. Test the flow:
   - Have a resident submit a hazard report
   - MDRRMO approves/rejects the report
   - Resident should receive a push notification on their device
   - Backend logs should show: `FCM push sent → token abc123...`

## Testing Without Firebase (Current Fallback)

If you don't want to set up Firebase right now, the system still works:

- ✅ Database notifications are saved
- ✅ Residents can view them in the Notifications screen
- ✅ Notification count badge updates
- ❌ No real-time push alerts (residents must open the app to check)

This is acceptable for development/testing but not ideal for production.

## Architecture Reference

### Backend Files
- `backend/apps/notifications/fcm_service.py` - FCM sending logic
- `backend/apps/mobile_sync/views.py:92-134` - Approve/reject background worker
- `backend/apps/mobile_sync/views.py:701-728` - Database notification creation

### Mobile Files
- `mobile/lib/core/services/notification_service.dart` - FCM setup and handlers
- `mobile/lib/main.dart:19-44` - Firebase initialization
- `mobile/lib/ui/screens/notifications_screen.dart` - Notification display UI

### How It Works

1. **Report Approval/Rejection**:
   - MDRRMO calls `/api/mdrrmo/approve-report/` or `/api/mdrrmo/reject-report/`
   - Backend immediately saves notification to database (lines 701-728)
   - Backend spawns background thread to send FCM push (lines 92-134)

2. **FCM Push Delivery**:
   - Background thread calls `fcm_service.send_push()`
   - If `FIREBASE_CREDENTIALS` is set: sends push via Firebase Admin SDK
   - If not set: logs warning and skips (notifications still in database)

3. **Mobile App Receives**:
   - **Foreground**: Shows banner + snackbar with "View" button
   - **Background**: Taps notification → navigates to Notifications screen
   - **Terminated**: Taps notification → opens app + navigates to Notifications screen

## Troubleshooting

### "I set FIREBASE_CREDENTIALS but it's still not working"

1. Check the base64 encoding is correct (no newlines, complete JSON)
2. Verify the service account has the right permissions (Cloud Messaging API enabled)
3. Check backend logs for Firebase initialization errors
4. Ensure the mobile app's FCM token is registered (check `/api/auth/fcm-token/` endpoint)

### "Notifications appear in the app but no push alerts"

This means:
- ✅ Database notifications working
- ❌ FCM not configured

Follow Steps 1-4 above to enable FCM.

### "Push notifications work in development but not production"

- Check if `FIREBASE_CREDENTIALS` is set in production environment (Render)
- Verify you're using the correct Firebase project (dev vs prod)
- Check if the service account key is for the right project

## Summary

**Current state:** Database notifications work, push notifications don't (missing Firebase config).

**To enable push notifications:** Set `FIREBASE_CREDENTIALS` environment variable on Render with base64-encoded service account JSON.

**If you skip this:** App still works, residents just won't get real-time alerts.
