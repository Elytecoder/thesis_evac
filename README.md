# AI-Powered Evacuation Routing Application

Mobile app and backend for intelligent evacuation route recommendation (Bulan, Sorsogon). Built with **Flutter** (mobile) and **Django REST** (API).

## Repository structure

| Folder    | Description                    |
|-----------|--------------------------------|
| `backend/`| Django API, routing, hazards   |
| `mobile/` | Flutter app (Android / iOS)    |

## Quick start

**Backend**

```bash
cd backend
python -m venv venv
venv\Scripts\activate   # Windows
pip install -r requirements.txt
python manage.py migrate
python manage.py load_mock_data
python manage.py seed_evacuation_centers
python manage.py runserver
```

**Mobile**

```bash
cd mobile
flutter pub get
flutter run
```

See [backend/README.md](backend/README.md) and [mobile/README.md](mobile/README.md) for details.  
Tech stack and tools: [COMPLETE_TECH_STACK.md](COMPLETE_TECH_STACK.md).
