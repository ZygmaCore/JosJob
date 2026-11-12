import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:josjob_fe/bootstrap/bootstrap_page.dart';

// In the VM test environment kIsWeb is false, so AppBootstrap takes the native
// path: it reveals its child immediately (no wasm to download) and fires
// onReady after the first frame. The web streamed-fetch path needs a browser,
// so it is verified manually / via a throwaway golden of the splash instead.
void main() {
  testWidgets('reveals child immediately and fires onReady on native', (
    tester,
  ) async {
    var readyCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrap(
          onReady: () => readyCalls++,
          child: const Text('APP READY'),
        ),
      ),
    );

    // Child is shown right away; no boot splash / progress bar on native.
    expect(find.text('APP READY'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // onReady fires exactly once, after the first frame.
    await tester.pump();
    expect(readyCalls, 1);
  });
}
