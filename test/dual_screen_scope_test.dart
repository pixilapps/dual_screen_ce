import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const EventChannel _state = EventChannel('dual_screen_ce/display_state');

Map<String, Object?> _duo({required String posture, required bool foldActive}) => <String, Object?>{
  'hasHinge': true,
  'posture': posture,
  'horizontalSizeClass': 'regular',
  'verticalSizeClass': 'regular',
  'regions': <Object?>[
    <String, Object?>{'kind': 'division', 'rect': <double>[455.5, 0, 40, 669], 'margins': <double>[20, 0, 20, 0], 'isActive': foldActive},
  ],
  'verticalBar': <String, Object?>{'edge': 'trailing', 'side': 'right', 'rect': <double>[879, 124, 48, 511]},
};

/// Records every MediaQuery and DualScreen value it sees, and counts its own rebuilds.
class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  List<DisplayFeature> features = const <DisplayFeature>[];
  DualScreenData? data;

  @override
  Widget build(BuildContext context) {
    features = MediaQuery.displayFeaturesOf(context);
    data = DualScreen.maybeOf(context);
    return const SizedBox();
  }
}

class _BarCounter extends StatelessWidget {
  const _BarCounter(this.onBuild);

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    DualScreen.verticalBarOf(context);
    onBuild();
    return const SizedBox();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('Android: data comes from the display features, MediaQuery is left alone', (WidgetTester tester) async {
    const DisplayFeature fold = DisplayFeature(bounds: Rect.fromLTWH(420, 0, 0, 800), type: DisplayFeatureType.fold, state: DisplayFeatureState.postureHalfOpened);
    final GlobalKey<_ProbeState> probe = GlobalKey<_ProbeState>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(displayFeatures: <DisplayFeature>[fold]),
        child: DualScreenScope(child: _Probe(key: probe)),
      ),
    );
    expect(probe.currentState!.features, <DisplayFeature>[fold]);
    expect(probe.currentState!.data!.posture, DevicePosture.halfOpened);
    expect(probe.currentState!.data!.isFoldable, isTrue);
    expect(probe.currentState!.data!.fold!.rect, fold.bounds, reason: 'a half-opened Android fold is active even at zero width');
  });

  testWidgets('iOS: the fold is published only while half-opened, and the subtree keeps its state', (WidgetTester tester) async {
    final StreamController<Object?> events = StreamController<Object?>();
    messenger.setMockStreamHandler(
      _state,
      MockStreamHandler.inline(onListen: (Object? args, MockStreamHandlerEventSink sink) {
        events.stream.listen(sink.success);
      }),
    );
    addTearDown(() => messenger.setMockStreamHandler(_state, null));
    final GlobalKey<_ProbeState> probe = GlobalKey<_ProbeState>();
    await tester.pumpWidget(const MediaQuery(data: MediaQueryData(), child: SizedBox()));
    await tester.pumpWidget(MediaQuery(data: const MediaQueryData(), child: DualScreenScope(child: _Probe(key: probe))));
    final _ProbeState first = probe.currentState!;

    // Mocked platform events arrive over a few microtask turns, not within one frame.
    Future<void> deliver(Map<String, Object?> event) async {
      events.add(event);
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    await deliver(_duo(posture: 'halfOpened', foldActive: true));
    expect(probe.currentState!.features.single.bounds, const Rect.fromLTWH(455.5, 0, 40, 669));
    expect(probe.currentState!.features.single.state, DisplayFeatureState.postureHalfOpened);

    await deliver(_duo(posture: 'flat', foldActive: false));
    expect(probe.currentState!.features, isEmpty);
    expect(probe.currentState!.data!.verticalBar!.side, AxisDirection.right);
    expect(identical(probe.currentState, first), isTrue, reason: 'publishing the fold must not rebuild the subtree from scratch');
    await events.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: steps aside when Flutter already reports display features', (WidgetTester tester) async {
    messenger.setMockStreamHandler(
      _state,
      MockStreamHandler.inline(onListen: (Object? args, MockStreamHandlerEventSink sink) => sink.success(_duo(posture: 'halfOpened', foldActive: true))),
    );
    addTearDown(() => messenger.setMockStreamHandler(_state, null));
    const DisplayFeature engineFold = DisplayFeature(bounds: Rect.fromLTWH(455.5, 0, 40, 669), type: DisplayFeatureType.fold, state: DisplayFeatureState.postureHalfOpened);
    final GlobalKey<_ProbeState> probe = GlobalKey<_ProbeState>();
    await tester.pumpWidget(MediaQuery(data: const MediaQueryData(displayFeatures: <DisplayFeature>[engineFold]), child: DualScreenScope(child: _Probe(key: probe))));
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(probe.currentState!.data!.posture, DevicePosture.halfOpened, reason: 'the platform state did arrive');
    expect(probe.currentState!.features, <DisplayFeature>[engineFold], reason: 'never published twice');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a posture change does not rebuild widgets that only read the vertical bar', (WidgetTester tester) async {
    int builds = 0;
    // The same child instance in both pumps, so only a DualScreen notification can rebuild it.
    final Widget counter = _BarCounter(() => builds++);
    Widget app(DevicePosture posture) => DualScreen(
      data: DualScreenData(
        isFoldable: true,
        posture: posture,
        verticalBar: const VerticalBar(side: AxisDirection.right, isLeading: false, rect: Rect.fromLTWH(879, 124, 48, 511)),
      ),
      child: counter,
    );
    await tester.pumpWidget(app(DevicePosture.flat));
    await tester.pumpWidget(app(DevicePosture.halfOpened));
    expect(builds, 1);
  });

  test('debug: the Android derivation reports nothing for a plain phone', () {
    expect(DualScreenData.fromDisplayFeatures(const <DisplayFeature>[]), DualScreenData.fallback);
    expect(kIsWeb, isFalse);
  });
}
