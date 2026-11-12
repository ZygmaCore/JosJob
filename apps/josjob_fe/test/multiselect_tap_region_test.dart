import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Reproduces the onboarding multi-select bug: a focus-gated suggestion panel
// under a TextField. On desktop/web the TextField's default onTapOutside
// unfocuses on pointer-DOWN; if the panel is only shown while focused, the
// pointer-down rebuild removes the tapped tile before pointer-up, so its onTap
// never fires (you can't SELECT). Wrapping the panel in TextFieldTapRegion
// keeps the tap "inside" the field's group, so focus + the tile survive.
//
// This mirrors the structure of _SuggestionResults inside _MultiSelectInput
// (see lib/onboarding/widgets/multi_select_input.dart).

const _tileLabel = 'Add "welding"';

class _Repro extends StatefulWidget {
  final bool wrap;
  final List<String> selected;
  const _Repro({required this.wrap, required this.selected});

  @override
  State<_Repro> createState() => _ReproState();
}

class _ReproState extends State<_Repro> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Same as _MultiSelectInput: rebuild on focus change so the panel is
    // shown/hidden with focus.
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = InkWell(
      canRequestFocus: false,
      onTap: () => setState(() => widget.selected.add('picked')),
      child: const SizedBox(height: 44, width: 220, child: Text(_tileLabel)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 220, child: TextField(focusNode: _focus)),
        if (_focus.hasFocus)
          widget.wrap ? TextFieldTapRegion(child: tile) : tile,
      ],
    );
  }
}

Future<List<String>> _tapSuggestion(
  WidgetTester tester, {
  required bool wrap,
}) async {
  // Desktop/web platform so the TextField's default onTapOutside unfocuses.
  // Reset inside the body (not tearDown) so it's unset before the harness's
  // end-of-test invariant check.
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Repro(wrap: wrap, selected: selected),
        ),
      ),
    );

    // Focus the field -> the suggestion tile appears.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text(_tileLabel), findsOneWidget);

    // Tap the tile with a mouse (desktop/web) pointer, pumping AFTER
    // pointer-down so any onTapOutside->unfocus->rebuild happens mid-gesture,
    // exactly like the real app.
    final g = await tester.startGesture(
      tester.getCenter(find.text(_tileLabel)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await g.up();
    await tester.pump();

    return selected;
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('BUG: without TextFieldTapRegion the suggestion tap is lost', (
    tester,
  ) async {
    final selected = await _tapSuggestion(tester, wrap: false);
    expect(selected, isEmpty);
  });

  testWidgets('FIX: with TextFieldTapRegion the suggestion tap selects', (
    tester,
  ) async {
    final selected = await _tapSuggestion(tester, wrap: true);
    expect(selected, ['picked']);
  });
}
