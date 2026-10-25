import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:foldable/foldable.dart';

/// Copyright (c) Microsoft Corporation.
/// Copyright (c) 2026 Pixil Apps.
/// Licensed under the MIT License.
class DualScreenInfo {
  static const EventChannel _hingeAngleEventChannel = EventChannel('dual_screen_ce/hinge_angle');
  static const MethodChannel _hingeInfoMethodChannel = MethodChannel('dual_screen_ce/hinge_info');
  static Stream<double>? _hingeAngleEvents;

  // ponytail: the Duo hinge reports in only after its first update. Raise this if a Duo cold start measures slower.
  static const Duration _iosSettleTimeout = Duration(milliseconds: 1500);

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// A broadcast stream of hinge angles in degrees: 0 is closed, 180 is flat.
  ///
  /// Android reads the hinge angle sensor. iOS reads the iPhone Duo hinge
  /// through the `foldable` plugin. Without a hinge the stream is empty.
  static Stream<double> get hingeAngleEvents {
    try {
      _hingeAngleEvents ??= _repeatLatest(
        _isIOS ? Foldable.hingeAngleStream : _hingeAngleEventChannel.receiveBroadcastStream().map((dynamic event) => event as double),
      );
      return _hingeAngleEvents!;
    } catch (e) {
      return const Stream<double>.empty();
    }
  }

  /// Returns true on Android foldables with a hinge angle sensor and on
  /// iPhone Duo. Returns false everywhere else, never throws.
  static Future<bool> get hasHingeAngleSensor async {
    try {
      if (_isIOS) return await _iosHasHinge();
      return await _hingeInfoMethodChannel.invokeMethod<bool>('hasHingeAngleSensor') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _iosHasHinge() async {
    final FoldableData snapshot = await Foldable.snapshot;
    if (snapshot.capabilities.supportLevel != FoldableSupportLevel.unknown) return snapshot.isFoldable;
    final FoldableData settled = await Foldable.changes
        .firstWhere((FoldableData d) => d.capabilities.supportLevel != FoldableSupportLevel.unknown, orElse: () => FoldableData.unsupported)
        .timeout(_iosSettleTimeout, onTimeout: () => FoldableData.unsupported);
    return settled.isFoldable;
  }

  static Stream<T> _repeatLatest<T>(Stream<T> original) {
    bool done = false;
    T? latest;
    final Set<MultiStreamController<T>> currentListeners = <MultiStreamController<T>>{};
    original.listen(
      (T event) {
        latest = event;
        for (MultiStreamController<T> listener in <MultiStreamController<T>>[...currentListeners]) {
          listener.addSync(event);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (MultiStreamController<T> listener in <MultiStreamController<T>>[...currentListeners]) {
          listener.addErrorSync(error, stack);
        }
      },
      onDone: () {
        done = true;
        latest = null;
        for (MultiStreamController<T> listener in currentListeners) {
          listener.closeSync();
        }
        currentListeners.clear();
      },
    );
    return Stream<T>.multi((MultiStreamController<T> controller) {
      if (done) {
        controller.close();
        return;
      }
      currentListeners.add(controller);
      final T? latestValue = latest;
      if (latestValue != null) controller.add(latestValue);
      controller.onCancel = () {
        if (!done) currentListeners.remove(controller);
      };
    });
  }
}
