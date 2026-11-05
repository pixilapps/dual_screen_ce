## 1.1.0

* **iPhone Duo, own iOS layer:** the plugin now ships its own Swift implementation (Swift Package Manager and CocoaPods) and no
  longer depends on [`foldable`](https://pub.dev/packages/foldable). It attaches to its own engine's Flutter view, re-attaches on
  UIScene reconnects, observes only while something listens, and does nothing on devices without a hinge.
* **New `DualScreen` / `DualScreenData`:** posture (`closed`, `halfOpened`, `flat`), reserved regions (the fold and the cameras,
  with margins and an active flag), iOS size classes, and the system **vertical bar** (`VerticalBar.side` and `rect`), as an
  `InheritedModel` with per-aspect accessors. `DualScreenScope` provides it on iOS and derives it from display features on Android.
* **New `DualScreenInfo.displayStateEvents`** and **`DualScreenInfo.setPreferredVerticalBarBehavior`** (turns the iPhone Duo
  vertical bar off for calculator-like or full-screen UIs).
* **TwoPane (behaviour change on iPhone Duo):** at a fold that has width, each pane's `MediaQuery.padding` gains half the fold on
  its fold side, so `SafeArea` content stays off the crease. Backgrounds still meet at the centre line. Android folds are
  zero-width and unaffected.
* **Hinge stream:** the platform subscription is now released when the last listener cancels (the sensor no longer runs
  forever); the latest angle is still replayed to later listeners.
* **iOS `hasHingeAngleSensor`:** answered natively from the first hinge update.

## 1.0.0

First release of **dual_screen_ce**, the community edition of Microsoft's archived
[`dual_screen`](https://pub.dev/packages/dual_screen) 1.0.4.

* **iPhone Duo:** `DualScreenInfo.hingeAngleEvents` and `hasHingeAngleSensor` work on iOS 27.1+
  through [`foldable`](https://pub.dev/packages/foldable).
* **New `DualScreenScope`:** publishes the iPhone Duo fold to `MediaQuery.displayFeatures` so `TwoPane` splits around it.
* **TwoPane:** panes meet at the centre line of a fold instead of leaving its width empty (the iPhone Duo
  reports a 40pt fold; Android folds were already zero-width). A hinge still keeps its gap.
* **TwoPane:** new `singleWidget` and toggle mode (`switchToSinglePane`, `animationDuration`, `animationCurve`).
  `startPane` / `endPane` are now nullable. With all three widgets but no notifier, the dual layout shows instead of crashing.
* **Android:** ignores the hinge sensor on phones that expose one without declaring
  `FEATURE_SENSOR_HINGE_ANGLE` (Samsung One UI non-foldables). Name-based sensor fallback works again below API 30.
* **Android build:** AGP 9 built-in Kotlin, Kotlin 2.4, compileSdk 36, minSdk 24, `build.gradle.kts`.

### Migrating from `dual_screen`

* Dependency `dual_screen` → `dual_screen_ce`; import `package:dual_screen_ce/dual_screen_ce.dart`. Class names are unchanged.
* Android namespace is now `com.pixilapps.dual_screen_ce` and channel names are `dual_screen_ce/*`.
* Requires Dart ≥ 3.12, Flutter ≥ 3.44, Android minSdk 24, iOS deployment target 15.0.
* `DualScreenInfo.hingeAngleEvents` no longer starts with a synthetic 180°; it emits only real sensor values.
