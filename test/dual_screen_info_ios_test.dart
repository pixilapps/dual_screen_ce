import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The inner display, open flat in landscape, as the iPhone Duo simulator reports it (doc/iphone_duo_matrix.md).
const Map<String, Object?> innerFlatLandscape = <String, Object?>{
  'hasHinge': true,
  'posture': 'flat',
  'horizontalSizeClass': 'regular',
  'verticalSizeClass': 'regular',
  'regions': <Object?>[
    <String, Object?>{'kind': 'division', 'rect': <double>[455.5, 0, 40, 669], 'margins': <double>[20, 0, 20, 0], 'isActive': false},
    <String, Object?>{'kind': 'occlusion', 'rect': <double>[677.3, 21, 58, 37], 'margins': <double>[0, 0, 0, 0], 'isActive': false},
    <String, Object?>{'kind': 'occlusion', 'rect': <double>[867, 0, 84, 124], 'margins': <double>[0, 0, 0, 0], 'isActive': true},
  ],
  'verticalBar': <String, Object?>{'edge': 'trailing', 'side': 'right', 'rect': <double>[879, 124, 48, 511]},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel info = MethodChannel('dual_screen_ce/hinge_info');
  const MethodChannel bar = MethodChannel('dual_screen_ce/vertical_bar');
  const EventChannel state = EventChannel('dual_screen_ce/display_state');
  const EventChannel angle = EventChannel('dual_screen_ce/hinge_angle');
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(info, null);
    messenger.setMockMethodCallHandler(bar, null);
  });

  test('hasHingeAngleSensor takes the native answer, which waits for the first hinge update itself', () async {
    messenger.setMockMethodCallHandler(info, (MethodCall call) async => call.method == 'hasHingeAngleSensor');
    expect(await DualScreenInfo.hasHingeAngleSensor, isTrue);
  });

  test('displayStateEvents decodes the Duo snapshot', () async {
    messenger.setMockStreamHandler(state, MockStreamHandler.inline(onListen: (Object? args, MockStreamHandlerEventSink sink) => sink.success(innerFlatLandscape)));
    final DualScreenData data = await DualScreenInfo.displayStateEvents.first;
    expect(data.isFoldable, isTrue);
    expect(data.posture, DevicePosture.flat);
    expect(data.horizontalSizeClass, SizeClass.regular);
    expect(data.fold, isNull, reason: 'a flat Duo has an inactive fold');
    expect(data.regions.first.margins, const EdgeInsets.symmetric(horizontal: 20));
    expect(data.verticalBar, const VerticalBar(side: AxisDirection.right, isLeading: false, rect: Rect.fromLTWH(879, 124, 48, 511)));
  });

  test('setPreferredVerticalBarBehavior sends the behavior name', () async {
    final List<MethodCall> calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(bar, (MethodCall call) async {
      calls.add(call);
      return true;
    });
    expect(await DualScreenInfo.setPreferredVerticalBarBehavior(VerticalBarBehavior.disabled), isTrue);
    expect(calls.single.method, 'setPreferredVerticalBarBehavior');
    expect(calls.single.arguments, 'disabled');
  });

  test('the hinge stream closes the platform side with its last listener and keeps the latest angle', () async {
    int listens = 0;
    int cancels = 0;
    messenger.setMockStreamHandler(
      angle,
      MockStreamHandler.inline(
        onListen: (Object? args, MockStreamHandlerEventSink sink) {
          listens++;
          if (listens == 1) sink.success(92.5);
        },
        onCancel: (Object? args) => cancels++,
      ),
    );
    expect(await DualScreenInfo.hingeAngleEvents.first, 92.5);
    await pumpEventQueue();
    expect(cancels, 1, reason: 'no listener left, so the sensor is released');
    // A later listener gets the cached angle at once, although the platform sends nothing on resubscribe.
    expect(await DualScreenInfo.hingeAngleEvents.first, 92.5);
    expect(listens, 2);
  });

  test('off iOS there is no display state and no vertical bar to control', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await DualScreenInfo.displayStateEvents.isEmpty, isTrue);
    expect(await DualScreenInfo.setPreferredVerticalBarBehavior(VerticalBarBehavior.disabled), isFalse);
  });
}
