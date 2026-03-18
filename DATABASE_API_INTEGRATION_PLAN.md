# Database & API Integration Plan

## ✅ Phase 1: Database Setup (COMPLETED)

### 1.1 Django Database Configuration ✅
- **Status**: SQLite configured at `backend/db.sqlite3`
- **Migrations**: All applied successfully
- **Existing Tables**:
  - `users_user` (custom user model with role: resident/mdrrmo)
  - `hazards_hazardreport` (resident reports with AI validation)
  - `hazards_baselinehazard` (MDRRMO official data)
  - `evacuation_evacuationcenter` (evacuation destinations)
  - `routing_roadsegment` (road network for pathfinding)
  - `routing_routelog` (route calculation history)

---

## 🚧 Phase 2: Expand Database Models (TO DO)

### 2.1 Create Notifications Model
**File**: `backend/apps/notifications/models.py` (NEW APP)

```python
class Notification(models.Model):
    class NotificationType(models.TextChoices):
        REPORT_APPROVED = 'approved', 'Report Approved'
        REPORT_REJECTED = 'rejected', 'Report Rejected'
        SYSTEM_ALERT = 'alert', 'System Alert'
    
    user = models.ForeignKey('users.User', on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=NotificationType.choices)
    title = models.CharField(max_length=255)
    message = models.TextField()
    related_report = models.ForeignKey('hazards.HazardReport', null=True, blank=True, on_delete=models.SET_NULL)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
```

### 2.2 Create SystemLog Model
**File**: `backend/apps/system_logs/models.py` (NEW APP)

```python
class SystemLog(models.Model):
    class LogStatus(models.TextChoices):
        SUCCESS = 'success', 'Success'
        WARNING = 'warning', 'Warning'
        FAILED = 'failed', 'Failed'
    
    user = models.ForeignKey('users.User', on_delete=models.SET_NULL, null=True, blank=True)
    user_role = models.CharField(max_length=20)
    user_name = models.CharField(max_length=255)
    action = models.CharField(max_length=255)
    module = models.CharField(max_length=100)
    status = models.CharField(max_length=20, choices=LogStatus.choices)
    details = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
```

### 2.3 Create EmergencyContact Model
**File**: `backend/apps/emergency_contacts/models.py` (NEW APP)

```python
class EmergencyContact(models.Model):
    class ContactType(models.TextChoices):
        POLICE = 'police', 'Police'
        FIRE = 'fire', 'Fire Department'
        AMBULANCE = 'ambulance', 'Ambulance'
        MDRRMO = 'mdrrmo', 'MDRRMO'
        OTHER = 'other', 'Other'
    
    name = models.CharField(max_length=255)
    number = models.CharField(max_length=15)
    type = models.CharField(max_length=20, choices=ContactType.choices)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
```

### 2.4 Expand EvacuationCenter Model
**File**: `backend/apps/evacuation/models.py` (UPDATE)

Add fields:
```python
# Contact information
contact_number = models.CharField(max_length=15, blank=True)
contact_person = models.CharField(max_length=255, blank=True)

# Operational status
is_operational = models.BooleanField(default=True)
deactivated_at = models.DateTimeField(null=True, blank=True)

# Structured address
province = models.CharField(max_length=100, blank=True)
municipality = models.CharField(max_length=100, blank=True)
barangay = models.CharField(max_length=100, blank=True)
street = models.TextField(blank=True)
```

### 2.5 Expand User Model
**File**: `backend/apps/users/models.py` (UPDATE)

Add fields:
```python
# Profile information
full_name = models.CharField(max_length=255, blank=True)
phone_number = models.CharField(max_length=15, blank=True)
barangay = models.CharField(max_length=100, blank=True)
profile_picture = models.URLField(blank=True)

# Account status
is_suspended = models.BooleanField(default=False)
suspended_at = models.DateTimeField(null=True, blank=True)
```

---

## 🚧 Phase 3: Create/Expand Django API Endpoints (TO DO)

### 3.1 Authentication Endpoints
**File**: `backend/apps/auth_api/views.py` (NEW)

```python
POST /api/auth/register/
  Body: {username, email, password, full_name, phone_number, barangay, role}
  Returns: {user, token}

POST /api/auth/login/
  Body: {username, password}
  Returns: {user, token}

POST /api/auth/logout/
  Headers: {Authorization: Token xxx}
  Returns: {message}

GET /api/auth/profile/
  Headers: {Authorization: Token xxx}
  Returns: {user profile}

PUT /api/auth/profile/
  Headers: {Authorization: Token xxx}
  Body: {full_name, phone_number, email, profile_picture}
  Returns: {updated user}
```

### 3.2 Notification Endpoints
**File**: `backend/apps/notifications/views.py` (NEW)

```python
GET /api/notifications/
  Headers: {Authorization: Token xxx}
  Query: ?is_read=false
  Returns: [{id, type, title, message, is_read, created_at}]

POST /api/notifications/{id}/mark-read/
  Headers: {Authorization: Token xxx}
  Returns: {notification}

GET /api/notifications/unread-count/
  Headers: {Authorization: Token xxx}
  Returns: {count}
```

### 3.3 System Logs Endpoints
**File**: `backend/apps/system_logs/views.py` (NEW)

```python
GET /api/system-logs/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Query: ?user_role=&module=&status=&start_date=&end_date=
  Returns: [{id, user_role, user_name, action, module, status, created_at}]

POST /api/system-logs/
  Headers: {Authorization: Token xxx}
  Body: {user_role, user_name, action, module, status, details}
  Returns: {log}
```

### 3.4 User Management Endpoints
**File**: `backend/apps/users/views.py` (UPDATE)

```python
GET /api/users/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Query: ?role=&barangay=&is_suspended=&search=
  Returns: [{id, username, full_name, email, role, barangay, is_suspended}]

GET /api/users/{id}/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Returns: {user details, total_reports_count}

POST /api/users/{id}/suspend/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Returns: {user}

POST /api/users/{id}/activate/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Returns: {user}

DELETE /api/users/{id}/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Returns: {message}
```

### 3.5 Evacuation Center Endpoints (Expand)
**File**: `backend/apps/evacuation/views.py` (UPDATE)

```python
GET /api/evacuation-centers/
  Query: ?is_operational=true
  Returns: [{all fields}]

POST /api/evacuation-centers/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Body: {name, latitude, longitude, address, contact_number, province, municipality, barangay, street}
  Returns: {center}

PUT /api/evacuation-centers/{id}/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Body: {fields to update}
  Returns: {center}

POST /api/evacuation-centers/{id}/deactivate/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Returns: {center}

POST /api/evacuation-centers/{id}/reactivate/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Returns: {center}
```

### 3.6 Hazard Report Endpoints (Expand)
**File**: `backend/apps/hazards/views.py` (UPDATE)

```python
GET /api/hazard-reports/
  Headers: {Authorization: Token xxx}
  Query: ?status=&my_reports=true
  Returns: [{reports}]

GET /api/hazard-reports/verified/
  Query: ?barangay=
  Returns: [{approved reports for map display}]

DELETE /api/hazard-reports/{id}/
  Headers: {Authorization: Token xxx} (own reports only)
  Returns: {message}

POST /api/hazard-reports/{id}/restore/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Body: {restoration_reason}
  Returns: {report}

GET /api/mdrrmo/reports/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Query: ?status=&barangay=&hazard_type=
  Returns: [{full report details with AI analysis}]
```

### 3.7 Emergency Contacts Endpoints
**File**: `backend/apps/emergency_contacts/views.py` (NEW)

```python
GET /api/emergency-contacts/
  Returns: [{all active contacts}]

POST /api/emergency-contacts/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Body: {name, number, type, description}
  Returns: {contact}

PUT /api/emergency-contacts/{id}/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Body: {fields}
  Returns: {contact}

DELETE /api/emergency-contacts/{id}/
  Headers: {Authorization: Token xxx} (MDRRMO only)
  Returns: {message}
```

---

## 🚧 Phase 4: Flutter API Integration (TO DO)

### 4.1 Create API Client Service
**File**: `mobile/lib/core/api/api_client.dart` (NEW)

```dart
class ApiClient {
  static const String baseUrl = 'http://localhost:8000/api';  // Update for production
  final Dio _dio;
  
  // Singleton pattern
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  
  ApiClient._internal() : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  )) {
    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(LogInterceptor());
  }
  
  // GET, POST, PUT, DELETE methods
}
```

### 4.2 Create API Interceptors
**File**: `mobile/lib/core/api/interceptors.dart` (NEW)

- AuthInterceptor: Automatically add token to headers
- ErrorInterceptor: Handle 401 (logout), 403, 500 errors
- LogInterceptor: Debug API calls in development

### 4.3 Update Service Files
Replace mock implementations with API calls:

**AuthService** → Call `/api/auth/*` endpoints
**HazardService** → Call `/api/hazard-reports/*` endpoints
**EvacuationCenterService** → Call `/api/evacuation-centers/*` endpoints
**NotificationService** → Call `/api/notifications/*` endpoints
**SystemLogger** → Call `/api/system-logs/*` endpoints
**EmergencyContactsService** → Call `/api/emergency-contacts/*` endpoints

### 4.4 Implement Offline Caching
**File**: `mobile/lib/core/cache/cache_manager.dart` (NEW)

- Use Hive to cache API responses
- Sync when back online
- Queue actions for offline submission

---

## 🚧 Phase 5: Testing & Validation (TO DO)

### 5.1 Backend Testing
- Test all API endpoints with Postman/curl
- Verify authentication and permissions
- Test MDRRMO-only endpoints
- Verify data persistence in SQLite

### 5.2 Mobile Testing
- Test login/logout flow
- Test hazard reporting (online & offline)
- Test MDRRMO approval workflow
- Test map hazard display
- Test notifications
- Verify offline caching

### 5.3 Integration Testing
- End-to-end resident flow
- End-to-end MDRRMO flow
- Sync behavior after offline period

---

## 🚧 Phase 6: Cleanup (TO DO)

### 6.1 Remove Mock Files
```
mobile/lib/features/admin/admin_mock_service.dart
mobile/lib/features/residents/resident_notifications_service.dart
mobile/lib/features/emergency_contacts/emergency_contacts_service.dart (keep interface, replace implementation)
```

### 6.2 Update Configuration
- Set production API URL
- Configure proper CORS in Django
- Set up proper authentication tokens
- Configure file upload for media

---

## 📊 Current Status

**Phase 1**: ✅ COMPLETED (Database configured, migrations applied)
**Phase 2**: ⏳ PENDING (Need to create new models)
**Phase 3**: ⏳ PENDING (Need to create/expand API endpoints)
**Phase 4**: ⏳ PENDING (Need to integrate APIs in Flutter)
**Phase 5**: ⏳ PENDING (Testing)
**Phase 6**: ⏳ PENDING (Cleanup)

---

## 🎯 Recommended Execution Order

1. **Complete Phase 2** (Expand database models)
2. **Complete Phase 3.1** (Auth endpoints - critical)
3. **Complete Phase 4.1-4.2** (API client in Flutter)
4. **Complete Phase 4.3 (AuthService)** + **Phase 5.1-5.2 (Test auth)**
5. **Complete remaining Phase 3 endpoints** (one module at a time)
6. **Complete remaining Phase 4 services** (one at a time, test each)
7. **Complete Phase 6** (Cleanup mock files)

---

## 💡 Important Notes

1. **This is a multi-session task** - Too large to complete in one go
2. **Test incrementally** - Don't integrate everything at once
3. **Keep mock services temporarily** - Remove only after API integration verified
4. **Django already has good foundation** - Many endpoints already exist
5. **Focus on authentication first** - Everything depends on it
6. **Use existing backend structure** - Don't reinvent the wheel

---

**Next Action**: Do you want me to proceed with Phase 2 (creating new Django models)?
