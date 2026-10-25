import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;
import 'package:flutter/widgets.dart';

/// Copyright (c) Microsoft Corporation.
/// Licensed under the MIT License.

/// A widget that positions two panes side by side on uninterrupted screens or
/// on either side of a separating [DisplayFeature] on screens interrupted by a
/// separating [DisplayFeature].
///
/// A [DisplayFeature] separates the screen into sub-screens when both these
/// conditions are met:
///
///   * it obstructs the screen, meaning the area it occupies is not 0. Display
///     features of type [DisplayFeatureType.fold] can have height 0 or width 0
///     and not be obstructing the screen.
///   * it is at least as tall as the screen, producing a left and right
///     sub-screen or it is at least as wide as the screen, producing a top and
///     bottom sub-screen.
///
/// When positioning the two panes, [direction], [paneProportion] and
/// [panePriority] parameters are ignored and values are replaced in order to
/// avoid the separating [DisplayFeature]:
///
///   * On screens with a separating [DisplayFeature], the two panes are
///     positioned on each side of the feature. If the [DisplayFeature] splits
///     the screen left and right, [direction] is [Axis.horizontal]. Otherwise,
///     [direction] is [Axis.vertical]. The [paneProportion] and [panePriority]
///     parameters are also ignored and each pane occupies a sub-screen.
///   * On screens without a separating [DisplayFeature], [direction] is used
///     for deciding if the 2 panes are laid out horizontally or vertically and
///     [paneProportion] is used for deciding how much space each pane takes.
///
/// This widget is similar to [Flex] and also takes [textDirection] and
/// [verticalDirection] parameters, which are used for deciding in what order
/// the panes are laid out (e.g [TextDirection.ltr] would position [startPane]
/// on the left and [endPane] on the right).
///
/// The [panePriority] parameter can be used to display only one pane on screens
/// without any separating [DisplayFeature], by using [TwoPanePriority.start]
/// or [TwoPanePriority.end]. When [TwoPanePriority.both] is used or when the
/// screen has a separating [DisplayFeature], both panes are visible.
///
/// Similarly to [SafeArea] and [DisplayFeatureSubScreen], this widget assumes
/// there is no distance between it and the first [MediaQuery] ancestor. If this
/// is not true, the bounds of display features will not align with the
/// separation between the two panes. The [padding] parameter can be used to align
/// TwoPane with the real position of display features. The [padding] parameter is
/// the padding between TwoPane and the edges of the screen.
///
/// Pane widgets are wrapped in modified [MediaQuery] parents, removing padding,
/// insets and display features that no longer intersect with them.
///
/// If not provided, [textDirection] defaults to the ambient [Directionality].
/// If none are provided, then the widget asserts during build in debug mode.
/// The resolved [direction] of TwoPane is [Axis.horizontal] when there are
/// display features separating the screen into two horizontal sub-screens, in
/// which case the provided [direction] is ignored.
///
/// When [singleWidget], [startPane], and [endPane] are all provided, a toggle
/// button is displayed that allows switching between the single-widget view
/// and the dual-pane view with a cross-fade animation.
///
/// See also
///
///  * [DisplayFeature] and [MediaQueryData.displayFeatures], to further
///    understand display features
///  * [MediaQueryData.removeDisplayFeatures] which is used to remove padding,
///    insets and display features for each pane.
class TwoPane extends StatelessWidget {
  /// Create a layout that shows two pane widgets side by side.
  ///
  /// Provide [singleWidget] alone, both [startPane] and [endPane], or all
  /// three. When all three are provided a toggle button animates between
  /// the single-widget view and the dual-pane layout.
  const TwoPane({
    super.key,
    this.endPane,
    this.startPane,
    this.singleWidget,
    this.textDirection,
    this.padding = .zero,
    this.paneProportion = 0.5,
    this.panePriority = .both,
    this.direction = .horizontal,
    this.verticalDirection = .down,
    this.allowedOverrides = const <TwoPaneAllowedOverrides>{.paneProportion, .direction, .panePriority},
    // this.toggleButtonBuilder,
    this.animationDuration = const .new(milliseconds: 350),
    this.animationCurve = Curves.easeInOut,
    // this.showDualPaneFirst = true,
    this.switchToSinglePane,
  }) : assert(
         (singleWidget != null) || (startPane != null && endPane != null),
         'Provide singleWidget alone, both startPane and endPane, or all three for toggle mode.',
       );

  /// A widget that spans the entire area across both panels, ignoring
  /// the fold or hinge display feature.
  ///
  /// When provided alone (without [startPane] / [endPane]), this widget
  /// occupies the full space from the start panel edge to the end panel edge,
  /// rendering over any separating [DisplayFeature].
  ///
  /// When provided together with [startPane] and [endPane], a toggle button
  /// appears that lets the user switch between this single view and the
  /// dual-pane layout.
  ///
  /// Either [singleWidget] must be non-null, or both [startPane] and
  /// [endPane] must be non-null.
  final Widget? singleWidget;

  /// The first pane.
  ///
  /// On a horizontal layout, where [direction] is [Axis.horizontal]:
  ///
  ///   * The first pane is on the left when [textDirection] is
  ///     [TextDirection.ltr]
  ///   * The first pane is on the right when [textDirection] is
  ///     [TextDirection.rtl]
  ///
  /// On a vertical layout, where [direction] is [Axis.vertical]:
  ///
  ///   * The first pane is at the top when [verticalDirection] is
  ///     [VerticalDirection.down]
  ///   * The first pane is at the bottom when [verticalDirection] is
  ///     [VerticalDirection.up]
  ///
  /// If [panePriority] is [TwoPanePriority.start], this is the only pane
  /// visible.
  ///
  /// Must be non-null when [singleWidget] is null.
  final Widget? startPane;

  /// The second pane.
  ///
  /// On a horizontal layout, where [direction] is [Axis.horizontal]:
  ///
  ///   * The second pane is on the right when [textDirection] is
  ///     [TextDirection.ltr]
  ///   * The second pane is on the left when [textDirection] is
  ///     [TextDirection.rtl]
  ///
  /// On a vertical layout, where [direction] is [Axis.vertical]:
  ///
  ///   * The second pane is at the bottom when [verticalDirection] is
  ///     [VerticalDirection.down]
  ///   * The second pane is at the top when [verticalDirection] is
  ///     [VerticalDirection.up]
  ///
  /// If [panePriority] is [TwoPanePriority.end], this is the only pane
  /// visible.
  ///
  /// Must be non-null when [singleWidget] is null.
  final Widget? endPane;

  /// Proportion of the available space occupied by the first pane. The second
  /// pane takes over the rest of the screen.
  ///
  /// A value of 0.5 will make the 2 panes equal.
  ///
  /// This property is ignored is the screen is split into sub-screens by a
  /// [DisplayFeature], in which case each pane takes over one sub-screen.
  final double paneProportion;

  /// Same as [Flex.textDirection].
  ///
  /// If the resolved [direction] is [Axis.horizontal], [textDirection] defaults
  /// to the ambient [Directionality]. If none is provided, then the widget
  /// asserts during build in debug mode.
  final TextDirection? textDirection;

  /// Same as [Flex.verticalDirection].
  ///
  /// Defaults to [VerticalDirection.down].
  final VerticalDirection verticalDirection;

  /// Same as [Flex.direction].
  ///
  /// This property is ignored is the screen is split into sub-screens by a
  /// [DisplayFeature], in which case the direction is:
  ///
  ///   * [Axis.horizontal] when the sub-screens are located left and right.
  ///   * [Axis.vertical] when the sub-screens are located top and bottom.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis direction;

  /// Whether to show only one pane and which one, or both.
  ///
  /// This property is ignored is the screen is split into sub-screens by a
  /// [DisplayFeature], in which case each pane takes over one sub-screen.
  ///
  /// Defaults to [TwoPanePriority.both].
  final TwoPanePriority panePriority;

  /// The padding between TwoPane and the edges of the screen.
  ///
  /// Used to align TwoPane with the real position of display features. It
  /// measures the distance between TwoPane and the ambient MediaQuery.
  ///
  /// Defaults to [EdgeInsets.zero].
  final EdgeInsets padding;

  /// The parameters that TwoPane is allowed to override when a separating
  /// display feature is found.
  ///
  /// For example, if [direction] is [Axis.horizontal] and TwoPane should not
  /// override it to be [Axis.vertical] when a horizontal hinge is present (in a
  /// double-landscape device configuration), the value for `allowedOverrides`
  /// can be `const {TwoPaneAllowedOverrides.paneProportion,
  /// TwoPaneAllowedOverrides.panePriority}`. This still allows TwoPane to
  /// override [paneProportion] and [panePriority] so that the hinge acts as a
  /// boundary between the two panes if a vertical hinge is present (in a
  /// double-portrait device configuration).
  ///
  /// Defaults to `{TwoPaneAllowedOverrides.paneProportion,
  /// TwoPaneAllowedOverrides.direction, TwoPaneAllowedOverrides.panePriority}`,
  /// allowing all possible overrides.
  final Set<TwoPaneAllowedOverrides> allowedOverrides;

  /// Builder for a custom toggle button widget.
  ///
  /// Only used when [singleWidget], [startPane], and [endPane] are all
  /// provided. Receives the current mode (`true` when showing dual pane) and
  /// a callback to trigger the toggle. When `null`, a default pill-shaped
  /// toggle button is rendered at the bottom-right corner.
  // final Widget Function(BuildContext context, bool isDualPane, VoidCallback toggle)? toggleButtonBuilder;

  /// Duration of the cross-fade animation when toggling between modes.
  ///
  /// Defaults to 350 milliseconds.
  final Duration animationDuration;

  /// Curve applied to the toggle animation.
  ///
  /// Defaults to [Curves.easeInOut].
  final Curve animationCurve;

  /// When all three widgets are provided, whether to initially show dual pane
  /// (`true`) or single widget (`false`).
  ///
  /// Defaults to `true`.
  // final bool showDualPaneFirst;

  /// Drives toggle mode: `true` shows the dual-pane layout, `false` shows
  /// [singleWidget]. Toggle mode needs all three widgets and this notifier;
  /// without it TwoPane shows the dual-pane layout.
  final ValueNotifier<bool>? switchToSinglePane;

  TextDirection _resolveTextDirection(BuildContext context) => textDirection ?? Directionality.of(context);

  @override
  Widget build(BuildContext context) {
    final bool hasPanes = startPane != null && endPane != null;
    if (singleWidget != null && hasPanes && switchToSinglePane != null) return _TwoPaneToggle(config: this);
    if (hasPanes) return _buildDualPaneLayout(context);
    return singleWidget!;
  }

  Widget _buildDualPaneLayout(BuildContext context) {
    assert(
      textDirection != null ||
          debugCheckHasDirectionality(
            context,
            why:
                'to determine what pane goes on the right or left side. The real '
                'direction of TwoPane is horizontal when there are display features '
                'separating the screen into two horizontal sub-screens, in which case '
                'the provided "direction" is ignored.',
            alternative: "Alternatively, consider specifying the 'textDirection' argument on the TwoPane.",
          ),
    );
    final TextDirection resolvedTextDirection = _resolveTextDirection(context);

    final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
    late Rect? displayFeatureBounds;
    late final Size size;
    Offset screenOffset = .zero;
    late final Axis resolvedDirection;
    late final int startPaneFlex;
    late final int endPaneFlex;
    late final Widget resolvedStartPane;
    late final Widget resolvedEndPane;
    late final Widget resolvedDelimiter;
    late final TwoPanePriority resolvedPanePriority;
    const int fractionBase = 1000000000000;

    if (mediaQuery == null) {
      resolvedDirection = direction;
      resolvedPanePriority = panePriority;
    } else {
      final Rect position = padding.deflateRect(Offset.zero & mediaQuery.size);
      size = position.size;
      screenOffset = position.topLeft;
      final Iterable<DisplayFeature> separatingDisplayFeatures = _separatingDisplayFeatures(mediaQuery.displayFeatures, position);
      resolvedDirection = _resolveDirection(separatingDisplayFeatures, position);
      final DisplayFeature? displayFeature = _firstDisplayFeature(
        separatingDisplayFeatures,
        resolvedDirection,
        resolvedTextDirection,
        verticalDirection,
        position,
      );
      if (displayFeature == null) {
        displayFeatureBounds = null;
        resolvedPanePriority = panePriority;
      } else {
        displayFeatureBounds = displayFeature.bounds.intersect(position).shift(-position.topLeft);
        if (allowedOverrides.contains(TwoPaneAllowedOverrides.panePriority)) {
          resolvedPanePriority = .both;
        } else {
          resolvedPanePriority = panePriority;
        }
      }
    }

    if (mediaQuery == null || resolvedPanePriority != .both) {
      startPaneFlex = (fractionBase * paneProportion).toInt();
      endPaneFlex = fractionBase - startPaneFlex;
      resolvedStartPane = startPane!;
      resolvedEndPane = endPane!;
      resolvedDelimiter = const SizedBox.shrink();
    } else {
      final bool allowProportionOverride = allowedOverrides.contains(TwoPaneAllowedOverrides.paneProportion);
      switch (resolvedDirection) {
        case Axis.horizontal:
          {
            late final Rect seam;
            if (displayFeatureBounds == null || !allowProportionOverride) {
              seam = Rect.fromLTWH(paneProportion * size.width, 0, 0, size.height);
            } else {
              seam = displayFeatureBounds;
            }
            resolvedDelimiter = SizedBox(width: seam.size.width);
            final int leftFlex = (seam.left * fractionBase).toInt();
            final int rightFlex = ((size.width - seam.right) * fractionBase).toInt();
            final Rect leftScreen = Offset.zero & Size(seam.left, size.height);
            final Rect rightScreen = seam.topRight & Size(size.width - seam.right, size.height);
            switch (resolvedTextDirection) {
              case .ltr:
                {
                  startPaneFlex = leftFlex;
                  endPaneFlex = rightFlex;
                  resolvedStartPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, leftScreen, screenOffset), child: startPane!);
                  resolvedEndPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, rightScreen, screenOffset), child: endPane!);
                }
                break;
              case .rtl:
                {
                  startPaneFlex = rightFlex;
                  endPaneFlex = leftFlex;
                  resolvedStartPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, rightScreen, screenOffset), child: startPane!);
                  resolvedEndPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, leftScreen, screenOffset), child: endPane!);
                }
                break;
            }
          }
          break;
        case .vertical:
          {
            late final Rect seam;
            if (displayFeatureBounds == null || !allowProportionOverride) {
              seam = .fromLTWH(0, paneProportion * size.height, size.width, 0);
            } else {
              seam = displayFeatureBounds;
            }
            resolvedDelimiter = SizedBox(height: seam.size.height);
            final int topPane = (seam.top * fractionBase).toInt();
            final int bottomPane = ((size.height - seam.bottom) * fractionBase).toInt();
            final Rect topScreen = Offset.zero & Size(size.width, seam.top);
            final Rect bottomScreen = seam.bottomLeft & Size(size.width, size.height - seam.bottom);
            switch (verticalDirection) {
              case .down:
                {
                  startPaneFlex = topPane;
                  endPaneFlex = bottomPane;
                  resolvedStartPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, topScreen, screenOffset), child: startPane!);
                  resolvedEndPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, bottomScreen, screenOffset), child: endPane!);
                }
                break;
              case .up:
                {
                  startPaneFlex = bottomPane;
                  endPaneFlex = topPane;
                  resolvedStartPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, bottomScreen, screenOffset), child: startPane!);
                  resolvedEndPane = MediaQuery(data: _removeMediaQueryPadding(mediaQuery, topScreen, screenOffset), child: endPane!);
                }
                break;
            }
          }
          break;
      }
    }

    return Flex(
      direction: resolvedDirection,
      crossAxisAlignment: .stretch,
      textDirection: resolvedTextDirection,
      verticalDirection: verticalDirection,
      mainAxisAlignment: resolvedPanePriority != .both ? .center : .start,
      children: <Widget>[
        if (resolvedPanePriority != .end) KeyedSubtree.wrap(Expanded(flex: startPaneFlex, child: resolvedStartPane), 1),
        if (resolvedPanePriority == .both) resolvedDelimiter,
        if (resolvedPanePriority != .start) KeyedSubtree.wrap(Expanded(flex: endPaneFlex, child: resolvedEndPane), 2),
      ],
    );
  }

  /// Determines what direction to use while laying out panes.
  ///
  /// If [allowedOverrides] does not allows for overriding direction, then the
  /// provided parameter [direction] is returned.
  ///
  /// If it is allowed, then this method looks for separating display features.
  ///
  ///   * If one is found, the direction is determined by how it splits the
  ///     screen into sub-screens.
  ///   * If multiple are found in the same direction, the same rule applies.
  ///   * If multiple are found in both directions, then the provided
  ///     [direction] is used.
  Axis _resolveDirection(Iterable<DisplayFeature> separatingFeatures, Rect position) {
    if (!allowedOverrides.contains(TwoPaneAllowedOverrides.direction)) {
      return direction;
    }
    bool verticalSubScreensExist = false;
    bool horizontalSubScreensExist = false;
    for (final DisplayFeature displayFeature in separatingFeatures) {
      if (_splitsHorizontally(displayFeature.bounds, position)) horizontalSubScreensExist = true;
      if (_splitsVertically(displayFeature.bounds, position)) verticalSubScreensExist = true;
    }
    if (verticalSubScreensExist && !horizontalSubScreensExist) return .vertical;
    if (horizontalSubScreensExist && !verticalSubScreensExist) return .horizontal;
    return direction;
  }

  /// Retrieves the first [DisplayFeature] that splits the screen into separate
  /// sub-screens in the provided direction.
  ///
  /// In case there are multiple display features, [textDirection] or
  /// [verticalDirection] are used to determine the first one, according
  /// [direction].
  static DisplayFeature? _firstDisplayFeature(
    Iterable<DisplayFeature> displayFeatures,
    Axis direction,
    TextDirection textDirection,
    VerticalDirection verticalDirection,
    Rect position,
  ) {
    if (displayFeatures.isEmpty) {
      return null;
    }
    DisplayFeature? result;
    for (final DisplayFeature displayFeature in displayFeatures) {
      switch (direction) {
        case .horizontal:
          {
            if (!_splitsHorizontally(displayFeature.bounds, position)) continue;
            switch (textDirection) {
              case .ltr:
                {
                  if (result == null || displayFeature.bounds.left < result.bounds.left) result = displayFeature;
                }
                break;
              case .rtl:
                {
                  if (result == null || displayFeature.bounds.right > result.bounds.right) result = displayFeature;
                }
                break;
            }
          }
          break;
        case .vertical:
          {
            if (!_splitsVertically(displayFeature.bounds, position)) continue;
            switch (verticalDirection) {
              case .down:
                {
                  if (result == null || displayFeature.bounds.top < result.bounds.top) result = displayFeature;
                }
                break;
              case .up:
                {
                  if (result == null || displayFeature.bounds.bottom > result.bounds.bottom) result = displayFeature;
                }
                break;
            }
          }
          break;
      }
    }
    return result;
  }

  /// Returns only the display features that separate the screen into
  /// sub-screens.
  ///
  /// A [DisplayFeature] separates the screen into sub-screens when both these
  /// conditions are met:
  ///
  ///   * it obstructs the screen, meaning the area it occupies is not 0. Display
  ///     features of type [DisplayFeatureType.fold] can have height 0 or width 0
  ///     and not be obstructing the screen.
  ///   * it is at least as tall as the screen, producing a left and right
  ///     sub-screen or it is at least as wide as the screen, producing a top and
  ///     bottom sub-screen.
  static Iterable<DisplayFeature> _separatingDisplayFeatures(Iterable<DisplayFeature> displayFeatures, Rect position) {
    final List<DisplayFeature> result = <DisplayFeature>[];
    for (final DisplayFeature displayFeature in displayFeatures) {
      final Rect bounds = displayFeature.bounds;
      if (_splitsHorizontally(bounds, position) || _splitsVertically(bounds, position)) result.add(displayFeature);
    }
    return result;
  }

  static bool _splitsHorizontally(Rect bounds, Rect position) {
    final bool tallEnough = bounds.top <= position.top && bounds.bottom >= position.bottom;
    final bool splitsHorizontally = bounds.left > position.left && bounds.right < position.right;
    return tallEnough && splitsHorizontally;
  }

  static bool _splitsVertically(Rect bounds, Rect position) {
    final bool wideEnough = bounds.left <= position.left && bounds.right >= position.right;
    final bool splitsVertically = bounds.top > position.top && bounds.bottom < position.bottom;
    return wideEnough && splitsVertically;
  }

  /// Removes MediaQuery padding, insets, and display features that fall
  /// outside [subScreen]. The [origin] offset translates the sub-screen from
  /// local coordinates back to screen coordinates for display-feature
  /// intersection testing.
  static MediaQueryData _removeMediaQueryPadding(MediaQueryData data, Rect subScreen, [Offset origin = .zero]) {
    assert(
      subScreen.left >= 0.0 && subScreen.top >= 0.0 && subScreen.right <= data.size.width && subScreen.bottom <= data.size.height,
      "'subScreen' argument cannot be outside the bounds of the screen",
    );
    if (subScreen.size == data.size && subScreen.topLeft == .zero) return data;
    final double rightInset = data.size.width - subScreen.right;
    final double bottomInset = data.size.height - subScreen.bottom;

    final Rect screenSubScreen = subScreen.shift(origin);
    final List<DisplayFeature> filteredFeatures = <DisplayFeature>[
      for (final DisplayFeature feature in data.displayFeatures)
        if (feature.bounds.overlaps(screenSubScreen)) feature,
    ];

    return data.copyWith(
      padding: .only(
        top: math.max(0.0, data.padding.top - subScreen.top),
        right: math.max(0.0, data.padding.right - rightInset),
        left: math.max(0.0, data.padding.left - subScreen.left),
        bottom: math.max(0.0, data.padding.bottom - bottomInset),
      ),
      viewPadding: .only(
        top: math.max(0.0, data.viewPadding.top - subScreen.top),
        right: math.max(0.0, data.viewPadding.right - rightInset),
        left: math.max(0.0, data.viewPadding.left - subScreen.left),
        bottom: math.max(0.0, data.viewPadding.bottom - bottomInset),
      ),
      viewInsets: .only(
        top: math.max(0.0, data.viewInsets.top - subScreen.top),
        right: math.max(0.0, data.viewInsets.right - rightInset),
        left: math.max(0.0, data.viewInsets.left - subScreen.left),
        bottom: math.max(0.0, data.viewInsets.bottom - bottomInset),
      ),
      displayFeatures: filteredFeatures,
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle wrapper (internal)
// ---------------------------------------------------------------------------

class _TwoPaneToggle extends StatelessWidget {
  const _TwoPaneToggle({required this.config});
  final TwoPane config;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: config.switchToSinglePane!,
      builder: (BuildContext context, bool showDualPane, Widget? child) {
        final Widget content = showDualPane
            ? KeyedSubtree(key: const ValueKey<String>('dual'), child: config._buildDualPaneLayout(context))
            : KeyedSubtree(key: const ValueKey<String>('single'), child: config.singleWidget!);

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedSwitcher(
              duration: config.animationDuration,
              switchInCurve: config.animationCurve,
              switchOutCurve: config.animationCurve,
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(fit: StackFit.expand, children: <Widget>[...previousChildren, ?currentChild]);
              },
              child: content,
            ),
            // config.toggleButtonBuilder?.call(context, _showDualPane, _toggle) ?? _buildDefaultToggleButton(),
          ],
        );
      },
    );
  }
}

// // ---------------------------------------------------------------------------
// // Toggle icon painter (internal)
// // ---------------------------------------------------------------------------

// class _ToggleIconPainter extends CustomPainter {
//   _ToggleIconPainter({required this.isDualPane});

//   final bool isDualPane;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint paint = Paint()
//       ..color = const Color(0xFFFFFFFF)
//       ..style = PaintingStyle.fill;

//     const double r = 2;
//     if (isDualPane) {
//       final double gap = 3;
//       final double paneWidth = (size.width - gap) / 2;
//       canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, paneWidth, size.height), const Radius.circular(r)), paint);
//       canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(paneWidth + gap, 0, paneWidth, size.height), const Radius.circular(r)), paint);
//     } else {
//       canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)), paint);
//     }
//   }

//   @override
//   bool shouldRepaint(_ToggleIconPainter oldDelegate) => isDualPane != oldDelegate.isDualPane;
// }

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Describes if showing both panes at the same time or which one if only one is
/// shown.
enum TwoPanePriority {
  /// Show both panes
  both,

  /// Show only the first pane
  start,

  /// Show only the second pane
  end,
}

enum TwoPaneAllowedOverrides { direction, panePriority, paneProportion }
