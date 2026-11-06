import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Copyright (c) 2026 Pixil Apps.
/// Licensed under the MIT License.

/// How the device is folded.
///
/// iPhone Duo reports this from its hinge (`UIHinge.status`). Android reports it from the window's fold
/// [DisplayFeature]; a closed Android foldable has no fold in the window, so it reads [unknown] there.
enum DevicePosture {
  /// Not reported: no hinge, no fold in this window, or no reading yet.
  unknown,

  /// Folded shut. On iPhone Duo the app runs on the outer display.
  closed,

  /// Partially open, like a book or a laptop.
  halfOpened,

  /// Fully open and flat.
  flat,
}

/// An iOS size class. [compact] width is the iPhone Duo outer display or a compact Split View window; [regular]
/// width is the inner display. Always [unspecified] off iOS.
enum SizeClass { unspecified, compact, regular }

/// The two kinds of reserved display region.
enum DisplayRegionKind {
  /// Splits the display into separate parts: the iPhone Duo fold, an Android fold or hinge.
  division,

  /// Covers part of the display: a camera, the Dynamic Island, an Android display cutout.
  occlusion,
}

/// Whether the system draws its vertical bar for this window (iPhone Duo, iOS 27.1+).
enum VerticalBarBehavior {
  /// The system decides; on iPhone Duo bars go vertical in most poses.
  automatic,

  /// No vertical bar: the status bar returns to the top and the side inset goes away. Meant for UIs that are better
  /// with horizontal bars (a calculator, a full-screen video player). Keep it stable rather than toggling it often.
  disabled,
}

/// A reserved region of the display, in logical pixels of the Flutter view.
@immutable
class DisplayRegion {
  const DisplayRegion({required this.kind, required this.rect, this.margins = EdgeInsets.zero, required this.isActive});

  final DisplayRegionKind kind;

  /// The area to keep interactive content out of. On iOS it already includes [margins].
  final Rect rect;

  /// The part of [rect] that is margin around the hardware itself (iOS). The iPhone Duo fold is a 40pt rect with
  /// 20pt margins on each side of the crease.
  final EdgeInsets margins;

  /// Whether the region affects layout right now. The fold is active only while the device is partially open; the
  /// inner camera only while it is in use. Inactive regions still have a frame, so a layout can leave room for them.
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      other is DisplayRegion && other.kind == kind && other.rect == rect && other.margins == margins && other.isActive == isActive;

  @override
  int get hashCode => Object.hash(kind, rect, margins, isActive);

  @override
  String toString() => 'DisplayRegion(${kind.name}, $rect, active: $isActive)';
}

/// Where the system places its vertical bar: the strip that holds the back button, toolbar items and tab bar on
/// iPhone Duo, beside the status bar and camera.
///
/// A custom bar belongs in [rect]. The safe area on [side] already reserves the column around it, so content that
/// respects `MediaQuery.padding` stays clear of it.
@immutable
class VerticalBar {
  const VerticalBar({required this.side, required this.isLeading, required this.rect});

  /// The physical side: [AxisDirection.left] or [AxisDirection.right]. It follows the hardware, not the text direction:
  /// right on the outer display, left in a left-hand Split View window or a rotated outer display.
  final AxisDirection side;

  /// Whether [side] is the leading edge of the window's layout direction.
  final bool isLeading;

  /// The region the system bar would draw in, in logical pixels of the Flutter view.
  final Rect rect;

  @override
  bool operator ==(Object other) => other is VerticalBar && other.side == side && other.isLeading == isLeading && other.rect == rect;

  @override
  int get hashCode => Object.hash(side, isLeading, rect);

  @override
  String toString() => 'VerticalBar(${side.name}, $rect)';
}

/// A snapshot of the device's fold and display layout for the current window.
@immutable
class DualScreenData {
  const DualScreenData({
    this.isFoldable = false,
    this.posture = DevicePosture.unknown,
    this.regions = const <DisplayRegion>[],
    this.horizontalSizeClass = SizeClass.unspecified,
    this.verticalSizeClass = SizeClass.unspecified,
    this.verticalBar,
  });

  /// Not foldable, nothing reported. Used off foldables and before the first reading.
  static const DualScreenData fallback = DualScreenData();

  /// Whether the device has a hinge: iPhone Duo, or an Android window that reports a fold or hinge.
  final bool isFoldable;
  final DevicePosture posture;

  /// Folds, hinges, cameras and cutouts overlapping the window, active or not.
  final List<DisplayRegion> regions;
  final SizeClass horizontalSizeClass;
  final SizeClass verticalSizeClass;

  /// Non-null while the system places a vertical bar for this window.
  final VerticalBar? verticalBar;

  /// The active fold, if the window is split by one right now.
  DisplayRegion? get fold {
    for (final DisplayRegion region in regions) {
      if (region.kind == DisplayRegionKind.division && region.isActive) return region;
    }
    return null;
  }

  /// [Axis.vertical] when the active fold runs top to bottom (a book), [Axis.horizontal] when it runs side to side
  /// (a laptop), `null` without an active fold.
  Axis? get foldAxis {
    final Rect? rect = fold?.rect;
    if (rect == null) return null;
    return rect.height >= rect.width ? Axis.vertical : Axis.horizontal;
  }

  /// Builds the snapshot Android exposes through `MediaQuery.displayFeatures`. Folds and hinges become divisions,
  /// cutouts become occlusions. Android reports no closed posture or size classes.
  factory DualScreenData.fromDisplayFeatures(List<DisplayFeature> features) {
    DevicePosture posture = DevicePosture.unknown;
    final List<DisplayRegion> regions = <DisplayRegion>[];
    for (final DisplayFeature feature in features) {
      final bool divides = feature.type == DisplayFeatureType.fold || feature.type == DisplayFeatureType.hinge;
      if (divides) {
        posture = switch (feature.state) {
          DisplayFeatureState.postureHalfOpened => DevicePosture.halfOpened,
          DisplayFeatureState.postureFlat => DevicePosture.flat,
          _ => posture,
        };
      }
      regions.add(
        DisplayRegion(
          kind: divides ? DisplayRegionKind.division : DisplayRegionKind.occlusion,
          rect: feature.bounds,
          // Active as Flutter's DisplayFeatureSubScreen sees it: a half-opened fold, or anything with a size (a hinge,
          // a cutout). A flat zero-width fold does not split the window, like the iPhone Duo's inactive fold.
          isActive: feature.state == DisplayFeatureState.postureHalfOpened || !feature.bounds.isEmpty,
        ),
      );
    }
    final bool foldable = regions.any((DisplayRegion r) => r.kind == DisplayRegionKind.division);
    return DualScreenData(isFoldable: foldable, posture: posture, regions: regions);
  }

  /// Decodes a `dual_screen_ce/display_state` event.
  factory DualScreenData.fromMap(Map<Object?, Object?> map) {
    final Object? bar = map['verticalBar'];
    return DualScreenData(
      isFoldable: map['hasHinge'] == true,
      posture: switch (map['posture']) {
        'closed' => DevicePosture.closed,
        'halfOpened' => DevicePosture.halfOpened,
        'flat' => DevicePosture.flat,
        _ => DevicePosture.unknown,
      },
      regions: <DisplayRegion>[
        for (final Object? region in (map['regions'] as List<Object?>?) ?? const <Object?>[])
          if (region is Map<Object?, Object?>)
            DisplayRegion(
              kind: region['kind'] == 'division' ? DisplayRegionKind.division : DisplayRegionKind.occlusion,
              rect: _rect(region['rect']),
              margins: _insets(region['margins']),
              isActive: region['isActive'] == true,
            ),
      ],
      horizontalSizeClass: _sizeClass(map['horizontalSizeClass']),
      verticalSizeClass: _sizeClass(map['verticalSizeClass']),
      verticalBar: bar is Map<Object?, Object?>
          ? VerticalBar(side: bar['side'] == 'left' ? AxisDirection.left : AxisDirection.right, isLeading: bar['edge'] == 'leading', rect: _rect(bar['rect']))
          : null,
    );
  }

  static SizeClass _sizeClass(Object? value) => switch (value) {
    'compact' => SizeClass.compact,
    'regular' => SizeClass.regular,
    _ => SizeClass.unspecified,
  };

  static Rect _rect(Object? value) {
    final List<double> v = _doubles(value, 4);
    return Rect.fromLTWH(v[0], v[1], v[2], v[3]);
  }

  static EdgeInsets _insets(Object? value) {
    final List<double> v = _doubles(value, 4);
    return EdgeInsets.fromLTRB(v[0], v[1], v[2], v[3]);
  }

  static List<double> _doubles(Object? value, int count) {
    final List<Object?> list = value is List<Object?> ? value : const <Object?>[];
    return <double>[for (int i = 0; i < count; i++) i < list.length && list[i] is num ? (list[i]! as num).toDouble() : 0];
  }

  DualScreenData copyWith({
    bool? isFoldable,
    DevicePosture? posture,
    List<DisplayRegion>? regions,
    SizeClass? horizontalSizeClass,
    SizeClass? verticalSizeClass,
    VerticalBar? verticalBar,
    bool clearVerticalBar = false,
  }) {
    return DualScreenData(
      isFoldable: isFoldable ?? this.isFoldable,
      posture: posture ?? this.posture,
      regions: regions ?? this.regions,
      horizontalSizeClass: horizontalSizeClass ?? this.horizontalSizeClass,
      verticalSizeClass: verticalSizeClass ?? this.verticalSizeClass,
      verticalBar: clearVerticalBar ? null : verticalBar ?? this.verticalBar,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DualScreenData &&
      other.isFoldable == isFoldable &&
      other.posture == posture &&
      listEquals(other.regions, regions) &&
      other.horizontalSizeClass == horizontalSizeClass &&
      other.verticalSizeClass == verticalSizeClass &&
      other.verticalBar == verticalBar;

  @override
  int get hashCode => Object.hash(isFoldable, posture, Object.hashAll(regions), horizontalSizeClass, verticalSizeClass, verticalBar);

  @override
  String toString() => 'DualScreenData(${posture.name}, foldable: $isFoldable, bar: $verticalBar, regions: ${regions.length})';
}
