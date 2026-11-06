import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'dual_screen_data.dart';

/// Copyright (c) 2026 Pixil Apps.
/// Licensed under the MIT License.

/// The parts of [DualScreenData] a widget can depend on, so it rebuilds only when that part changes.
enum DualScreenAspect { foldable, posture, regions, sizeClass, verticalBar }

/// Exposes [DualScreenData] to the subtree. `DualScreenScope` provides it from the platform; tests and device
/// previews can build one directly with any data.
class DualScreen extends InheritedModel<DualScreenAspect> {
  const DualScreen({super.key, required this.data, required super.child});

  final DualScreenData data;

  /// The nearest data, or `null` without a `DualScreenScope` above. Depends on [aspect] only, or on everything.
  static DualScreenData? maybeOf(BuildContext context, [DualScreenAspect? aspect]) => InheritedModel.inheritFrom<DualScreen>(context, aspect: aspect)?.data;

  /// The nearest data, or [DualScreenData.fallback]. Rebuilds on any change.
  static DualScreenData of(BuildContext context) => maybeOf(context) ?? DualScreenData.fallback;

  static bool isFoldableOf(BuildContext context) => maybeOf(context, .foldable)?.isFoldable ?? false;

  static DevicePosture postureOf(BuildContext context) => maybeOf(context, .posture)?.posture ?? .unknown;

  static List<DisplayRegion> regionsOf(BuildContext context) => maybeOf(context, .regions)?.regions ?? const <DisplayRegion>[];

  static SizeClass horizontalSizeClassOf(BuildContext context) => maybeOf(context, .sizeClass)?.horizontalSizeClass ?? .unspecified;

  static SizeClass verticalSizeClassOf(BuildContext context) => maybeOf(context, .sizeClass)?.verticalSizeClass ?? .unspecified;

  /// Where the system places its vertical bar, or `null` when it places none.
  static VerticalBar? verticalBarOf(BuildContext context) => maybeOf(context, .verticalBar)?.verticalBar;

  @override
  bool updateShouldNotify(DualScreen oldWidget) => data != oldWidget.data;

  @override
  bool updateShouldNotifyDependent(DualScreen oldWidget, Set<DualScreenAspect> dependencies) {
    final DualScreenData a = data;
    final DualScreenData b = oldWidget.data;
    return (dependencies.contains(DualScreenAspect.foldable) && a.isFoldable != b.isFoldable) ||
        (dependencies.contains(DualScreenAspect.posture) && a.posture != b.posture) ||
        (dependencies.contains(DualScreenAspect.regions) && !listEquals(a.regions, b.regions)) ||
        (dependencies.contains(DualScreenAspect.sizeClass) && (a.horizontalSizeClass != b.horizontalSizeClass || a.verticalSizeClass != b.verticalSizeClass)) ||
        (dependencies.contains(DualScreenAspect.verticalBar) && a.verticalBar != b.verticalBar);
  }
}
