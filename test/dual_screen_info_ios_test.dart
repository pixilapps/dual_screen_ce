import 'dart:async';
import 'dart:ui' show DisplayFeature;

import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart';

class _FakeFoldable extends FoldablePlatform {
  _FakeFoldable(this.snapshot);
  final FoldableData snapshot;
  final StreamController<FoldableData> controller = StreamController<FoldableData>.broadcast();

  @override
  Future<FoldableData> getSnapshot() async => snapshot;

  @override
  Stream<FoldableData> get events => controller.stream;
}

FoldableData _data(FoldableSupportLevel level, {double? angle}) => FoldableData(
  capabilities: FoldableCapabilities(
    supportLevel: level,
    isFoldable: level == FoldableSupportLevel.available,
    hingeApiPresent: level != FoldableSupportLevel.unsupported,
    regionApiPresent: true,
    angleUnitVerified: true,
    strategy: 'test',
  ),
  status: HingeStatus.partiallyOpen,
  angleDegrees: angle,
  regions: const <ReservedRegion>[],
  displayFeatures: const <DisplayFeature>[],
);

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('a settled Duo snapshot answers true immediately', () async {
    FoldablePlatform.instance = _FakeFoldable(_data(FoldableSupportLevel.available));
    expect(await DualScreenInfo.hasHingeAngleSensor, isTrue);
  });

  test('iOS without hinge APIs answers false', () async {
    FoldablePlatform.instance = _FakeFoldable(_data(FoldableSupportLevel.unsupported));
    expect(await DualScreenInfo.hasHingeAngleSensor, isFalse);
  });

  test('an unknown snapshot waits for the first settled update', () async {
    final _FakeFoldable fake = _FakeFoldable(_data(FoldableSupportLevel.unknown));
    FoldablePlatform.instance = fake;
    final Future<bool> result = DualScreenInfo.hasHingeAngleSensor;
    await Future<void>.delayed(Duration.zero);
    fake.controller.add(_data(FoldableSupportLevel.available));
    expect(await result, isTrue);
  });

  test('an unknown snapshot that never settles gives up as false', () async {
    FoldablePlatform.instance = _FakeFoldable(_data(FoldableSupportLevel.unknown));
    expect(await DualScreenInfo.hasHingeAngleSensor, isFalse);
  });

  test('hingeAngleEvents carries the Duo angle in degrees', () async {
    final _FakeFoldable fake = _FakeFoldable(_data(FoldableSupportLevel.available));
    FoldablePlatform.instance = fake;
    final Future<double> first = DualScreenInfo.hingeAngleEvents.first;
    fake.controller.add(_data(FoldableSupportLevel.available, angle: 92.5));
    expect(await first, 92.5);
  });
}
