"""
Firebase Cloud Messaging (FCM) service — push notification transport layer.

Sends push notifications to Android devices.
FCM is purely a delivery mechanism; PostgreSQL remains the primary database.

Credentials are loaded from the FIREBASE_CREDENTIALS environment variable,
which must contain the Firebase service account JSON encoded as a base64 string.

If FIREBASE_CREDENTIALS is absent (local dev / not configured), all send calls
are silently no-ops so the rest of the application continues to work normally.

Setup on Render:
  1. Firebase console → Project Settings → Service Accounts → Generate new private key
  2. base64-encode the downloaded JSON:
       python -c "import base64,open; print(base64.b64encode(open('key.json','rb').read()).decode())"
  3. Set FIREBASE_CREDENTIALS = <the base64 string> in Render environment variables.
"""
from __future__ import annotations

import base64
import json
import logging
import os

logger = logging.getLogger(__name__)

_app = None
_init_attempted = False


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


def send_push(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """
    Send a push notification to a single FCM device token.

    Returns True on success, False if skipped or failed.
    Never raises; errors are logged as warnings only.
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
            # data must be string→string; callers may pass ints/None
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
        logger.debug('FCM push sent to token %s…', token[:12])
        return True

    except Exception as exc:
        logger.warning('FCM send failed (token=%s…): %s', token[:12], exc)
        return False


def send_to_role(role: str, title: str, body: str, data: dict | None = None) -> int:
    """
    Broadcast a push notification to ALL users of *role* who have an FCM token.

    Returns the number of successful sends (0 when FCM is not configured).
    """
    try:
        from apps.users.models import User

        tokens = list(
            User.objects.filter(role=role)
            .exclude(fcm_token='')
            .values_list('fcm_token', flat=True)
        )
    except Exception as exc:
        logger.warning('Could not fetch FCM tokens for role=%s: %s', role, exc)
        return 0

    return sum(1 for t in tokens if send_push(t, title, body, data))
