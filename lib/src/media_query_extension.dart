import 'dart:ui';
import 'package:flutter/widgets.dart';

/// Copyright (c) Microsoft Corporation.
/// Licensed under the MIT License.
/// Extension method that helps with working with the hinge specifically.
extension MediaQueryHinge on MediaQueryData {
  DisplayFeature? get hinge {
    for (final DisplayFeature e in displayFeatures) {
      if (e.type == .hinge) return e;
    }
    return null;
  }
}
