"""
Firebase Cloud Messaging (FCM) service — push notification transport layer.

FCM is used ONLY for push delivery. PostgreSQL remains the primary database.
Existing Django auth, routing, AI, and report logic are untouched.

Security model
--------------
* send_to_role() performs the role check server-side — callers cannot override it.
* Tokens are stored per-user in PostgreSQL; the role stored in PostgreSQL governs
  who receives which notification type.
* Residents can never trigger or receive MDRRMO-role pushes via this service.

Token lifecycle
---------------
* Token saved on login (via /api/auth/fcm-token/).
* Token refreshed automatically via FirebaseMessaging.onTokenRefresh.
* Token cleared to '' on logout.
* Permanently invalid tokens (app uninstalled, token rotated) are automatically
  removed from the database on the first failed send.

Credentials
-----------
Set FIREBASE_CREDENTIALS env var to the base64-encoded service account JSON.
When absent (local dev), all send calls are silent no-ops; the rest of the app
continues to work normally.
"""
from __future__ import annotations

import base64
import json
import logging
import os

logger = logging.getLogger(__name__)

_app = None
_init_attempted = False

# FCM error codes that mean the token is permanently invalid and should be
# removed from the database so we stop wasting send attempts.
_INVALID_TOKEN_CODES = frozenset({
    'registration-token-not-registered',   # app uninstalled / token expired
    'invalid-registration-token',          # malformed token
    'mismatched-credential',               # wrong Firebase project
})


def _get_app():
    """Lazy-initialise the Firebase Admin SDK exactly once per process."""
    global _app, _init_attempted
    if _init_attempted:
        return _app
    _init_attempted = True

    creds_b64 = os.environ.get('FIREBASE_CREDENTIALS', '').strip()
    if not creds_b64:
        logger.debug('FIREBASE_CREDENTIALS not set — FCM push notifications disabled.')
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        creds_dict = json.loads(base64.b64decode(creds_b64).decode('utf-8'))
        cred = credentials.Certificate(creds_dict)
        _app = firebase_admin.initialize_app(cred)
        logger.info('Firebase Admin SDK initialised successfully.')
    except Exception as exc:
        logger.warning('Failed to initialise Firebase Admin SDK: %s', exc)

    return _app


def _is_invalid_token_error(exc: Exception) -> bool:
    """Return True if the FCM exception indicates the token is permanently invalid."""
    code = getattr(exc, 'code', '') or ''
    return code in _INVALID_TOKEN_CODES


def _clear_stale_token(token: str) -> None:
    """Remove a permanently-invalid FCM token from PostgreSQL."""
    try:
        from apps.users.models import User
        cleared = User.objects.filter(fcm_token=token.strip()).update(fcm_token='')
        if cleared:
            logger.info('Cleared stale FCM token: %s…', token[:12])
    except Exception as exc:
        logger.warning('Could not clear stale token: %s', exc)


def send_push(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """
    Send a push notification to a single FCM device token.

    - Returns True on success, False if skipped or failed.
    - Automatically removes permanently-invalid tokens from PostgreSQL so
      future sends are not wasted on stale devices.
    - Never raises; all errors are logged as warnings.
    """
    if not token or not token.strip():
        return False
    app = _get_app()
    if app is None:
        return False

    try:
        from firebase_admin import messaging

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            # FCM data payload must be string→string only.
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    priority='high',
                    channel_id='haznav_alerts',
                    click_action='FLUTTER_NOTIFICATION_CLICK',
                ),
            ),
            token=token.strip(),
        )
        messaging.send(message)
        logger.debug('FCM push sent → token %s…', token[:12])
        return True

    except Exception as exc:
        logger.warning('FCM send failed (token=%s…): %s', token[:12], exc)
        # Clean up permanently-invalid tokens so they don't clog the database.
        if _is_invalid_token_error(exc):
            _clear_stale_token(token)
        return False


def send_to_role(role: str, title: str, body: str, data: dict | None = None) -> int:
    """
    Broadcast a push notification to every active device of every user with *role*.

    The role filter is enforced here against PostgreSQL — it cannot be spoofed
    by a client. Residents will never receive MDRRMO-role notifications.

    Returns the count of successful sends (0 when FCM is not configured).
    """
    try:
        from apps.users.models import User

        tokens = list(
            User.objects
            .filter(role=role, is_active=True, is_suspended=False)
            .exclude(fcm_token='')
            .values_list('fcm_token', flat=True)
        )
    except Exception as exc:
        logger.warning('Could not fetch FCM tokens for role=%s: %s', role, exc)
        return 0

    return sum(1 for t in tokens if send_push(t, title, body, data))
