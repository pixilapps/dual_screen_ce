import 'dart:async';
import 'package:flutter/services.dart';

/// Copyright (c) Microsoft Corporation.
/// Licensed under the MIT License.
class DualScreenInfo {
  static const EventChannel _hingeAngleEventChannel = EventChannel('dual_screen_ce/hinge_angle');
  static const MethodChannel _hingeInfoMethodChannel = MethodChannel('dual_screen_ce/hinge_info');
  static Stream<double>? _hingeAngleEvents;

  /// A broadcast stream of events from the device hinge angle sensor.
  ///
  /// If the device is not equipped with a hinge angle sensor, this stream is
  /// empty.
  static Stream<double> get hingeAngleEvents {
    try {
      _hingeAngleEvents ??= _repeatLatest(_hingeAngleEventChannel.receiveBroadcastStream().map((dynamic event) => event as double));
      return _hingeAngleEvents!;
    } catch (e) {
      return const Stream<double>.empty();
    }
  }

  /// Returns true if the device has a hinge angle sensor.
  ///
  /// Returns false if the platform is not supported or if the device does not
  /// have a hinge or hinge angle sensor.
  static Future<bool> get hasHingeAngleSensor async {
    try {
      return await _hingeInfoMethodChannel.invokeMethod<bool>('hasHingeAngleSensor') ?? false;
    } catch (e) {
      return false;
    }
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
