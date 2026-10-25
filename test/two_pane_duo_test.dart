import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// iPhone Duo inner display, from duo_kit's FoldTestPose.
const Size _inner = Size(951, 669);

Future<void> _pump(WidgetTester tester, Size size, List<DisplayFeature> features) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, displayFeatures: features),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: TwoPane(
          startPane: SizedBox.expand(key: Key('start')),
          endPane: SizedBox.expand(key: Key('end')),
          panePriority: TwoPanePriority.start,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('half-open landscape Duo: panes meet at the centre of the 40pt fold', (WidgetTester tester) async {
    await _pump(tester, _inner, const <DisplayFeature>[
      DisplayFeature(bounds: Rect.fromLTWH(455.5, 0, 40, 669), type: DisplayFeatureType.fold, state: DisplayFeatureState.postureHalfOpened),
    ]);
    // TwoPane's flex math uses a 1e12 fraction base, so compare approximately.
    expect(tester.getRect(find.byKey(const Key('start'))), rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, 475.5, 669)));
    expect(tester.getRect(find.byKey(const Key('end'))), rectMoreOrLessEquals(const Rect.fromLTWH(475.5, 0, 475.5, 669)));
  });

  testWidgets('half-open portrait Duo: panes stack and meet at the centre of the fold', (WidgetTester tester) async {
    await _pump(tester, const Size(669, 951), const <DisplayFeature>[
      DisplayFeature(bounds: Rect.fromLTWH(0, 455.5, 669, 40), type: DisplayFeatureType.fold, state: DisplayFeatureState.postureHalfOpened),
    ]);
    expect(tester.getRect(find.byKey(const Key('start'))), rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, 669, 475.5)));
    expect(tester.getRect(find.byKey(const Key('end'))), rectMoreOrLessEquals(const Rect.fromLTWH(0, 475.5, 669, 475.5)));
  });

  testWidgets('a hinge keeps its gap: panes sit either side of it (Surface Duo)', (WidgetTester tester) async {
    await _pump(tester, _inner, const <DisplayFeature>[
      DisplayFeature(bounds: Rect.fromLTWH(455.5, 0, 40, 669), type: DisplayFeatureType.hinge, state: DisplayFeatureState.postureFlat),
    ]);
    expect(tester.getRect(find.byKey(const Key('start'))), rectMoreOrLessEquals(const Rect.fromLTWH(0, 0, 455.5, 669)));
    expect(tester.getRect(find.byKey(const Key('end'))), rectMoreOrLessEquals(const Rect.fromLTWH(495.5, 0, 455.5, 669)));
  });

  testWidgets('flat Duo (nothing published): panePriority is respected', (WidgetTester tester) async {
    await _pump(tester, _inner, const <DisplayFeature>[]);
    expect(find.byKey(const Key('start')), findsOneWidget);
    expect(find.byKey(const Key('end')), findsNothing);
  });
}
