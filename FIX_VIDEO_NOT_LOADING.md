# FIX: Video Not Loading in Pending Reports

**Status:** ⚠️ PARTIALLY FIXED (lifecycle bug fixed, video playback not implemented)

**Issue:** Residents cannot view videos attached to their pending reports. The video thumbnail shows but nothing happens on tap.

---

## ROOT CAUSES

### Bug 1: No Tap Handler for Videos

**Location:** `mobile/lib/ui/screens/map_screen.dart:1305-1307` (OLD)

```dart
onTap: isImage && url.isNotEmpty
    ? () => _openFullscreenImage(url)
    : null,  // ❌ Videos have no tap handler
```

**Problem:** Only images have tap handlers. Videos show as static icons with no interaction.

### Bug 2: setState() After Dispose

**Location:** `mobile/lib/ui/screens/map_screen.dart:1365-1381` (OLD)

```dart
Future<void> fetchMedia() async {
  setState(() => state['isLoading'] = true);
  try {
    // ... fetch media ...
    if (resp.statusCode == 200 && mounted) {  // ❌ Check mounted BEFORE setState
      onMediaFetched(photo, video);
      setState(() => state['isLoading'] = false);  // ❌ Called without mounted check
    }
  } catch (e) {
    if (mounted) setState(() => state['isLoading'] = false);
  }
}
```

**Error:**
```
Error fetching media: setState() called after dispose(): _StatefulBuilderState#1c97a
(lifecycle state: defunct, not mounted)
```

**Cause:** User closes dialog while media is still loading → StatefulBuilder disposed → setState() crashes

### Bug 3: Backend Sends Large Base64 Videos

**Location:** `backend/apps/mobile_sync/views.py:773-788`

```python
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def report_media(request, report_id):
    """
    Returns the full photo_url and video_url (including base64 blobs).
    """
    report = HazardReport.objects.get(pk=report_id, user=request.user)
    return Response({
        'id': report.id,
        'photo_url': report.photo_url or '',
        'video_url': report.video_url or '',  # ❌ 2.3MB base64 in JSON
    })
```

**Log Evidence:**
```
content-length: 2384869  (2.3MB)
video_url: "data:video/mp4;base64,AAAAGGZ0eXBtcDQyAAA..."
```

**Problem:** Base64-encoded video in JSON is inefficient for memory and parsing, but technically works if player supports it.

---

## THE FIXES

### Fix 1: Add Video Tap Handler (Temporary)

**File:** `mobile/lib/ui/screens/map_screen.dart:1305-1320`

**Before:**
```dart
onTap: isImage && url.isNotEmpty
    ? () => _openFullscreenImage(url)
    : null,  // No handler for videos
```

**After:**
```dart
onTap: url.isNotEmpty
    ? () {
        if (isImage) {
          _openFullscreenImage(url);
        } else {
          // Video - show error message for now
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video playback not yet supported in this view'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    : null,
```

**Why temporary:** Proper fix requires implementing `video_player` package, but this prevents user confusion (tap does something now).

### Fix 2: Fix setState() Lifecycle Bug

**File:** `mobile/lib/ui/screens/map_screen.dart:1365-1381`

**Before:**
```dart
Future<void> fetchMedia() async {
  setState(() => state['isLoading'] = true);  // ❌ No mounted check
  try {
    final resp = await apiClient.get(endpoint);
    if (resp.statusCode == 200 && mounted) {
      onMediaFetched(photo, video);
      setState(() => state['isLoading'] = false);  // ❌ Called without mounted check
    }
  } catch (e) {
    if (mounted) setState(() => state['isLoading'] = false);
  }
}
```

**After:**
```dart
Future<void> fetchMedia() async {
  if (!mounted) return;  // ✅ Guard at start
  setState(() => state['isLoading'] = true);
  try {
    final resp = await apiClient.get(endpoint);
    if (resp.statusCode == 200) {
      final photo = (resp.data['photo_url'] as String? ?? '').trim();
      final video = (resp.data['video_url'] as String? ?? '').trim();
      onMediaFetched(photo, video);
      if (mounted) setState(() => state['isLoading'] = false);  // ✅ Check before setState
    }
  } catch (e) {
    debugPrint('Error fetching media: $e');
    if (mounted) setState(() => state['isLoading'] = false);  // ✅ Already checked
  }
}
```

**Changes:**
1. Guard at function start: `if (!mounted) return;`
2. Check `mounted` before EVERY `setState()` call
3. Removed redundant `mounted` check from response condition (moved to setState call)

---

## PROPER VIDEO PLAYBACK (NOT YET IMPLEMENTED)

To fully fix video playback, implement these changes:

### Step 1: Add video_player Package

**File:** `mobile/pubspec.yaml`

```yaml
dependencies:
  video_player: ^2.8.0  # Add this
```

### Step 2: Create Video Player Dialog

**File:** `mobile/lib/ui/screens/map_screen.dart` (NEW FUNCTION)

```dart
void _openVideoPlayer(String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoPlayerScreen(videoUrl: url),
    ),
  );
}
```

### Step 3: Create VideoPlayerScreen Widget

**File:** `mobile/lib/ui/widgets/video_player_screen.dart` (NEW FILE)

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';
import 'dart:convert';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Handle base64-encoded video
      if (widget.videoUrl.startsWith('data:video/')) {
        final base64Data = widget.videoUrl.split(',')[1];
        final bytes = base64Decode(base64Data);
        
        // Create temp file from base64
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_video.mp4');
        await tempFile.writeAsBytes(bytes);
        
        _controller = VideoPlayerController.file(tempFile);
      } else {
        // Handle URL-based video
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      }

      await _controller.initialize();
      setState(() {
        _isLoading = false;
        _controller.play();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load video: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.white))
                : AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
      ),
      floatingActionButton: !_isLoading && _error == null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
```

### Step 4: Update Tap Handler

**File:** `mobile/lib/ui/screens/map_screen.dart:1305-1320`

```dart
onTap: url.isNotEmpty
    ? () {
        if (isImage) {
          _openFullscreenImage(url);
        } else {
          _openVideoPlayer(url);  // ✅ Now implemented
        }
      }
    : null,
```

---

## BACKEND OPTIMIZATION (RECOMMENDED BUT NOT CRITICAL)

### Option 1: Stream Video Instead of Base64

**File:** `backend/apps/mobile_sync/views.py` (REPLACE report_media)

```python
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def report_media(request, report_id):
    """
    Stream video file instead of returning base64 in JSON.
    """
    try:
        report = HazardReport.objects.get(pk=report_id, user=request.user)
    except HazardReport.DoesNotExist:
        return Response({'error': 'Report not found'}, status=404)
    
    # For photos: return base64 (small enough)
    # For videos: return streaming URL
    
    video_url = report.video_url or ''
    if video_url.startswith('data:video/'):
        # Convert to streaming endpoint
        video_url = f'/api/my-reports/{report_id}/video-stream/'
    
    return Response({
        'id': report.id,
        'photo_url': report.photo_url or '',
        'video_url': video_url,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def video_stream(request, report_id):
    """
    Stream video file with proper HTTP range support.
    """
    import re
    from django.http import StreamingHttpResponse
    
    report = HazardReport.objects.get(pk=report_id, user=request.user)
    video_base64 = report.video_url.split(',')[1]
    video_bytes = base64.b64decode(video_base64)
    
    # Support range requests for seeking
    range_header = request.META.get('HTTP_RANGE', '').strip()
    range_match = re.match(r'bytes=(\d+)-(\d*)', range_header)
    
    if range_match:
        start = int(range_match.group(1))
        end = int(range_match.group(2)) if range_match.group(2) else len(video_bytes) - 1
        length = end - start + 1
        
        response = StreamingHttpResponse(
            iter([video_bytes[start:end+1]]),
            content_type='video/mp4',
            status=206,
        )
        response['Content-Length'] = str(length)
        response['Content-Range'] = f'bytes {start}-{end}/{len(video_bytes)}'
        response['Accept-Ranges'] = 'bytes'
        return response
    else:
        response = StreamingHttpResponse(
            iter([video_bytes]),
            content_type='video/mp4',
        )
        response['Content-Length'] = str(len(video_bytes))
        response['Accept-Ranges'] = 'bytes'
        return response
```

### Option 2: Store Videos in Cloud Storage

Use AWS S3, Google Cloud Storage, or Cloudinary:

```python
# In HazardReport model
def get_video_url(self):
    """Return presigned URL for video if stored in S3."""
    if self.video_s3_key:
        return generate_presigned_url(self.video_s3_key, expires_in=3600)
    return self.video_url  # Fallback to base64
```

**Benefits:**
- No 2.3MB JSON payloads
- Browser-native video controls
- Seek support
- Lower memory usage

---

## TESTING CHECKLIST

### ✅ Test 1: setState() Lifecycle Bug
1. Submit report with video
2. Open pending report dialog
3. Click "Load Attached Media"
4. **Immediately close dialog** while loading
5. Expected: No crash, no error in logs ✅

### ⚠️ Test 2: Video Tap Handler
1. Submit report with video
2. Open pending report dialog
3. Load media
4. Tap video thumbnail
5. Expected: Snackbar shows "Video playback not yet supported" ⚠️
6. **Proper fix needed:** Video should play ❌

### ✅ Test 3: Photo Still Works
1. Submit report with photo
2. Open pending report dialog
3. Load media
4. Tap photo thumbnail
5. Expected: Fullscreen photo viewer opens ✅

### ⚠️ Test 4: Large Video Memory
1. Submit report with 10-second video (2-3MB)
2. Open pending report dialog
3. Load media
4. Expected: Loads successfully but uses excessive memory ⚠️
5. **Proper fix needed:** Stream video instead of base64 ❌

---

## FILES CHANGED

**1 file modified:**
- `mobile/lib/ui/screens/map_screen.dart` (lines 1305-1320, 1365-1381)

**Changes:**
1. Added video tap handler with temporary snackbar message
2. Fixed setState() lifecycle bug with proper `mounted` checks
3. Added guard at function start

**Total Changes:** 1 file, ~20 lines modified

---

## STATUS

**⚠️ PARTIALLY FIXED**

| Issue | Status |
|-------|--------|
| setState() crash | ✅ FIXED |
| Video tap does nothing | ⚠️ WORKAROUND (shows message) |
| Video playback | ❌ NOT IMPLEMENTED |
| Large base64 payload | ⚠️ WORKS BUT INEFFICIENT |

---

## RECOMMENDED NEXT STEPS

**Priority 1 (Critical for Demo):**
1. ✅ Fix setState() crash → DONE
2. ⚠️ Implement video_player → PENDING

**Priority 2 (Performance Optimization):**
1. Backend video streaming endpoint
2. Cloud storage for videos
3. Thumbnail generation

**Priority 3 (Nice to Have):**
1. Video compression before upload
2. Progress indicator for video download
3. Offline video caching

---

## DEMO WORKAROUND

For demo purposes, if video playback is not critical:

**Option 1:** Disable video upload feature
```dart
// In report_hazard_screen.dart
final canSelectVideo = false;  // Temporarily disable
```

**Option 2:** Show "Coming Soon" message
```dart
Text('Video attachments coming soon', 
     style: TextStyle(color: Colors.grey))
```

**Option 3:** Accept current state
- setState() crash is fixed ✅
- User gets feedback when tapping video (snackbar) ✅
- No unexpected silence or crashes ✅

---

## VERIFICATION

### Before Fix
```
Tap video → Nothing happens ❌
Close dialog while loading → setState() crash ❌
```

### After Fix
```
Tap video → "Not yet supported" message ✅
Close dialog while loading → No crash ✅
Tap photo → Still works ✅
```

**Next:** Implement proper video playback with `video_player` package.
