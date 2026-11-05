// Copyright (c) 2026 Pixil Apps. Licensed under the MIT License.

import UIKit

/// The iOS 26 and iOS 27.1 UIKit symbols iPhone Duo support needs, resolved at runtime.
///
/// Naming them in Swift would force the iOS 27.1 SDK on every app that depends on the package, Android-only ones
/// included. Each lookup checks that the class or selector exists first and degrades to `nil` or empty, never crashes.
// ponytail: runtime lookup instead of typed calls; switch to typed calls once Flutter's minimum Xcode ships the 27.1 SDK.
enum DuoRuntime {
  // MARK: - Calling conventions

  private typealias ClassGetter = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
  private typealias ClassUIntGetter = @convention(c) (AnyClass, Selector, UInt) -> Unmanaged<AnyObject>?
  private typealias ClassUIntFloatGetter = @convention(c) (AnyClass, Selector, UInt, CGFloat) -> Unmanaged<AnyObject>?
  private typealias ViewObjectGetter = @convention(c) (UIView, Selector, AnyObject) -> Unmanaged<AnyObject>?
  private typealias ViewRegionsGetter = @convention(c) (UIView, Selector, AnyObject, UInt) -> Unmanaged<NSArray>?
  private typealias InitWithBlock = @convention(c) (AnyObject, Selector, AnyObject) -> Unmanaged<AnyObject>?

  private static func classMethod<T>(_ cls: AnyClass, _ name: String, as _: T.Type) -> (imp: T, sel: Selector)? {
    let sel = NSSelectorFromString(name)
    guard let method = class_getClassMethod(cls, sel) else { return nil }
    return (unsafeBitCast(method_getImplementation(method), to: T.self), sel)
  }

  private static func instanceMethod<T>(_ cls: AnyClass, _ name: String, as _: T.Type) -> (imp: T, sel: Selector)? {
    let sel = NSSelectorFromString(name)
    guard let method = class_getInstanceMethod(cls, sel) else { return nil }
    return (unsafeBitCast(method_getImplementation(method), to: T.self), sel)
  }

  // MARK: - Hinge (UIHingeInteraction, iOS 27.1)

  static var hasHingeAPI: Bool { NSClassFromString("UIHingeInteraction") != nil }

  /// A `UIHingeInteraction` whose handler receives `(status, angleRadians)`, or `nil` for both when the
  /// interaction left a hierarchy that provides hinge updates.
  static func makeHingeInteraction(_ onUpdate: @escaping (_ status: Int?, _ angle: Double?) -> Void) -> UIInteraction? {
    guard let cls = NSClassFromString("UIHingeInteraction"),
          let alloc = classMethod(cls, "alloc", as: ClassGetter.self),
          let initializer = instanceMethod(cls, "initWithUpdateHandler:", as: InitWithBlock.self),
          let allocated = alloc.imp(cls, alloc.sel)
    else { return nil }
    let handler: @convention(block) (AnyObject, AnyObject) -> Void = { _, update in
      guard let hinge = (update as? NSObject)?.value(forKey: "hinge") as? NSObject else { return onUpdate(nil, nil) }
      onUpdate((hinge.value(forKey: "status") as? NSNumber)?.intValue, (hinge.value(forKey: "angle") as? NSNumber)?.doubleValue)
    }
    // `init` consumes the +1 from `alloc` and returns its own +1, hence unretained in, retained out.
    let created = initializer.imp(allocated.takeUnretainedValue(), initializer.sel, unsafeBitCast(handler, to: AnyObject.self))
    return created?.takeRetainedValue() as? UIInteraction
  }

  static func setEnabled(_ enabled: Bool, on interaction: UIInteraction) {
    guard let object = interaction as? NSObject, object.responds(to: NSSelectorFromString("setEnabled:")) else { return }
    object.setValue(enabled, forKey: "enabled")
  }

  // MARK: - Reserved regions (UIView.ReservedRegion, iOS 27.1)

  enum RegionKind: String {
    case division
    case occlusion
  }

  struct RawRegion: Equatable {
    let kind: RegionKind
    let frame: CGRect
    let margins: UIEdgeInsets
    let isActive: Bool
  }

  /// Regions of `kind` overlapping `view`, in its coordinates, inactive ones included.
  static func reservedRegions(of kind: RegionKind, in view: UIView) -> [RawRegion] {
    guard let kindClass = NSClassFromString("UIViewReservedRegionKind"),
          let getter = classMethod(kindClass, "\(kind.rawValue)RegionKind", as: ClassGetter.self),
          let kindObject = getter.imp(kindClass, getter.sel)?.takeUnretainedValue(),
          let query = instanceMethod(UIView.self, "reservedRegionsOfKind:options:", as: ViewRegionsGetter.self),
          let regions = query.imp(view, query.sel, kindObject, 1 /* includeInactive */)?.takeUnretainedValue()
    else { return [] }
    return regions.compactMap { item in
      guard let region = item as? NSObject, let frame = (region.value(forKey: "frame") as? NSValue)?.cgRectValue else { return nil }
      return RawRegion(
        kind: kind,
        frame: frame,
        margins: (region.value(forKey: "margins") as? NSValue)?.uiEdgeInsetsValue ?? .zero,
        // KVC finds the `isActive` getter. An unreadable flag reads inactive: a 40pt inactive fold has a real frame.
        isActive: (region.value(forKey: "active") as? NSNumber)?.boolValue ?? false)
    }
  }

  // MARK: - Vertical bar (iOS 27.1 / 27.2)

  /// `UITraitCollection.verticalBarEdge`: 0 unspecified, 1 leading, 2 trailing. `nil` when the OS has no such trait.
  static func verticalBarEdge(_ traits: UITraitCollection) -> Int? {
    guard traits.responds(to: NSSelectorFromString("verticalBarEdge")) else { return nil }
    return (traits.value(forKey: "verticalBarEdge") as? NSNumber)?.intValue
  }

  /// `UITraitCollection.systemTraitsAffectingVerticalBarEdge`, for trait-change registration.
  static var traitsAffectingVerticalBarEdge: [AnyObject] {
    guard let getter = classMethod(UITraitCollection.self, "systemTraitsAffectingVerticalBarEdge", as: ClassGetter.self) else { return [] }
    return (getter.imp(UITraitCollection.self, getter.sel)?.takeUnretainedValue() as? [AnyObject]) ?? []
  }

  /// `UIViewLayoutRegion` for a bar on a directional edge: the system extent (iOS 27.2) when `extent` is nil, else `extent`.
  static func barRegion(on edge: NSDirectionalRectEdge, extent: CGFloat?) -> AnyObject? {
    guard let cls = NSClassFromString("UIViewLayoutRegion") else { return nil }
    if let extent {
      guard let factory = classMethod(cls, "layoutRegionForBarOnDirectionalEdge:extent:", as: ClassUIntFloatGetter.self) else { return nil }
      return factory.imp(cls, factory.sel, edge.rawValue, extent)?.takeUnretainedValue()
    }
    guard let factory = classMethod(cls, "layoutRegionForBarOnDirectionalEdge:", as: ClassUIntGetter.self) else { return nil }
    return factory.imp(cls, factory.sel, edge.rawValue)?.takeUnretainedValue()
  }

  /// `-[UIView layoutGuideForLayoutRegion:]` (iOS 26).
  static func layoutGuide(for region: AnyObject, in view: UIView) -> UILayoutGuide? {
    guard let getter = instanceMethod(UIView.self, "layoutGuideForLayoutRegion:", as: ViewObjectGetter.self) else { return nil }
    return getter.imp(view, getter.sel, region)?.takeUnretainedValue() as? UILayoutGuide
  }

  // MARK: - Vertical bar behavior (UIViewController, iOS 27.1)

  private static var behaviorKey: UInt8 = 0
  private static var overriddenClasses = Set<ObjectIdentifier>()

  /// Makes `controller`'s class answer `preferredVerticalBarBehavior` from per-instance state set by
  /// `setVerticalBarBehavior`. Returns false when the OS has no such property, or when the class implements it itself
  /// (an app subclass, or a future engine), in which case that implementation is left alone.
  @discardableResult
  static func installVerticalBarBehaviorOverride(on controller: UIViewController) -> Bool {
    let selector = NSSelectorFromString("preferredVerticalBarBehavior")
    guard controller.responds(to: selector) else { return false }
    let cls: AnyClass = type(of: controller)
    if overriddenClasses.contains(ObjectIdentifier(cls)) { return true }
    let getter: @convention(block) (AnyObject) -> Int = { object in
      (objc_getAssociatedObject(object, &behaviorKey) as? NSNumber)?.intValue ?? 0
    }
    // class_addMethod never replaces a method the class defines itself, only overrides the inherited one.
    guard class_addMethod(cls, selector, imp_implementationWithBlock(getter), "q@:") else { return false }
    overriddenClasses.insert(ObjectIdentifier(cls))
    return true
  }

  /// 0 automatic, 1 disabled. Asks UIKit to re-resolve the vertical bar, which animates the status bar and safe area.
  static func setVerticalBarBehavior(_ behavior: Int, on controller: UIViewController) {
    objc_setAssociatedObject(controller, &behaviorKey, NSNumber(value: behavior), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    let update = NSSelectorFromString("setNeedsUpdateOfVerticalBarConfiguration")
    if controller.responds(to: update) { controller.perform(update) }
  }
}
