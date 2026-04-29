"""
Django settings for HAZNAV backend.
Production DB: PostgreSQL via DATABASE_URL env var (Render managed Postgres).
Local dev: SQLite fallback when DATABASE_URL is not set.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'dev-secret-key-change-in-production')

DEBUG = os.environ.get('DJANGO_DEBUG', 'True').lower() in ('1', 'true', 'yes')

# Safety guard: refuse to run with weak defaults when DEBUG is off
if not DEBUG and SECRET_KEY == 'dev-secret-key-change-in-production':
    import warnings
    warnings.warn(
        "SECURITY WARNING: DJANGO_SECRET_KEY is not set. "
        "Set a strong random secret key via the environment variable.",
        RuntimeWarning,
        stacklevel=2,
    )

# Render sets RENDER_EXTERNAL_HOSTNAME; locally allow 127.0.0.1 and localhost
_allowed = os.environ.get('ALLOWED_HOSTS', '127.0.0.1,localhost').split(',')
if os.environ.get('RENDER_EXTERNAL_HOSTNAME'):
    _allowed.append(os.environ['RENDER_EXTERNAL_HOSTNAME'])
ALLOWED_HOSTS = [h.strip() for h in _allowed if h.strip()]

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',  # Added for CORS support
    'apps.users',
    'apps.evacuation',
    'apps.hazards',
    'apps.validation',
    'apps.risk_prediction',
    'apps.routing',
    'apps.mobile_sync',
    'apps.system_logs',
    'apps.notifications',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.middleware.gzip.GZipMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',  # Added for CORS - must be before CommonMiddleware
    'django.middleware.common.CommonMiddleware',
    'config.middleware.DisableCSRFForAPIMiddleware',  # Disable CSRF for /api/ endpoints
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

# Exempt API endpoints from CSRF checks (API uses Token authentication instead)
CSRF_TRUSTED_ORIGINS = [
    'http://localhost:8000',
    'http://127.0.0.1:8000',
    'https://127.0.0.1:8000',
]
# Add Render app URL when deployed (e.g. https://your-service.onrender.com)
if os.environ.get('RENDER_EXTERNAL_HOSTNAME'):
    _host = os.environ['RENDER_EXTERNAL_HOSTNAME']
    CSRF_TRUSTED_ORIGINS.append(f'https://{_host}')
    CSRF_TRUSTED_ORIGINS.append(f'http://{_host}')

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# ── Database ──────────────────────────────────────────────────────────────────
# Production (Render): set the DATABASE_URL environment variable to the
# Internal Database URL from your Render PostgreSQL instance.
# Local dev: DATABASE_URL is not set → SQLite is used automatically.
#
# HOW TO SET UP ON RENDER:
#   1. Create a new "PostgreSQL" resource in Render dashboard.
#   2. Copy its "Internal Database URL" (starts with postgres://...).
#   3. Add it as env var DATABASE_URL on the Web Service.
#   4. Re-deploy — data now survives all future re-deploys.
import dj_database_url as _dj_db_url

_DATABASE_URL = os.environ.get('DATABASE_URL', '')
if _DATABASE_URL:
    DATABASES = {
        'default': _dj_db_url.config(
            default=_DATABASE_URL,
            conn_max_age=600,
            conn_health_checks=True,
            ssl_require=False,   # Internal Render URL uses private network — no SSL needed
        )
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Manila'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Custom user model
AUTH_USER_MODEL = 'users.User'

# Authenticate by email (backend finds user by email, then checks password)
AUTHENTICATION_BACKENDS = ['apps.users.backends.EmailBackend']

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PARSER_CLASSES': [
        'rest_framework.parsers.JSONParser',
        'rest_framework.parsers.MultiPartParser',
        'rest_framework.parsers.FormParser',
    ],
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
}

# CORS settings
# In development: allow all origins for convenience.
# In production (DEBUG=False): restrict to known origins.
if DEBUG:
    CORS_ALLOW_ALL_ORIGINS = True
else:
    CORS_ALLOW_ALL_ORIGINS = False
    CORS_ALLOWED_ORIGINS = [
        o.strip()
        for o in os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',')
        if o.strip()
    ]
    # Allow local Flutter web dev servers in production testing
    # (e.g. http://localhost:59512, http://127.0.0.1:12345).
    CORS_ALLOWED_ORIGIN_REGEXES = [
        r"^https?://localhost(:\d+)?$",
        r"^https?://127\.0\.0\.1(:\d+)?$",
    ]

CORS_ALLOW_CREDENTIALS = True

CORS_ALLOW_METHODS = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
]

CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]

# Path to mock data (replace with real MDRRMO data later)
MOCK_DATA_DIR = BASE_DIR / 'mock_data'

# System logs retention: delete logs older than this many days.
# Set to 0 to keep logs forever (no auto-deletion).
SYSTEM_LOG_RETENTION_DAYS = int(os.environ.get('SYSTEM_LOG_RETENTION_DAYS', '90'))

# Hazard reports: multipart file uploads + legacy JSON (e.g. offline sync). Video cap when enabled.
# Large enough for ~10 MB video as base64 in JSON when HAZARD_VIDEO_UPLOAD is enabled (sync edge case).
DATA_UPLOAD_MAX_MEMORY_SIZE = int(os.environ.get('DATA_UPLOAD_MAX_MEMORY_BYTES', str(20 * 1024 * 1024)))
FILE_UPLOAD_MAX_MEMORY_SIZE = DATA_UPLOAD_MAX_MEMORY_SIZE

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# ── Email (Gmail SMTP) ────────────────────────────────────────────────────────
# Configure via environment variables so credentials are never committed.
#
# Required env vars:
#   EMAIL_HOST_USER     – your Gmail address  (e.g. yourname@gmail.com)
#   EMAIL_HOST_PASSWORD – Gmail App Password  (NOT your real password)
#                         Generate one at: Google Account → Security → App passwords
#                         (Requires 2-Step Verification to be enabled)
#
# Optional override env vars (defaults shown):
#   EMAIL_HOST          – defaults to smtp.gmail.com
#   EMAIL_PORT          – defaults to 587
#   EMAIL_USE_TLS       – defaults to True
#   DEFAULT_FROM_EMAIL  – defaults to EMAIL_HOST_USER
#
# If EMAIL_HOST_USER is not set the console backend is used as a safe fallback
# (prints emails to the terminal) so dev mode still works without credentials.
_email_host_user = os.environ.get('EMAIL_HOST_USER', '')
if _email_host_user:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
    EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
    EMAIL_PORT = int(os.environ.get('EMAIL_PORT', '587'))
    EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() in ('1', 'true', 'yes')
    EMAIL_HOST_USER = _email_host_user
    EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
    DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', _email_host_user)
else:
    # Fallback: print emails to the terminal (safe for local dev without credentials)
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
    DEFAULT_FROM_EMAIL = 'noreply@evacsystem.local'

# Timeout for SMTP connections in seconds (prevents background thread from hanging).
EMAIL_TIMEOUT = 10
# ─────────────────────────────────────────────────────────────────────────────

# Hazard media limits (enforced in apps.hazards.hazard_media and serializers).
# Hazard report media limits
# Updated image size to 5MB for higher quality photos
HAZARD_IMAGE_MAX_BYTES = 5 * 1024 * 1024
HAZARD_VIDEO_MAX_BYTES = 10 * 1024 * 1024
HAZARD_VIDEO_MAX_DURATION_SEC = 10
# MP4 hazard clips: on by default; set HAZARD_VIDEO_UPLOAD=0 or false to disable.
_hazard_video_flag = os.environ.get('HAZARD_VIDEO_UPLOAD', 'true').strip().lower()
HAZARD_VIDEO_UPLOAD_ENABLED = _hazard_video_flag not in ('0', 'false', 'no', 'off')
