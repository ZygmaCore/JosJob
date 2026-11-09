import 'package:flutter/widgets.dart';

import 'vod_playback_native.dart'
    if (dart.library.js_interop) 'vod_playback_web.dart'
    as impl;

// =========================================================================
// ATVETI STELLAR — VOD playback abstraction
//
// A minimal video surface the VOD player shell drives, so the same shell,
// checkpoint seek bar and transcript work on every platform:
//   • native (iOS/Android/macOS/Safari) — `video_player` (native HLS),
//   • web (Chrome/Firefox/Edge) — an HTML <video> + hls.js, since those
//     browsers can't decode HLS natively.
//
// [createVodPlayback] returns the right implementation via a conditional
// import (web build -> vod_playback_web.dart; everything else -> _native).
// =========================================================================
abstract class VodPlayback {
  /// Loads [url] and prepares the surface. On native this resolves once the
  /// video is initialized; on web it returns after wiring the element and
  /// [addListener] callbacks fire as metadata/state arrive.
  Future<void> initialize();

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);

  bool get isInitialized;
  bool get isPlaying;
  bool get isBuffering;
  bool get hasError;
  Duration get position;
  Duration get duration;

  /// Width / height of the video (falls back to 16:9 until known).
  double get aspectRatio;

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> dispose();

  /// The platform video surface to embed in the stage.
  Widget buildView();
}

/// Creates the platform-appropriate [VodPlayback] for the HLS [url].
VodPlayback createVodPlayback(String url) => impl.newPlayback(url);
