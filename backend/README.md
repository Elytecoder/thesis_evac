# Evacuation Route Recommendation – Backend

AI-powered evacuation routing API: **Django + Django REST Framework**, **SQLite** (`db.sqlite3` in this folder), token auth, and optional **Render** deployment.

**Where things live**

| Topic | Location |
|--------|-----------|
| **Database config** | `config/settings.py` → `DATABASES` (default: `db.sqlite3`) |
| **Modified Dijkstra** | `apps/routing/services/dijkstra.py` |
| **Route API orchestration** | `apps/mobile_sync/services/route_service.py` |
| **Naive Bayes (report score)** | `apps/validation/services/naive_bayes.py` |
| **Report pipeline** | `apps/mobile_sync/services/report_service.py` |
| **Random Forest (segment risk)** | `apps/risk_prediction/services/random_forest.py` |
| **REST API views** | `apps/mobile_sync/views.py`, `apps/users/views.py`, `apps/system_logs/views.py`, … |
| **Auth views (login / register)** | `apps/users/views.py` |
| **Email backend** | `apps/users/backends.py` (authenticates by email + password) |

Full tree + docs index: **[../docs/FOLDER_STRUCTURE.md](../docs/FOLDER_STRUCTURE.md)**.

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

---

## Performance optimizations

The following optimizations were applied to reduce API response time and server overhead:

| Optimization | Detail |
|---|---|
| **Email DB index** | `users_user_email_idx` on `users_user.email` — login lookup uses an index instead of a full table scan (migration `0006_user_email_index`) |
| **GZip compression** | `django.middleware.gzip.GZipMiddleware` compresses all responses — smaller JSON payloads over mobile networks |
| **Token-only auth** | `SessionAuthentication` removed from `REST_FRAMEWORK` — eliminates session middleware overhead on every API request |
| **Single DB write on register** | Password is now hashed and saved in one `create_user()` call instead of `create_user()` + `set_password()` + `save()` |
| **Response-time logging** | `login` and `register` views log `"completed in XXXms"` via Python's `logging` module — visible in server logs for monitoring |
| **Debug prints removed** | All `print()` calls in `send_verification_code` replaced with structured `logger.info()` — eliminates stdout I/O on every verification request |

---

## Documentation

- **[docs/FOLDER_STRUCTURE.md](../docs/FOLDER_STRUCTURE.md)** — Repository layout, database file, algorithms, API modules.
- **[../README.md](../README.md)** — Full-stack overview and API table.
- **`../docs/`** — SRS, test cases, algorithm narratives, diagrams.
