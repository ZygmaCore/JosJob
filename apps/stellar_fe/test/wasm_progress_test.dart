import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_fe/services/wasm_prefetch.dart';

// Pure, non-widget unit test for the sqlite3.wasm prefetch progress model, so
// it never touches google_fonts (which throws in headless widget tests).
void main() {
  group('WasmProgress.fraction', () {
    test('is the received/total ratio when total is known', () {
      expect(const WasmProgress(received: 374, total: 748).fraction, 0.5);
    });

    test('is null (indeterminate) when total is unknown', () {
      expect(const WasmProgress(received: 100).fraction, isNull);
    });

    test('is null when total is zero (avoids divide-by-zero)', () {
      expect(const WasmProgress(received: 100, total: 0).fraction, isNull);
    });

    test('clamps to 1.0 when received exceeds total', () {
      expect(const WasmProgress(received: 900, total: 748).fraction, 1.0);
    });

    test('defaults: nothing received, not done, indeterminate', () {
      const p = WasmProgress();
      expect(p.received, 0);
      expect(p.done, isFalse);
      expect(p.fraction, isNull);
    });
  });
}
