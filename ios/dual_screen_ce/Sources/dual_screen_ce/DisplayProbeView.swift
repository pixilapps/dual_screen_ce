// Copyright (c) 2026 Pixil Apps. Licensed under the MIT License.

import UIKit

/// A transparent, non-interactive subview filling the Flutter view, so it shares its coordinates, safe area and traits.
///
/// It reports every event that can change the display state: layout, safe area, window moves, reserved regions
/// (read in `updateConstraints()`, which UIKit re-runs when they change) and the traits behind the vertical bar edge.
final class DisplayProbeView: UIView {
  var onChange: (() -> Void)?

  /// One layout guide per directional bar edge, created on first use. UIKit keeps their frames current.
  private var barGuides: [UInt: UILayoutGuide] = [:]

  override class var requiresConstraintBasedLayout: Bool { true }

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    accessibilityElementsHidden = true
    backgroundColor = .clear
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self, UITraitLayoutDirection.self]) {
        (view: DisplayProbeView, _: UITraitCollection) in view.onChange?()
      }
      registerForVerticalBarTraits()
    }
  }

  required init?(coder: NSCoder) { nil }

  /// The traits behind `verticalBarEdge` come from the runtime as class objects, which Swift cannot cast to `UITrait`, so
  /// they are registered through the Objective-C method, which takes the classes as they are.
  private func registerForVerticalBarTraits() {
    let traits = DuoRuntime.traitsAffectingVerticalBarEdge
    let selector = NSSelectorFromString("registerForTraitChanges:withHandler:")
    guard !traits.isEmpty, responds(to: selector) else { return }
    let handler: @convention(block) (AnyObject, UITraitCollection) -> Void = { [weak self] _, _ in self?.onChange?() }
    _ = perform(selector, with: traits as NSArray, with: unsafeBitCast(handler, to: AnyObject.self))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    onChange?()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onChange?()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    setNeedsUpdateConstraints()
    onChange?()
  }

  override func updateConstraints() {
    // Reading the regions here is what subscribes this view to their changes.
    _ = DuoRuntime.reservedRegions(of: .division, in: self)
    _ = DuoRuntime.reservedRegions(of: .occlusion, in: self)
    super.updateConstraints()
    onChange?()
  }

  /// The frame of the region the system bar would draw in on `edge`, in this view's coordinates.
  /// Uses the system extent (iOS 27.2) and falls back to `fallbackExtent` (iOS 27.1, which needs one).
  func barFrame(on edge: NSDirectionalRectEdge, fallbackExtent: CGFloat) -> CGRect? {
    if let guide = barGuides[edge.rawValue] { return guide.layoutFrame }
    guard let region = DuoRuntime.barRegion(on: edge, extent: nil) ?? DuoRuntime.barRegion(on: edge, extent: fallbackExtent),
          let guide = DuoRuntime.layoutGuide(for: region, in: self)
    else { return nil }
    barGuides[edge.rawValue] = guide
    return guide.layoutFrame
  }
}
