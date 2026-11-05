// Copyright (c) 2026 Pixil Apps. Licensed under the MIT License.

import Flutter
import UIKit

// ponytail: spike-only diagnostics for doc/iphone_duo_matrix.md (plan step 1.0). Delete this file once the matrix is
// recorded; nothing in the public API depends on it.
enum DebugProbe {
  private typealias ClassRectEdgeGetter = @convention(c) (AnyClass, Selector, UInt) -> Unmanaged<AnyObject>?

  static func dump(view: UIView, controller: UIViewController?, state: DisplayState, hingeAngle: Double?) -> [String: Any] {
    let insets = view.safeAreaInsets
    var out: [String: Any] = [
      "state": state.toMap(),
      "hingeAngle": hingeAngle as Any? ?? NSNull(),
      "bounds": DisplayState.encode(view.bounds),
      "safeArea": DisplayState.encode(insets),
      "layoutMargins": DisplayState.encode(view.layoutMargins),
      "rtl": view.effectiveUserInterfaceLayoutDirection == .rightToLeft,
      "verticalBarEdgeTrait": DuoRuntime.verticalBarEdge(view.traitCollection) ?? -1,
      "traitsAffectingEdge": DuoRuntime.traitsAffectingVerticalBarEdge.count,
      "controllerClass": controller.map { NSStringFromClass(type(of: $0)) } ?? NSNull(),
      "respondsToPreferredVerticalBarBehavior": controller?.responds(to: NSSelectorFromString("preferredVerticalBarBehavior")) ?? false,
    ]
    if let window = view.window {
      out["windowBounds"] = DisplayState.encode(window.bounds)
      out["viewInWindow"] = DisplayState.encode(view.convert(view.bounds, to: window))
      if let scene = window.windowScene {
        out["screenBounds"] = DisplayState.encode(scene.screen.bounds)
        out["screenNativeBounds"] = DisplayState.encode(scene.screen.nativeBounds)
        if #available(iOS 16.0, *) { out["interfaceOrientation"] = scene.effectiveGeometry.interfaceOrientation.rawValue }
        if let frame = scene.statusBarManager?.statusBarFrame { out["statusBarFrame"] = DisplayState.encode(view.convert(frame, from: window)) }
      }
    }
    var bars: [String: Any] = [:]
    for (name, edge) in [("leading", NSDirectionalRectEdge.leading), ("trailing", .trailing)] {
      var entry: [String: Any] = [:]
      if let region = DuoRuntime.barRegion(on: edge, extent: nil) { entry["systemExtent"] = describe(region, in: view) }
      let extent = max(insets.left, insets.right)
      if extent > 0, let region = DuoRuntime.barRegion(on: edge, extent: extent) { entry["insetExtent"] = describe(region, in: view) }
      bars[name] = entry
    }
    for (name, edge) in [("left", UIRectEdge.left), ("right", .right)] {
      if let region = physicalBarRegion(edge) { bars["physical-\(name)"] = describe(region, in: view) }
    }
    out["barRegions"] = bars
    var corners: [String: Any] = [:]
    for (name, axis) in [("none", UInt(0)), ("horizontal", 1), ("vertical", 2)] {
      if let region = DuoRuntime.cornerAdaptedSafeArea(axis: axis) { corners[name] = describe(region, in: view) }
    }
    out["cornerAdaptedSafeArea"] = corners
    return out
  }

  private static func describe(_ region: AnyObject, in view: UIView) -> [String: Any] {
    var out: [String: Any] = ["description": String(describing: region)]
    if let insets = DuoRuntime.edgeInsets(for: region, in: view) { out["edgeInsets"] = DisplayState.encode(insets) }
    if let guide = DuoRuntime.layoutGuide(for: region, in: view) {
      view.layoutIfNeeded()
      out["guideFrame"] = DisplayState.encode(guide.layoutFrame)
    }
    return out
  }

  private static func physicalBarRegion(_ edge: UIRectEdge) -> AnyObject? {
    guard let cls = NSClassFromString("UIViewLayoutRegion") else { return nil }
    let sel = NSSelectorFromString("layoutRegionForBarOnEdge:")
    guard let method = class_getClassMethod(cls, sel) else { return nil }
    return unsafeBitCast(method_getImplementation(method), to: ClassRectEdgeGetter.self)(cls, sel, edge.rawValue)?.takeUnretainedValue()
  }

  /// Presents a native alert or sheet, reports where UIKit put it, then dismisses it.
  static func probePresentation(_ kind: String, from controller: UIViewController, result: @escaping FlutterResult) {
    let presented: UIViewController
    if kind == "sheet" {
      presented = UIViewController()
      presented.view.backgroundColor = .systemBackground
      presented.sheetPresentationController?.detents = [.medium(), .large()]
    } else {
      let alert = UIAlertController(title: "Duo probe", message: "Where does this land?", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      presented = alert
    }
    controller.present(presented, animated: false) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        let window = controller.view.window
        let frame = presented.view.convert(presented.view.bounds, to: window)
        let report: [String: Any] = [
          "kind": kind,
          "frameInWindow": DisplayState.encode(frame),
          "windowBounds": DisplayState.encode(window?.bounds ?? .zero),
          "presentedSafeArea": DisplayState.encode(presented.view.safeAreaInsets),
        ]
        presented.dismiss(animated: false) { result(report) }
      }
    }
  }
}
