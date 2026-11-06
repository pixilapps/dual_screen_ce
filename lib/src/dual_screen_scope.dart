import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'dual_screen.dart';
import 'dual_screen_data.dart';
import 'dual_screen_info.dart';

/// Copyright (c) 2026 Pixil Apps.
/// Licensed under the MIT License.

/// Provides [DualScreenData] to the app ([DualScreen.of] and friends), and publishes the iPhone Duo fold to
/// `MediaQuery.displayFeatures` so [TwoPane] and Flutter's dialogs and sheets see it as they see an Android fold.
///
/// Place it above `MaterialApp` / `CupertinoApp`. On iOS it listens to the platform while mounted; the fold is
/// published only while the device is partially open, never when closed or flat, and not at all once Flutter reports
/// display features on iOS itself (flutter/flutter#192515). On Android it derives the data from the display features
/// Android already reports, and starts no sensor.
class DualScreenScope extends StatefulWidget {
  const DualScreenScope({super.key, required this.child});

  final Widget child;

  @override
  State<DualScreenScope> createState() => _DualScreenScopeState();
}

class _DualScreenScopeState extends State<DualScreenScope> {
  StreamSubscription<DualScreenData>? _subscription;
  DualScreenData _platform = DualScreenData.fallback;

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_isIOS) _subscription = DualScreenInfo.displayStateEvents.listen((DualScreenData data) => setState(() => _platform = data));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    if (!_isIOS) return DualScreen(data: DualScreenData.fromDisplayFeatures(mediaQuery.displayFeatures), child: widget.child);
    final DisplayRegion? fold = _platform.posture == DevicePosture.halfOpened ? _platform.fold : null;
    final bool publish = fold != null && mediaQuery.displayFeatures.isEmpty;
    return DualScreen(
      data: _platform,
      // Always a MediaQuery here, so the subtree keeps its state when the fold comes and goes.
      child: MediaQuery(
        data: publish
            ? mediaQuery.copyWith(
                displayFeatures: <DisplayFeature>[
                  DisplayFeature(bounds: fold.rect, type: DisplayFeatureType.fold, state: DisplayFeatureState.postureHalfOpened),
                ],
              )
            : mediaQuery,
        child: widget.child,
      ),
    );
  }
}
