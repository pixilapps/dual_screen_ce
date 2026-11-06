import 'dart:async';

import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs on a real platform: `flutter test integration_test -d <device>`. On the iPhone Duo simulator it checks the
/// native layer end to end; anywhere else it checks that nothing is reported and nothing throws.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the platform reports the display state the native layer measures', (WidgetTester tester) async {
    final bool foldable = await DualScreenInfo.hasHingeAngleSensor;
    DualScreenData? data;
    await tester.pumpWidget(
      DualScreenScope(
        child: Builder(
          builder: (BuildContext context) {
            data = DualScreen.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    // The first snapshot arrives once the probe is attached and the hinge has reported.
    for (int i = 0; i < 50 && foldable && data?.posture == DevicePosture.unknown; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && foldable) {
      expect(data!.isFoldable, isTrue);
      expect(data!.posture, isNot(DevicePosture.unknown));
      expect(data!.horizontalSizeClass, isNot(SizeClass.unspecified));
      expect(data!.regions.where((DisplayRegion r) => r.kind == DisplayRegionKind.occlusion), isNotEmpty, reason: 'the camera cluster');
      final VerticalBar? bar = data!.verticalBar;
      if (bar != null) {
        // The bar region lies inside the safe-area column on its side.
        final MediaQueryData mq = MediaQuery.of(tester.element(find.byType(SizedBox)));
        final double column = bar.side == AxisDirection.right ? mq.padding.right : mq.padding.left;
        expect(column, greaterThanOrEqualTo(bar.rect.width));
      }
    } else {
      expect(data == null || !data!.isFoldable, isTrue);
    }
  });

  testWidgets('without a hinge the hinge angle stream ends', (WidgetTester tester) async {
    if (await DualScreenInfo.hasHingeAngleSensor) return; // a device with a hinge keeps it open
    final Completer<void> done = Completer<void>();
    final StreamSubscription<double> subscription = DualScreenInfo.hingeAngleEvents.listen((_) {}, onDone: done.complete);
    addTearDown(subscription.cancel);
    await tester.pumpWidget(const SizedBox());
    // Ends at once below iOS 27.1, or once the native side has settled "no hinge" (1.5 s after the view is on screen).
    await tester.runAsync(() => done.future.timeout(const Duration(seconds: 6)));
    expect(done.isCompleted, isTrue);
  });
}
