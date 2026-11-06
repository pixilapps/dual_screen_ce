import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dual_screen_data.dart';

/// Copyright (c) Microsoft Corporation.
/// Copyright (c) 2026 Pixil Apps.
/// Licensed under the MIT License.
class DualScreenInfo {
  static const EventChannel _hingeAngleEventChannel = EventChannel('dual_screen_ce/hinge_angle');
  static const MethodChannel _hingeInfoMethodChannel = MethodChannel('dual_screen_ce/hinge_info');
  static const EventChannel _displayStateEventChannel = EventChannel('dual_screen_ce/display_state');
  static const MethodChannel _verticalBarMethodChannel = MethodChannel('dual_screen_ce/vertical_bar');
  static Stream<double>? _hingeAngleEvents;
  static Stream<DualScreenData>? _displayStateEvents;

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  /// A broadcast stream of hinge angles in degrees: 0 is closed, 180 is flat.
  ///
  /// Android reads the hinge angle sensor, iOS the iPhone Duo hinge. Without a hinge the stream is empty. The sensor
  /// runs only while the stream has listeners; a listener that subscribes later gets the latest angle right away.
  static Stream<double> get hingeAngleEvents {
    if (!_isMobile) return const Stream<double>.empty();
    return _hingeAngleEvents ??= _shareLatest(() => _hingeAngleEventChannel.receiveBroadcastStream().map((dynamic event) => (event as num).toDouble()));
  }

  /// iPhone Duo display state: posture, fold and camera regions, size classes and the vertical bar. Emits on change
  /// only, starting with the current state. Empty off iOS; on Android, read `DualScreen.of(context)` instead.
  static Stream<DualScreenData> get displayStateEvents {
    if (!_isIOS) return const Stream<DualScreenData>.empty();
    return _displayStateEvents ??= _shareLatest(
      () => _displayStateEventChannel.receiveBroadcastStream().map((dynamic event) => DualScreenData.fromMap(event as Map<Object?, Object?>)),
    );
  }

  /// Returns true on Android foldables with a hinge angle sensor and on iPhone Duo. Returns false everywhere else,
  /// never throws.
  static Future<bool> get hasHingeAngleSensor async {
    if (!_isMobile) return false;
    try {
      return await _hingeInfoMethodChannel.invokeMethod<bool>('hasHingeAngleSensor') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Turns the system vertical bar off or back on for the app's window (iPhone Duo, iOS 27.1+). Disabled, the status
  /// bar moves back to the top and the side inset goes away. Returns whether the behavior reached the app's view
  /// controller (false before iOS 27.1, off iOS, and before the view controller exists, in which case the behavior is
  /// kept and applied as soon as it does); true does not mean the device has a vertical bar.
  static Future<bool> setPreferredVerticalBarBehavior(VerticalBarBehavior behavior) async {
    if (!_isIOS) return false;
    try {
      return await _verticalBarMethodChannel.invokeMethod<bool>('setPreferredVerticalBarBehavior', behavior.name) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// One platform subscription shared by all listeners: opened by the first, closed by the last. The latest event is
  /// kept across that gap, so a listener that arrives later gets it at once (hinge sensors don't re-send on resubscribe).
  static Stream<T> _shareLatest<T>(Stream<T> Function() open) {
    T? latest;
    StreamSubscription<T>? source;
    final Set<MultiStreamController<T>> listeners = <MultiStreamController<T>>{};
    // The platform ended the stream (no hinge): its subscription is done, so it is dropped, not cancelled.
    void closeAll() {
      source = null;
      for (final MultiStreamController<T> listener in <MultiStreamController<T>>[...listeners]) {
        listener.closeSync();
      }
      listeners.clear();
    }

    return Stream<T>.multi((MultiStreamController<T> controller) {
      listeners.add(controller);
      final T? value = latest;
      if (value != null) controller.add(value);
      source ??= open().listen(
        (T event) {
          latest = event;
          for (final MultiStreamController<T> listener in <MultiStreamController<T>>[...listeners]) {
            listener.addSync(event);
          }
        },
        onError: (Object error, StackTrace stack) {
          for (final MultiStreamController<T> listener in <MultiStreamController<T>>[...listeners]) {
            listener.addErrorSync(error, stack);
          }
        },
        onDone: closeAll,
      );
      controller.onCancel = () {
        listeners.remove(controller);
        if (listeners.isNotEmpty) return;
        source?.cancel();
        source = null;
      };
    });
  }
}
