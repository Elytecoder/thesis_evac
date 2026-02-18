# Evacuation Route Recommendation – Backend

AI-Powered Mobile Application for Intelligent Evacuation Route Recommendation Using Machine Learning and Risk-Weighted Routing.

**Django + Django REST Framework.** SQLite, mock data, schema only. No frontend, no production deployment config.

---

## Quick start

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

- API base: `http://127.0.0.1:8000/api/`
- Admin: `http://127.0.0.1:8000/admin/` (create superuser with `python manage.py createsuperuser`)

---

## Running tests

✅ **83 automated tests covering all models, algorithms, and APIs**

```bash
# Run all tests
python manage.py test

# Run with verbose output
python manage.py test --verbosity=2

# Run specific app tests
python manage.py test apps.validation
```

Run `python manage.py test` for app-specific tests (e.g. `python manage.py test apps.validation`).
