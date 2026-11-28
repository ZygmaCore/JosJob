import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'vod_playback.dart';

// =========================================================================
// Native (iOS/Android/macOS/Safari) VOD playback — wraps `video_player`,
// which decodes HLS natively on these platforms. Selected by the conditional
// import in vod_playback.dart for every non-web build.
// =========================================================================

/// Factory referenced by vod_playback.dart's conditional import.
VodPlayback newPlayback(String url) => _VideoPlayerPlayback(url);

class _VideoPlayerPlayback implements VodPlayback {
  _VideoPlayerPlayback(String url)
    : _controller = VideoPlayerController.networkUrl(Uri.parse(url));

  final VideoPlayerController _controller;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  bool get isBuffering => _controller.value.isBuffering;

  @override
  bool get hasError => _controller.value.hasError;

  @override
  Duration get position => _controller.value.position;

  @override
  Duration get duration => _controller.value.duration;

  @override
  double get aspectRatio {
    final ar = _controller.value.aspectRatio;
    return ar <= 0 ? 16 / 9 : ar;
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Widget buildView() => VideoPlayer(_controller);
}
