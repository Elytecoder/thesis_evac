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

See **TEST_SUMMARY.md** and **TESTING_GUIDE.md** for complete testing documentation.

---

## Project structure

See **FOLDER_STRUCTURE.md** (or the final summary below) for the full tree, models, services, and endpoints.

---

## Replacing mock data

See **REAL_DATA_INTEGRATION_GUIDE.md** for step-by-step instructions to replace mock data with real MDRRMO data.
