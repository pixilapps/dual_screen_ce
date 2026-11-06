// Copyright (c) 2026 Pixil Apps. Licensed under the MIT License.

import Flutter
import UIKit

/// iPhone Duo support: hinge status and angle, reserved regions, size classes and the vertical bar, bridged to Dart.
///
/// Observation runs only while Dart listens to `display_state` or `hinge_angle` (or waits on `hasHingeAngleSensor`), on
/// this engine's own Flutter view. Devices without the iOS 27.1 hinge API, or without a hinge, get no probe at all.
public final class DualScreenCePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private weak var registrar: FlutterPluginRegistrar?
  private var probe: DisplayProbeView?
  private var hinge: UIInteraction?
  private var hasHinge: Bool?
  private var hingeStatus = 0
  private var hingeAngle: Double?
  private var barBehavior = 0

  private var displaySink: FlutterEventSink?
  private var angleSink: FlutterEventSink?
  private var pendingHingeQueries: [FlutterResult] = []
  private var lastState: DisplayState?
  private var lastAngle: Double?
  private var emitScheduled = false
  private var attachRetries = 0

  // ponytail: the Duo reports its hinge on the first update after attach. Raise this if a cold start measures slower.
  private static let hingeQueryTimeout: TimeInterval = 1.5
  /// Upper bound when no scene ever shows a Flutter view (a headless engine).
  private static let hingeQueryCap: TimeInterval = 5
  private var hingeQueryTimeoutArmed = false

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = DualScreenCePlugin(registrar: registrar)
    let messenger = registrar.messenger()
    registrar.addMethodCallDelegate(plugin, channel: FlutterMethodChannel(name: "dual_screen_ce/hinge_info", binaryMessenger: messenger))
    registrar.addMethodCallDelegate(plugin, channel: FlutterMethodChannel(name: "dual_screen_ce/vertical_bar", binaryMessenger: messenger))
    FlutterEventChannel(name: "dual_screen_ce/display_state", binaryMessenger: messenger)
      .setStreamHandler(StreamHandler { [weak plugin] sink in plugin?.setDisplaySink(sink) })
    FlutterEventChannel(name: "dual_screen_ce/hinge_angle", binaryMessenger: messenger)
      .setStreamHandler(StreamHandler { [weak plugin] sink in plugin?.setAngleSink(sink) })
    registrar.addSceneDelegate(plugin)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    displaySink = nil
    angleSink = nil
    resolveHingeQueries()
    detach()
  }

  // MARK: - Scene lifecycle

  public func sceneWillEnterForeground(_ scene: UIScene) { reapplyBehavior(); refreshAttachment() }

  public func sceneDidBecomeActive(_ scene: UIScene) { reapplyBehavior(); refreshAttachment() }

  public func sceneDidDisconnect(_ scene: UIScene) { detach() }

  // MARK: - Methods

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasHingeAngleSensor":
      if let hasHinge { return result(hasHinge) }
      guard DuoRuntime.hasHingeAPI else { return result(false) }
      pendingHingeQueries.append(result)
      refreshAttachment()
      armHingeQueryTimeout()
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.hingeQueryCap) { [weak self] in self?.resolveHingeQueries() }
    case "setPreferredVerticalBarBehavior":
      let disabled = (call.arguments as? String) == "disabled"
      result(setVerticalBarBehavior(disabled ? 1 : 0))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// A behavior set before the view controller existed applies as soon as it does, listened to or not.
  private func reapplyBehavior() {
    guard barBehavior != 0, let controller = registrar?.viewController, DuoRuntime.installVerticalBarBehaviorOverride(on: controller) else { return }
    DuoRuntime.setVerticalBarBehavior(barBehavior, on: controller)
  }

  private func setVerticalBarBehavior(_ behavior: Int) -> Bool {
    barBehavior = behavior // kept, and re-applied on attach if the view controller is not there yet
    guard let controller = registrar?.viewController, DuoRuntime.installVerticalBarBehaviorOverride(on: controller) else { return false }
    DuoRuntime.setVerticalBarBehavior(behavior, on: controller)
    scheduleEmit()
    return true
  }

  // MARK: - Streams

  private func setDisplaySink(_ sink: FlutterEventSink?) {
    displaySink = sink
    lastState = nil // a new listener gets the current state right away
    refreshAttachment()
    scheduleEmit()
  }

  private func setAngleSink(_ sink: FlutterEventSink?) {
    // Without a hinge the stream is empty: it ends at once, as on Android and in 1.0.0.
    if let sink, !DuoRuntime.hasHingeAPI || hasHinge == false {
      sink(FlutterEndOfEventStream)
      return
    }
    angleSink = sink
    lastAngle = nil
    refreshAttachment()
    emitAngle()
  }

  /// No hinge after all: answers the queries, sends the last state, ends the angle stream and stops observing.
  private func settleWithoutHinge() {
    hasHinge = false
    resolveHingeQueries()
    emitNow()
    angleSink?(FlutterEndOfEventStream)
    angleSink = nil
    detach()
  }

  private var wantsObservation: Bool { displaySink != nil || angleSink != nil || !pendingHingeQueries.isEmpty }

  // MARK: - Attachment

  private func refreshAttachment() {
    wantsObservation ? attach() : detach()
  }

  private func attach() {
    guard DuoRuntime.hasHingeAPI, hasHinge != false else { return }
    guard let host = registrar?.viewController?.view else { return retryAttach() }
    attachRetries = 0
    let probe = self.probe ?? DisplayProbeView(frame: host.bounds)
    if probe.superview !== host {
      probe.frame = host.bounds
      host.insertSubview(probe, at: 0)
      probe.onChange = { [weak self] in
        self?.armHingeQueryTimeout() // the view may reach its window after attach
        self?.scheduleEmit()
      }
      self.probe = probe
    }
    if hinge == nil, let interaction = DuoRuntime.makeHingeInteraction({ [weak self] status, angle in self?.hingeUpdated(status, angle) }) {
      probe.addInteraction(interaction)
      hinge = interaction
    }
    armHingeQueryTimeout()
    // A behavior set before the view existed, or for a view controller that has since been replaced.
    if barBehavior != 0, let controller = registrar?.viewController, DuoRuntime.installVerticalBarBehaviorOverride(on: controller) {
      DuoRuntime.setVerticalBarBehavior(barBehavior, on: controller)
    }
    scheduleEmit()
  }

  /// Starts the hinge wait once the probe is on screen (at boot the scene may connect well after `main()` asks). A device
  /// with a hinge reports within milliseconds; one without never calls back, so silence settles "no hinge".
  private func armHingeQueryTimeout() {
    guard hasHinge == nil, !hingeQueryTimeoutArmed, probe?.window != nil else { return }
    hingeQueryTimeoutArmed = true
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.hingeQueryTimeout) { [weak self] in
      guard let self else { return }
      self.hingeQueryTimeoutArmed = false
      if self.hasHinge == nil, self.probe?.window != nil { self.settleWithoutHinge() } else { self.resolveHingeQueries() }
    }
  }

  /// The view controller is nil until the scene connects; the scene delegate re-attaches too.
  private func retryAttach() {
    guard attachRetries < 40 else { return }
    attachRetries += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      guard let self, self.wantsObservation, self.probe == nil else { return }
      self.attach()
    }
  }

  private func detach() {
    if let hinge, let probe { probe.removeInteraction(hinge) }
    hinge = nil
    probe?.onChange = nil
    probe?.removeFromSuperview()
    probe = nil
    lastState = nil
    lastAngle = nil
  }

  // MARK: - Hinge

  private func hingeUpdated(_ status: Int?, _ angleRadians: Double?) {
    guard let status else {
      // nil arrives when the interaction leaves a hierarchy that provides hinge updates, including on a Duo while it is
      // being removed, so it settles "no hinge" only before any hinge was seen.
      guard probe?.window != nil, hasHinge == nil else { return }
      settleWithoutHinge()
      return
    }
    hasHinge = true
    hingeStatus = status
    hingeAngle = angleRadians.map { min(max($0 * 180 / .pi, 0), 180) }
    resolveHingeQueries()
    emitAngle()
    scheduleEmit()
  }

  private func resolveHingeQueries() {
    let queries = pendingHingeQueries
    pendingHingeQueries = []
    queries.forEach { $0(hasHinge ?? false) }
    if !wantsObservation { detach() }
  }

  private func emitAngle() {
    guard let sink = angleSink, let angle = hingeAngle, angle != lastAngle else { return }
    lastAngle = angle
    sink(angle)
  }

  // MARK: - Display state

  private func scheduleEmit() {
    guard displaySink != nil, !emitScheduled else { return }
    emitScheduled = true
    // One snapshot per run-loop turn, however many layout, trait and hinge callbacks fired in it.
    DispatchQueue.main.async { [weak self] in
      self?.emitScheduled = false
      self?.emitNow()
    }
  }

  private func emitNow() {
    guard let sink = displaySink else { return }
    let state = currentState()
    guard state != lastState else { return }
    lastState = state
    sink(state.toMap())
  }

  private func currentState() -> DisplayState {
    let view: UIView? = probe ?? registrar?.viewController?.view
    let traits = view?.traitCollection ?? UITraitCollection.current
    let isRightToLeft = view?.effectiveUserInterfaceLayoutDirection == .rightToLeft
    let edge = DuoRuntime.verticalBarEdge(traits) ?? 0
    var barRect: CGRect?
    if let probe, edge != 0, let side = DisplayState.side(ofEdge: edge, isRightToLeft: isRightToLeft) {
      let inset = side == "left" ? probe.safeAreaInsets.left : probe.safeAreaInsets.right
      barRect = probe.barFrame(on: edge == 1 ? .leading : .trailing, fallbackExtent: inset)
      if barRect?.isEmpty ?? true, inset > 0 {
        // ponytail: no bar region API (or not laid out yet): the side inset, full height. Replaced on the next layout.
        let bounds = probe.bounds
        barRect = CGRect(x: side == "left" ? 0 : bounds.width - inset, y: 0, width: inset, height: bounds.height)
      }
    }
    return DisplayState(
      hasHinge: DuoRuntime.hasHingeAPI ? hasHinge : false,
      hingeStatus: hingeStatus,
      regions: probe.map { DuoRuntime.reservedRegions(of: .division, in: $0) + DuoRuntime.reservedRegions(of: .occlusion, in: $0) } ?? [],
      horizontalSizeClass: traits.horizontalSizeClass,
      verticalSizeClass: traits.verticalSizeClass,
      barEdge: edge,
      isRightToLeft: isRightToLeft,
      barRect: barRect,
      barEnabled: barBehavior == 0)
  }
}

/// A `FlutterStreamHandler` that forwards listen (sink) and cancel (nil) to one closure.
private final class StreamHandler: NSObject, FlutterStreamHandler {
  private let onSink: (FlutterEventSink?) -> Void

  init(_ onSink: @escaping (FlutterEventSink?) -> Void) {
    self.onSink = onSink
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onSink(nil)
    return nil
  }
}
