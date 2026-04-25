"""
Hazard report media: validate, compress, and store as base64 data URLs in the DB.

Images are stored as `data:image/jpeg;base64,...` strings directly in
HazardReport.photo_url (a TextField with no size limit).  This eliminates any
dependency on the local filesystem, which is ephemeral on Render's free tier —
files written to MEDIA_ROOT are lost on every server sleep/restart.

Videos are now stored the same way: as `data:video/mp4;base64,...` strings.
This ensures videos survive Render restarts and no media is ever lost.
"""
from __future__ import annotations

import base64
import io
import re
import uuid
from pathlib import Path

from django.conf import settings
from django.core.files.uploadedfile import UploadedFile
from PIL import Image

INVALID_FILE_ERROR = 'Invalid file. Must be under size limit and correct format.'

IMAGE_MAX_BYTES = getattr(settings, 'HAZARD_IMAGE_MAX_BYTES', 5 * 1024 * 1024)
VIDEO_MAX_BYTES = getattr(settings, 'HAZARD_VIDEO_MAX_BYTES', 10 * 1024 * 1024)

ALLOWED_IMAGE_EXTS = frozenset({'jpg', 'jpeg', 'png'})
ALLOWED_IMAGE_PILLOW = frozenset({'JPEG', 'PNG'})

# Target dimensions / quality for DB storage.
# 800 px wide at JPEG q=65 ≈ 80–180 KB → ~110–245 KB as base64 — manageable.
_STORE_MAX_WIDTH = 800
_STORE_QUALITY = 65


# ── Core image helper ─────────────────────────────────────────────────────────

def _compress_image_to_base64(raw: bytes) -> tuple[bool, str]:
    """
    Validate raw image bytes (JPEG or PNG), resize to at most _STORE_MAX_WIDTH px
    wide, re-compress as JPEG at _STORE_QUALITY%, and return a base64 data URL.
    No filesystem writes; safe on ephemeral deployments.
    """
    if len(raw) > IMAGE_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    try:
        # Pass 1 — verify format and structural integrity
        with Image.open(io.BytesIO(raw)) as im:
            fmt = im.format
            if fmt not in ALLOWED_IMAGE_PILLOW:
                return False, INVALID_FILE_ERROR
            im.verify()

        # Pass 2 — resize (if needed) and compress
        with Image.open(io.BytesIO(raw)) as im2:
            if im2.width > _STORE_MAX_WIDTH:
                ratio = _STORE_MAX_WIDTH / im2.width
                new_h = max(1, int(im2.height * ratio))
                im2 = im2.resize((_STORE_MAX_WIDTH, new_h), Image.LANCZOS)
            out = io.BytesIO()
            im2.convert('RGB').save(out, format='JPEG', quality=_STORE_QUALITY, optimize=True)
            compressed = out.getvalue()
    except Exception:
        return False, INVALID_FILE_ERROR

    b64 = base64.b64encode(compressed).decode('ascii')
    return True, f'data:image/jpeg;base64,{b64}'


# ── Core video helper ─────────────────────────────────────────────────────────

def _encode_video_to_base64(raw: bytes) -> tuple[bool, str]:
    """
    Validate raw MP4 bytes and return a base64 data URL for DB storage.
    No filesystem writes; safe on ephemeral deployments.
    """
    if len(raw) > VIDEO_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    # Validate MP4 container: ftyp box must appear at byte offset 4–7.
    if len(raw) < 12 or raw[4:8] != b'ftyp':
        return False, INVALID_FILE_ERROR
    b64 = base64.b64encode(raw).decode('ascii')
    return True, f'data:video/mp4;base64,{b64}'


# ── Public API: multipart file uploads ───────────────────────────────────────

def save_uploaded_image(upload: UploadedFile, request) -> tuple[bool, str]:  # noqa: ARG001
    """Validate a multipart image upload and return a base64 data URL for DB storage."""
    if upload.size > IMAGE_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    name = (upload.name or '').lower()
    ext = Path(name).suffix.lstrip('.')
    if ext not in ALLOWED_IMAGE_EXTS:
        return False, INVALID_FILE_ERROR
    raw = upload.read()
    return _compress_image_to_base64(raw)


def save_uploaded_video(upload: UploadedFile, request) -> tuple[bool, str]:  # noqa: ARG001
    """
    Validate a multipart MP4 upload and return a base64 data URL for DB storage.
    Videos are stored in the database (not the filesystem) to survive Render restarts.
    """
    if not getattr(settings, 'HAZARD_VIDEO_UPLOAD_ENABLED', False):
        return False, INVALID_FILE_ERROR
    if upload.size > VIDEO_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    name = (upload.name or '').lower()
    if not name.endswith('.mp4'):
        return False, INVALID_FILE_ERROR
    raw = upload.read()
    return _encode_video_to_base64(raw)


# ── Data URL helpers (JSON body / offline sync) ───────────────────────────────

_DATA_IMAGE_RE = re.compile(
    r'^data:image/(?:jpeg|jpg|png);base64,(.+)$',
    re.IGNORECASE | re.DOTALL,
)
_DATA_VIDEO_RE = re.compile(
    r'^data:video/mp4;base64,(.+)$',
    re.IGNORECASE | re.DOTALL,
)


def process_data_url_photo(photo_url: str, request) -> tuple[bool, str]:  # noqa: ARG001
    """
    Accept a photo as either:
    - An http(s) URL (pass through unchanged — legacy records).
    - A data:image/... base64 URL (validate, re-compress, return new data URL).
    """
    s = (photo_url or '').strip()
    if not s:
        return True, s
    if s.startswith(('http://', 'https://')):
        # Already an absolute URL (legacy record or re-submission) — keep as-is.
        return True, s
    m = _DATA_IMAGE_RE.match(s)
    if not m:
        return False, INVALID_FILE_ERROR
    try:
        raw = base64.b64decode(re.sub(r'\s+', '', m.group(1)), validate=True)
    except Exception:
        return False, INVALID_FILE_ERROR
    return _compress_image_to_base64(raw)


def process_data_url_video(video_url: str, request) -> tuple[bool, str]:  # noqa: ARG001
    """
    Accept a video as either:
    - An http(s) URL (pass through for legacy records — may 404 if file was on ephemeral disk).
    - A data:video/mp4;base64 URL (validate and return as-is — stored in DB).
    """
    s = (video_url or '').strip()
    if not s:
        return True, s
    if s.startswith(('http://', 'https://')):
        # Legacy record stored on filesystem (may no longer exist). Pass through.
        return True, s
    m = _DATA_VIDEO_RE.match(s)
    if not m:
        return False, INVALID_FILE_ERROR
    try:
        raw = base64.b64decode(re.sub(r'\s+', '', m.group(1)), validate=True)
    except Exception:
        return False, INVALID_FILE_ERROR
    return _encode_video_to_base64(raw)
