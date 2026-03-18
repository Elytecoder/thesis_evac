# Evacuation Route Recommendation – Backend

AI-Powered Mobile Application for Intelligent Evacuation Route Recommendation Using Machine Learning and Risk-Weighted Routing.

**Django + Django REST Framework.** SQLite, mock data, schema only. Ready for Render deployment.

---

## Deploy on Render

1. **New Web Service** → Connect this repo, set **Root Directory** to `backend`.
2. **Build Command:** `pip install -r requirements.txt && python manage.py migrate --noinput && python manage.py collectstatic --noinput`
3. **Start Command:** `gunicorn config.wsgi:application --bind 0.0.0.0:$PORT`
4. **Environment:** Set `DJANGO_SECRET_KEY` (generate a long random string). Optionally `DJANGO_DEBUG=False`. Render sets `RENDER_EXTERNAL_HOSTNAME` and `PORT` automatically.

Or use the repo-root **render.yaml** Blueprint (it points `rootDir` to `backend`).

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

**Routing:** Route calculation uses the road network loaded by `load_mock_data`. Without it, the API returns no routes.

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
