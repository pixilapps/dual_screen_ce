import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel info = MethodChannel('dual_screen_ce/hinge_info');
  const EventChannel angle = EventChannel('dual_screen_ce/hinge_angle');
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(info, null));

  test('hasHingeAngleSensor returns the platform answer', () async {
    messenger.setMockMethodCallHandler(info, (MethodCall call) async => call.method == 'hasHingeAngleSensor');
    expect(await DualScreenInfo.hasHingeAngleSensor, isTrue);
  });

  test('hasHingeAngleSensor is false when the plugin is missing', () async {
    expect(await DualScreenInfo.hasHingeAngleSensor, isFalse);
  });

  test('hingeAngleEvents replays the latest angle to late listeners', () async {
    messenger.setMockStreamHandler(
      angle,
      MockStreamHandler.inline(onListen: (Object? args, MockStreamHandlerEventSink sink) => sink.success(90.0)),
    );
    expect(await DualScreenInfo.hingeAngleEvents.first, 90.0);
    expect(await DualScreenInfo.hingeAngleEvents.first, 90.0);
  });
}
