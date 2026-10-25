# dual_screen_ce

Community edition of Microsoft's archived [`dual_screen`](https://pub.dev/packages/dual_screen), maintained by Pixil Apps.
Not affiliated with or endorsed by Microsoft.

Foldable and dual-screen support for Flutter on **Android foldables** and **iPhone Duo**:

- The [TwoPane widget](#twopane-widget) lays out two panes around a hinge or fold reported by `MediaQuery.displayFeatures`.
- [Hinge angle](#hinge-angle) events, in degrees, from the Android hinge sensor and the iPhone Duo hinge.
- [`DualScreenScope`](#iphone-duo) publishes the iPhone Duo fold to `MediaQuery`, which Flutter doesn't do on iOS yet.

```yaml
dependencies:
  dual_screen_ce: ^1.0.0
```

```dart
import 'package:dual_screen_ce/dual_screen_ce.dart';
```

Migrating from `dual_screen`? Change the dependency and the import; the class names are unchanged. See the [changelog](CHANGELOG.md).

# TwoPane widget

`TwoPane` has two child panes, which can be shown side-by-side, above-and-below, or a single pane can be prioritized. The relative size of the panes can be adjusted proportionally; on devices with a hinge or fold, the boundary snaps to it.

## TwoPane API

```dart
class TwoPane {
  const TwoPane({
    Widget? startPane,
    Widget? endPane,
    Widget? singleWidget,
    double paneProportion = 0.5,
    TwoPanePriority panePriority = TwoPanePriority.both,
    Axis direction = Axis.horizontal,
    TextDirection? textDirection,
    VerticalDirection verticalDirection = VerticalDirection.down,
    EdgeInsets padding = EdgeInsets.zero,
    Set<TwoPaneAllowedOverrides> allowedOverrides = const {...all},
    ValueNotifier<bool>? switchToSinglePane,
    Duration animationDuration = const Duration(milliseconds: 350),
    Curve animationCurve = Curves.easeInOut,
  });
}
```

- `startPane` - Start pane: on the left for left-to-right layouts, or at the top for top-to-bottom layouts. If `panePriority` is `start` and there is no hinge, this is the only visible pane.
- `endPane` - End pane: on the right for left-to-right layouts, or at the bottom for top-to-bottom layouts. If `panePriority` is `end` and there is no hinge, this is the only visible pane.
- `singleWidget` - A widget spanning both panes, ignoring the fold. Pass it alone to always show one widget, or together with `startPane`, `endPane` and `switchToSinglePane` for toggle mode.
- `switchToSinglePane` - Drives toggle mode: `true` shows the two panes, `false` shows `singleWidget`, with a cross-fade (`animationDuration`, `animationCurve`). Without it, TwoPane shows the two panes.
- `paneProportion` - Proportion of the screen occupied by the start pane; the end pane takes the rest. Ignored when a hinge or fold separates the screen.
- `panePriority` - Show only the start pane, only the end pane, or both. Ignored when a hinge or fold separates the screen.
- `direction` - Stack the panes horizontally or vertically, like [Flex direction](https://api.flutter.dev/flutter/widgets/Flex/direction.html). With a hinge, the direction follows the hinge.
- `textDirection` - When panes are laid out horizontally, decides which one goes on the left, like [Flex textDirection](https://api.flutter.dev/flutter/widgets/Flex/textDirection.html).
- `verticalDirection` - When panes are laid out vertically, decides which one goes at the top, like [Flex verticalDirection](https://api.flutter.dev/flutter/widgets/Flex/verticalDirection.html).
- `padding` - The padding between TwoPane and the edges of the screen, used to align the panes to the hinge when TwoPane isn't full screen.
- `allowedOverrides` - Which of `paneProportion`, `direction` and `panePriority` TwoPane may override when a hinge or fold is found. All three by default.

## TwoPane example

```dart
Widget build(BuildContext context) {
  return TwoPane(
    startPane: _widgetA(),
    endPane: _widgetB(),
    paneProportion: 0.3,
    panePriority: MediaQuery.sizeOf(context).width > 500 ? TwoPanePriority.both : TwoPanePriority.start,
  );
}
```

- On a **foldable** with a separating hinge or a half-open fold, widget A and widget B each take one side.
- On a **tablet** or **desktop**, widget A takes 30% of the screen and widget B the remaining 70%.
- On a **phone** narrower than 500 logical pixels, only widget A is visible.

# Hinge angle

`DualScreenInfo` exposes two static properties:

- `hingeAngleEvents` - Broadcast stream of hinge angles in degrees: 0 is closed, 180 is flat. Late listeners get the latest value right away. Without a hinge, the stream is empty.
- `hasHingeAngleSensor` - `true` on Android foldables with a hinge angle sensor and on iPhone Duo; `false` elsewhere. Never throws.

```dart
DualScreenInfo.hingeAngleEvents.listen((double hingeAngle) {
  print(hingeAngle);
});

final bool isFoldable = await DualScreenInfo.hasHingeAngleSensor;
```

> For layout decisions, prefer `MediaQuery.displayFeatures` (or `TwoPane`) over the raw angle.

# iPhone Duo

Flutter does not report display features on iOS yet ([flutter#192515](https://github.com/flutter/flutter/issues/192515)).
Wrap your app in `DualScreenScope` to publish the fold while the device is partially open:

```dart
void main() => runApp(const DualScreenScope(child: MyApp()));
```

`DualScreenScope` does nothing on other platforms, and steps aside on its own once Flutter reports display features on iOS. The iOS side is provided by the [`foldable`](https://pub.dev/packages/foldable) plugin, which works with both CocoaPods and Swift Package Manager.

**App requirements:** build with Xcode 27.1 (iOS 27.1 SDK) to get the hinge on device, adopt the UIScene
lifecycle (required by the iOS 27 SDK), deployment target ≥ iOS 15, and don't lock orientation on hinged devices.
While the Duo is partially open, Flutter keeps dialogs and sheets on one side of the fold, the same way it does on Android foldables.

# Testing

- Android: the foldable emulators in Android Studio (Pixel Fold, resizable) have a virtual hinge angle sensor.
- iOS: the iPhone Duo simulator in Xcode 27.1 (Device Hub) simulates closed, partially folded and flat poses.
- Widget tests: put a `DisplayFeature` into a `MediaQuery`. See [`test/two_pane_duo_test.dart`](test/two_pane_duo_test.dart) for iPhone Duo geometry.

# License

MIT. Copyright (c) Microsoft Corporation and (c) 2026 Pixil Apps; see [LICENSE](LICENSE).
