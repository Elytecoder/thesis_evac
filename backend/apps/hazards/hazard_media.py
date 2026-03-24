"""
Hazard report media: validate, save under MEDIA_ROOT/hazards/, return public URLs.

Used by multipart uploads and legacy JSON data URLs (e.g. offline sync).
"""
from __future__ import annotations

import base64
import io
import re
import shutil
import subprocess
import uuid
from pathlib import Path

from django.conf import settings
from django.core.files.uploadedfile import UploadedFile
from PIL import Image

INVALID_FILE_ERROR = 'Invalid file. Must be under size limit and correct format.'

IMAGE_MAX_BYTES = getattr(settings, 'HAZARD_IMAGE_MAX_BYTES', 2 * 1024 * 1024)
VIDEO_MAX_BYTES = getattr(settings, 'HAZARD_VIDEO_MAX_BYTES', 10 * 1024 * 1024)
VIDEO_MAX_DURATION_SEC = getattr(settings, 'HAZARD_VIDEO_MAX_DURATION_SEC', 10)

ALLOWED_IMAGE_EXTS = frozenset({'jpg', 'jpeg', 'png'})
ALLOWED_IMAGE_PILLOW = frozenset({'JPEG', 'PNG'})


def _hazards_dir() -> Path:
    root = Path(settings.MEDIA_ROOT) / 'hazards'
    root.mkdir(parents=True, exist_ok=True)
    return root


def _absolute_media_url(request, relative_under_media: str) -> str:
    """relative_under_media e.g. 'hazards/abc.jpg' (no leading slash)."""
    base = settings.MEDIA_URL
    if not base.endswith('/'):
        base = f'{base}/'
    rel = relative_under_media.lstrip('/')
    path = f'{base}{rel}'
    return request.build_absolute_uri(path)


def _validate_and_save_image_bytes(raw: bytes, request) -> tuple[bool, str]:
    if len(raw) > IMAGE_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    try:
        with Image.open(io.BytesIO(raw)) as im:
            fmt = im.format
            if fmt not in ALLOWED_IMAGE_PILLOW:
                return False, INVALID_FILE_ERROR
            im.verify()
        with Image.open(io.BytesIO(raw)) as im2:
            fmt = im2.format
            out = io.BytesIO()
            if fmt == 'JPEG':
                rgb = im2.convert('RGB')
                rgb.save(out, format='JPEG', quality=85, optimize=True)
                ext = 'jpg'
            else:
                im2.save(out, format='PNG', optimize=True)
                ext = 'png'
            final = out.getvalue()
    except Exception:
        return False, INVALID_FILE_ERROR
    if len(final) > IMAGE_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    name = f'{uuid.uuid4().hex}.{ext}'
    path = _hazards_dir() / name
    path.write_bytes(final)
    return True, _absolute_media_url(request, f'hazards/{name}')


def save_uploaded_image(upload: UploadedFile, request) -> tuple[bool, str]:
    if upload.size > IMAGE_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    name = (upload.name or '').lower()
    ext = Path(name).suffix.lstrip('.')
    if ext not in ALLOWED_IMAGE_EXTS:
        return False, INVALID_FILE_ERROR
    raw = upload.read()
    return _validate_and_save_image_bytes(raw, request)


def _mp4_duration_seconds(file_path: Path) -> float | None:
    ffprobe = shutil.which('ffprobe')
    if not ffprobe:
        return None
    try:
        r = subprocess.run(
            [
                ffprobe,
                '-v',
                'error',
                '-show_entries',
                'format=duration',
                '-of',
                'default=noprint_wrappers=1:nokey=1',
                str(file_path),
            ],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        if r.returncode != 0 or not (r.stdout or '').strip():
            return None
        return float((r.stdout or '').strip())
    except (ValueError, subprocess.TimeoutExpired, OSError):
        return None


def save_uploaded_video(upload: UploadedFile, request) -> tuple[bool, str]:
    if not getattr(settings, 'HAZARD_VIDEO_UPLOAD_ENABLED', False):
        return False, INVALID_FILE_ERROR
    if upload.size > VIDEO_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    name = (upload.name or '').lower()
    if not name.endswith('.mp4'):
        return False, INVALID_FILE_ERROR
    tmp_name = f'{uuid.uuid4().hex}.mp4'
    dest = _hazards_dir() / tmp_name
    with dest.open('wb') as out:
        for chunk in upload.chunks():
            out.write(chunk)
    if dest.stat().st_size > VIDEO_MAX_BYTES:
        dest.unlink(missing_ok=True)
        return False, INVALID_FILE_ERROR
    with dest.open('rb') as vf:
        head = vf.read(12)
    if len(head) < 8 or head[4:8] != b'ftyp':
        dest.unlink(missing_ok=True)
        return False, INVALID_FILE_ERROR
    dur = _mp4_duration_seconds(dest)
    if dur is not None and dur > VIDEO_MAX_DURATION_SEC + 0.25:
        dest.unlink(missing_ok=True)
        return False, INVALID_FILE_ERROR
    return True, _absolute_media_url(request, f'hazards/{tmp_name}')


_DATA_IMAGE_RE = re.compile(
    r'^data:image/(?:jpeg|jpg|png);base64,(.+)$',
    re.IGNORECASE | re.DOTALL,
)
_DATA_VIDEO_RE = re.compile(
    r'^data:video/mp4;base64,(.+)$',
    re.IGNORECASE | re.DOTALL,
)


def process_data_url_photo(photo_url: str, request) -> tuple[bool, str]:
    """If data URL, validate and save to disk; return absolute URL. Pass through http(s) unchanged."""
    s = (photo_url or '').strip()
    if not s or s.startswith(('http://', 'https://')):
        return True, s
    m = _DATA_IMAGE_RE.match(s)
    if not m:
        return False, INVALID_FILE_ERROR
    try:
        raw = base64.b64decode(re.sub(r'\s+', '', m.group(1)), validate=True)
    except Exception:
        return False, INVALID_FILE_ERROR
    return _validate_and_save_image_bytes(raw, request)


def process_data_url_video(video_url: str, request) -> tuple[bool, str]:
    if not getattr(settings, 'HAZARD_VIDEO_UPLOAD_ENABLED', False):
        return False, INVALID_FILE_ERROR
    s = (video_url or '').strip()
    if not s or s.startswith(('http://', 'https://')):
        return True, s
    m = _DATA_VIDEO_RE.match(s)
    if not m:
        return False, INVALID_FILE_ERROR
    try:
        raw = base64.b64decode(re.sub(r'\s+', '', m.group(1)), validate=True)
    except Exception:
        return False, INVALID_FILE_ERROR
    if len(raw) > VIDEO_MAX_BYTES:
        return False, INVALID_FILE_ERROR
    if len(raw) < 12 or raw[4:8] != b'ftyp':
        return False, INVALID_FILE_ERROR
    tmp_name = f'{uuid.uuid4().hex}.mp4'
    dest = _hazards_dir() / tmp_name
    dest.write_bytes(raw)
    dur = _mp4_duration_seconds(dest)
    if dur is not None and dur > VIDEO_MAX_DURATION_SEC + 0.25:
        dest.unlink(missing_ok=True)
        return False, INVALID_FILE_ERROR
    return True, _absolute_media_url(request, f'hazards/{tmp_name}')
