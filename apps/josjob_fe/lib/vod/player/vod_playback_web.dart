import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'vod_playback.dart';

// =========================================================================
// Web VOD playback — an HTML <video> driven by hls.js (bundled in
// web/index.html), so Chrome/Firefox/Edge can play the Cloudflare HLS stream
// they otherwise can't decode. Safari (native HLS) falls back to a plain src.
//
// The <video> element is registered as a platform view and embedded via
// [HtmlElementView]; DOM media events are bridged to the shell's listener so
// the seek bar, checkpoints and transcript stay in sync with the playhead.
// Selected by the conditional import in vod_playback.dart for web builds.
// =========================================================================

/// Factory referenced by vod_playback.dart's conditional import.
VodPlayback newPlayback(String url) => _HlsWebPlayback(url);

// ---- hls.js interop ------------------------------------------------------

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external factory _Hls();
  external void loadSource(String url);
  external void attachMedia(web.HTMLVideoElement media);
  external void on(String event, JSFunction callback);
  external void destroy();
}

@JS('Hls.isSupported')
external bool _hlsIsSupported();

// The `data` payload of hls.js' ERROR event; only `fatal` errors are terminal.
extension type _HlsErrorData._(JSObject _) implements JSObject {
  external bool? get fatal;
}

// Monotonic id so each player instance gets a unique platform-view type.
int _seq = 0;

class _HlsWebPlayback implements VodPlayback {
  _HlsWebPlayback(this._url) {
    _viewType = 'vod-hls-view-${_seq++}';
    // ignore: undefined_prefixed_name — dart:ui_web on web builds only.
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _video,
    );
  }

  final String _url;
  late final String _viewType;

  final web.HTMLVideoElement _video =
      (web.document.createElement('video') as web.HTMLVideoElement)
        ..controls = false
        ..autoplay = false
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = 'transparent';

  _Hls? _hls;
  final List<VoidCallback> _listeners = [];
  bool _initialized = false;
  bool _buffering = false;
  bool _error = false;

  void _notify() {
    for (final l in List<VoidCallback>.of(_listeners)) {
      l();
    }
  }

  void _on(String type, void Function() handler) {
    _video.addEventListener(type, ((web.Event _) => handler()).toJS);
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> initialize() async {
    _on('loadedmetadata', () {
      _initialized = true;
      _notify();
    });
    _on('durationchange', _notify);
    _on('timeupdate', _notify);
    _on('play', _notify);
    _on('pause', _notify);
    _on('ended', _notify);
    _on('waiting', () {
      _buffering = true;
      _notify();
    });
    _on('playing', () {
      _buffering = false;
      _initialized = true;
      _notify();
    });
    _on('canplay', () {
      _buffering = false;
      _notify();
    });
    _on('error', () {
      _error = true;
      _notify();
    });

    // Prefer hls.js; fall back to native HLS (Safari) if the browser has it.
    bool hlsSupported;
    try {
      hlsSupported = _hlsIsSupported();
    } catch (_) {
      hlsSupported = false; // window.Hls missing (script failed to load)
    }

    if (hlsSupported) {
      final hls = _Hls();
      _hls = hls;
      hls.on(
        'hlsError',
        ((JSObject _, _HlsErrorData data) {
          if (data.fatal ?? false) {
            _error = true;
            _notify();
          }
        }).toJS,
      );
      hls.loadSource(_url);
      hls.attachMedia(_video);
    } else if (_video.canPlayType('application/vnd.apple.mpegurl').isNotEmpty) {
      _video.src = _url;
    } else {
      _error = true;
      _notify();
    }
  }

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isPlaying => !_video.paused && !_video.ended;

  @override
  bool get isBuffering => _buffering;

  @override
  bool get hasError => _error;

  @override
  Duration get position =>
      Duration(milliseconds: (_video.currentTime * 1000).round());

  @override
  Duration get duration {
    final d = _video.duration;
    if (d.isNaN || d.isInfinite || d <= 0) return Duration.zero;
    return Duration(milliseconds: (d * 1000).round());
  }

  @override
  double get aspectRatio {
    final w = _video.videoWidth, h = _video.videoHeight;
    if (w <= 0 || h <= 0) return 16 / 9;
    return w / h;
  }

  @override
  Future<void> play() async {
    try {
      await _video.play().toDart;
    } catch (_) {
      // A browser autoplay/interaction rejection isn't a playback error.
    }
  }

  @override
  Future<void> pause() async => _video.pause();

  @override
  Future<void> seekTo(Duration position) async {
    _video.currentTime = position.inMilliseconds / 1000.0;
  }

  @override
  Future<void> dispose() async {
    try {
      _hls?.destroy();
    } catch (_) {}
    try {
      _video.pause();
    } catch (_) {}
    _video.removeAttribute('src');
    _video.remove();
    _listeners.clear();
  }

  @override
  Widget buildView() => HtmlElementView(viewType: _viewType);
}
