# dual_screen_ce

Community edition of Microsoft's archived [`dual_screen`](https://pub.dev/packages/dual_screen), maintained by Pixil Apps.
Not affiliated with or endorsed by Microsoft.

Foldable and dual-screen support for Flutter on **Android foldables** and **iPhone Duo**:

- The [TwoPane widget](#twopane-widget) lays out two panes around a hinge or fold reported by `MediaQuery.displayFeatures`.
- [Hinge angle](#hinge-angle) events, in degrees, from the Android hinge sensor and the iPhone Duo hinge.
- [`DualScreen`](#iphone-duo): posture, fold and camera regions, size classes and the [system vertical bar](#the-vertical-bar)
  on iPhone Duo, provided by `DualScreenScope`, which also publishes the fold to `MediaQuery` (Flutter doesn't on iOS yet).

```yaml
dependencies:
  dual_screen_ce: ^1.1.0
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

`DualScreenInfo` exposes static members for code outside the widget tree:

- `hingeAngleEvents` - Broadcast stream of hinge angles in degrees: 0 is closed, 180 is flat. The sensor runs only while the stream has listeners, and a listener that arrives later gets the latest value right away. Without a hinge, the stream is empty.
- `hasHingeAngleSensor` - `true` on Android foldables with a hinge angle sensor and on iPhone Duo; `false` elsewhere. Never throws.
- `displayStateEvents` - iPhone Duo display state as `DualScreenData`, on change only (empty off iOS). Inside the tree, read `DualScreen` instead.
- `setPreferredVerticalBarBehavior` - turns the iPhone Duo system vertical bar off or on (see [The vertical bar](#the-vertical-bar)).

```dart
DualScreenInfo.hingeAngleEvents.listen((double hingeAngle) {
  print(hingeAngle);
});

final bool isFoldable = await DualScreenInfo.hasHingeAngleSensor;
```

> Apple's guidance: drive effects and interactions from the angle, and layout from the posture, regions and size classes
> (`DualScreen`, `TwoPane`).

# iPhone Duo

Flutter does not report display features on iOS yet ([flutter#192515](https://github.com/flutter/flutter/issues/192515)), and it
draws its own bars, so none of iPhone Duo's system adaptations reach a Flutter app on their own. This package bridges the
platform facts; your app decides what to do with them.

```dart
void main() => runApp(const DualScreenScope(child: MyApp()));
```

`DualScreenScope` goes above `MaterialApp` / `CupertinoApp`. It provides `DualScreen` to the tree and, while the device is
partially open, publishes the fold to `MediaQuery.displayFeatures`, so `TwoPane` and Flutter's dialogs and sheets keep off it as
they do on Android foldables. On Android it derives the same data from the display features Android already reports.

```dart
final DualScreenData duo = DualScreen.of(context);   // or one aspect, rebuilding only when it changes:
final DevicePosture posture = DualScreen.postureOf(context);        // closed, halfOpened, flat, unknown
final VerticalBar? bar = DualScreen.verticalBarOf(context);         // where the system bar goes, or null
final SizeClass width = DualScreen.horizontalSizeClassOf(context);  // compact outer display, regular inner display
final List<DisplayRegion> regions = DualScreen.regionsOf(context);  // fold (division) and cameras (occlusion)
```

| Field | iPhone Duo | Android |
|---|---|---|
| `posture` | from the hinge: `closed`, `halfOpened`, `flat` | from the fold display feature: `halfOpened`, `flat`; `unknown` without one |
| `regions` | the fold (40pt, inactive while flat) and the cameras, with `margins` and `isActive` | folds and hinges as divisions, cutouts as occlusions |
| `horizontalSizeClass`, `verticalSizeClass` | iOS size classes | `unspecified` |
| `verticalBar` | side and rect of the system vertical bar, when the system places one | `null` |
| `fold`, `foldAxis` | the active fold and its direction | the same, for a half-opened fold |

## The vertical bar

On iPhone Duo the system moves bars to a strip beside the status bar and the camera: on the outer display, on the inner
display in landscape, and on the outer edge of a Split View window. Flutter's bars are custom bars, so they do not move by
themselves. The safe area already reserves the strip's column (`MediaQuery.padding` on that side), so content that respects
the safe area stays clear of it. To put your own controls where the system bar would be, read `verticalBar`:

```dart
Stack(
  children: <Widget>[
    const MyContent(), // respects MediaQuery.padding
    if (DualScreen.verticalBarOf(context) case final VerticalBar bar) Positioned.fromRect(rect: bar.rect, child: const MyBar()),
  ],
)
```

`bar.side` is the physical side: it follows the hardware, not the text direction, and moves to the left in a left-hand Split
View window. For UIs that are better with horizontal bars, such as a calculator or a full-screen video player, turn the system
bar off; the status bar moves back to the top and the side inset goes away:

```dart
await DualScreenInfo.setPreferredVerticalBarBehavior(VerticalBarBehavior.disabled);
```

Keep that choice stable rather than toggling it as the user navigates.

## Folds

`TwoPane` splits at an active fold. The panes meet at its centre line so backgrounds stay continuous, and each pane's
`MediaQuery.padding` gains half the fold on its fold side, so `SafeArea` content stays off the crease. Scrolling content does not
need to avoid the fold; fixed controls do, which is what `DualScreen.of(context).fold` is for.

## Requirements

Build with Xcode 27.1 or later (iOS 27.1 SDK) to get the full screen, the vertical bar and reserved regions, adopt the
UIScene lifecycle (required by the iOS 27 SDK), and use a deployment target of iOS 15 or later. The plugin itself still
compiles with older Xcode versions; the iPhone Duo features then report nothing. It observes the display only while a
`DualScreenScope` or a stream listener is active, attaches to its own engine's Flutter view, and does nothing at all on
devices without a hinge.

# Testing

- Android: the foldable emulators in Android Studio (Pixel Fold, resizable) have a virtual hinge angle sensor.
- iOS: the iPhone Duo simulator in Xcode 27.1 (Device Hub) simulates the closed, partially folded and flat poses. The values it
  reports for each pose are in [`doc/iphone_duo_matrix.md`](doc/iphone_duo_matrix.md).
- Widget tests and device previews: wrap the widget under test in `DualScreen(data: DualScreenData(...))`, or put a
  `DisplayFeature` into a `MediaQuery` for `TwoPane`. See [`test/two_pane_duo_test.dart`](test/two_pane_duo_test.dart) for
  iPhone Duo geometry.

# License

MIT. Copyright (c) Microsoft Corporation and (c) 2026 Pixil Apps; see [LICENSE](LICENSE).
