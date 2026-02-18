# Admin Login Credentials

**Created:** February 8, 2026

---

## 🔐 Django Admin Panel

**URL:** `http://127.0.0.1:8000/admin/`

### **Admin (Superuser)**
```
Username: admin
Password: admin123
Role: Admin/Superuser
```

**Permissions:** Full access to Django admin panel

---

## 👥 Test User Accounts

### **1. MDRRMO User**
```
Username: mdrrmo
Password: mdrrmo123
Role: mdrrmo
Token: f275338533126cd8d0bb35e6b9034551d52e55b5
```

**Can access:**
- ✅ POST `/api/report-hazard/` (can report hazards)
- ✅ POST `/api/calculate-route/` (can calculate routes)
- ✅ GET `/api/mdrrmo/pending-reports/` (MDRRMO only)
- ✅ POST `/api/mdrrmo/approve-report/` (MDRRMO only)
- ✅ Django admin panel (staff access)

**Use for:**
- Testing MDRRMO-specific endpoints
- Approving/rejecting hazard reports
- Admin panel access

---

### **2. Resident User**
```
Username: resident
Password: resident123
Role: resident
Token: 1559aca950b2a0dc0b52fbf8cbfe50d4d3160359
```

**Can access:**
- ✅ POST `/api/report-hazard/` (submit hazard reports)
- ✅ POST `/api/calculate-route/` (calculate evacuation routes)
- ❌ Cannot access MDRRMO endpoints

**Use for:**
- Testing resident hazard reporting
- Testing route calculation
- Simulating regular mobile app user

---

## 🔑 Getting API Tokens

To use the API endpoints that require authentication, you need tokens:

### **Method 1: Django Admin**
1. Go to `http://127.0.0.1:8000/admin/`
2. Login with admin credentials
3. Go to **Authentication and Authorization** → **Tokens**
4. Click **Add Token**
5. Select a user (mdrrmo or resident)
6. Click **Save**
7. Copy the token key

### **Method 2: Django Shell**
```bash
python manage.py shell
```

```python
from rest_framework.authtoken.models import Token
from apps.users.models import User

# Get or create token for MDRRMO
mdrrmo = User.objects.get(username='mdrrmo')
token, created = Token.objects.get_or_create(user=mdrrmo)
print(f"MDRRMO Token: {token.key}")

# Get or create token for Resident
resident = User.objects.get(username='resident')
token, created = Token.objects.get_or_create(user=resident)
print(f"Resident Token: {token.key}")
```

### **Method 3: Create Token Now**
I can create tokens for you. Let me know if you want them!

---

## 🧪 Testing API with Token

### **Example: Report Hazard (Resident)**

1. Get resident token (see methods above)
2. Use in request:

```bash
curl -X POST http://127.0.0.1:8000/api/report-hazard/ \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "hazard_type": "flood",
    "latitude": 14.5995,
    "longitude": 120.9842,
    "description": "Heavy flooding on Main Street"
  }'
```

### **Example: View Pending Reports (MDRRMO)**

```bash
curl -X GET http://127.0.0.1:8000/api/mdrrmo/pending-reports/ \
  -H "Authorization: Token MDRRMO_TOKEN_HERE"
```

---

## 📊 User Summary

| Username | Password | Role | Staff Access | Superuser |
|----------|----------|------|--------------|-----------|
| **admin** | admin123 | Admin | ✅ Yes | ✅ Yes |
| **mdrrmo** | mdrrmo123 | mdrrmo | ✅ Yes | ❌ No |
| **resident** | resident123 | resident | ❌ No | ❌ No |

---

## 🚀 Quick Start

### **1. Access Django Admin**
```
URL: http://127.0.0.1:8000/admin/
Username: admin
Password: admin123
```

### **2. Create More Users (Optional)**
In Django admin:
- Go to **Users** → **Add User**
- Set username, password
- Choose role: "resident" or "mdrrmo"
- Save

### **3. Get Tokens for API Testing**
In Django admin:
- Go to **Tokens** → **Add Token**
- Select user
- Copy token key
- Use in API requests: `Authorization: Token abc123...`

---

## 🔒 Security Notes

**⚠️ FOR DEVELOPMENT ONLY**

These are simple passwords for **development and testing**. 

**For production:**
- ✅ Use strong passwords
- ✅ Use environment variables
- ✅ Enable HTTPS
- ✅ Implement rate limiting
- ✅ Add password complexity requirements
- ✅ Enable 2FA for admin accounts

---

## 📝 Change Password

### **Via Django Admin:**
1. Login to admin panel
2. Go to **Users**
3. Click on username
4. Scroll to **Password** section
5. Click **this form** link
6. Enter new password twice
7. Save

### **Via Command Line:**
```bash
python manage.py changepassword admin
# Enter new password when prompted
```

### **Via Django Shell:**
```python
python manage.py shell
```

```python
from apps.users.models import User
user = User.objects.get(username='admin')
user.set_password('new_password_here')
user.save()
print('Password changed!')
```

---

## ✅ Next Steps

1. ✅ **Login to admin** - `http://127.0.0.1:8000/admin/`
2. ✅ **Create tokens** - For API testing
3. ✅ **Test APIs** - Use Postman or curl
4. ✅ **Add more users** - As needed

---

**All set! You can now access the Django admin panel!** 🎉
