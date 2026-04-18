# Evacuation Route Recommendation – Backend

AI-powered evacuation routing API: **Django + Django REST Framework**, **SQLite** (`db.sqlite3` in this folder), token auth, and optional **Render** deployment.

**Where things live**

| Topic | Location |
|--------|-----------|
| **Database config** | `config/settings.py` → `DATABASES` (default: `db.sqlite3`) |
| **Modified Dijkstra** | `apps/routing/services/dijkstra.py` |
| **Route API orchestration** | `apps/mobile_sync/services/route_service.py` |
| **Naive Bayes (report score)** | `apps/validation/services/naive_bayes.py` |
| **Rule scoring (distance + consensus)** | `apps/validation/services/rule_scoring.py` |
| **Report pipeline** | `apps/mobile_sync/services/report_service.py` |
| **Random Forest (segment risk)** | `apps/risk_prediction/services/random_forest.py` |
| **REST API views** | `apps/mobile_sync/views.py`, `apps/users/views.py`, `apps/system_logs/views.py`, … |
| **Auth views (login / register / email verify)** | `apps/users/views.py` |
| **Email backend** | `apps/users/backends.py` (authenticates by email + password) |

Full tree + docs index: **[../docs/FOLDER_STRUCTURE.md](../docs/FOLDER_STRUCTURE.md)**.

---

## Deploy on Render

1. **New Web Service** → Connect this repo, set **Root Directory** to `backend`.
2. **Build Command:** `pip install -r requirements.txt && python manage.py migrate --noinput && python manage.py collectstatic --noinput`
3. **Start Command:** `gunicorn config.wsgi:application --bind 0.0.0.0:$PORT`
4. **Environment:** Set the required variables below. Render sets `RENDER_EXTERNAL_HOSTNAME` and `PORT` automatically.

Or use the repo-root **render.yaml** Blueprint (it points `rootDir` to `backend`).

### Required environment variables

| Variable | Value |
|----------|-------|
| `DJANGO_SECRET_KEY` | Long random string — generate with `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"` |
| `DJANGO_DEBUG` | `False` |
| `BREVO_API_KEY` | Your Brevo API key (`xkeysib-...`) — for transactional email |
| `DEFAULT_FROM_EMAIL` | Verified sender email in your Brevo account |

### Optional environment variables

| Variable | Default | Notes |
|----------|---------|-------|
| `EMAIL_HOST_USER` | — | SMTP username (local fallback only; not used when `BREVO_API_KEY` is set) |
| `EMAIL_HOST_PASSWORD` | — | SMTP app password (local fallback only) |
| `SYSTEM_LOG_RETENTION_DAYS` | `30` | Days to keep system audit logs |

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

**Email (local):** Set `EMAIL_HOST_USER` and `EMAIL_HOST_PASSWORD` as environment variables before `runserver` to use Gmail SMTP locally. On Render, set `BREVO_API_KEY` and `DEFAULT_FROM_EMAIL` instead (Render blocks outbound SMTP, but Brevo HTTP API works).

```powershell
# Windows PowerShell — local Gmail SMTP
$env:EMAIL_HOST_USER="your@gmail.com"
$env:EMAIL_HOST_PASSWORD="your-app-password"
python manage.py runserver
```

---

## Management commands

| Command | Description |
|---------|-------------|
| `python manage.py migrate` | Apply all database migrations |
| `python manage.py load_mock_data` | Load road network + assign segment risk scores (required for routing) |
| `python manage.py seed_evacuation_centers` | Seed initial evacuation center data |
| `python manage.py createsuperuser` | Create a Django admin superuser |
| `python manage.py train_ml_models` | Retrain both Naive Bayes and Random Forest models |
| `python manage.py train_ml_models --nb-only` | Retrain Naive Bayes only |
| `python manage.py train_ml_models --rf-only` | Retrain Random Forest + update all segment risk scores |
| `python manage.py update_segment_risks` | Refresh `predicted_risk_score` for all segments from current RF model |
| `python manage.py collectstatic --noinput` | Collect static files (required for Render deploy) |

---

## Running tests

```bash
# Run all tests
python manage.py test

# Run with verbose output
python manage.py test --verbosity=2

# Run specific app tests
python manage.py test apps.validation
python manage.py test apps.mobile_sync
```

---

## Performance optimizations

| Optimization | Detail |
|---|---|
| **Email DB index** | `users_user_email_idx` on `users_user.email` — login lookup uses an index instead of a full table scan (migration `0006_user_email_index`) |
| **GZip compression** | `django.middleware.gzip.GZipMiddleware` compresses all responses — smaller JSON payloads over mobile networks |
| **Token-only auth** | `SessionAuthentication` removed from `REST_FRAMEWORK` — eliminates session middleware overhead on every API request |
| **Single DB write on register** | Password is now hashed and saved in one `create_user()` call instead of `create_user()` + `set_password()` + `save()` |
| **Response-time logging** | `login` and `register` views log `"completed in XXXms"` via Python's `logging` module — visible in server logs for monitoring |
| **Synchronous Brevo email** | Email sent directly via HTTPS (not in a daemon thread) — Gunicorn cannot kill it before it completes; `print(flush=True)` ensures the result always appears in Render logs |

---

## Documentation

- **[docs/FOLDER_STRUCTURE.md](../docs/FOLDER_STRUCTURE.md)** — Repository layout, database file, algorithms, API modules.
- **[docs/Algorithms_How_They_Work.md](../docs/Algorithms_How_They_Work.md)** — Detailed algorithm descriptions with formulas.
- **[docs/algorithm-workflow.md](../docs/algorithm-workflow.md)** — End-to-end data flow from report to route.
- **[../README.md](../README.md)** — Full-stack overview, API table, environment variables.
- **`../docs/`** — SRS, test cases, algorithm narratives, diagrams.
