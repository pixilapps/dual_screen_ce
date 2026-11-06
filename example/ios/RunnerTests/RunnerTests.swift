import Flutter
import UIKit
import XCTest

@testable import dual_screen_ce

/// A stand-in for an app's FlutterViewController: the override goes on a subclass, never on UIViewController itself.
private final class HostController: UIViewController {}

/// Unit tests for the parts of the iOS layer that do not need an iPhone Duo. The pose behaviour itself is recorded on
/// the Duo simulator in doc/iphone_duo_matrix.md.
class RunnerTests: XCTestCase {
  private func state(edge: Int = 2, rtl: Bool = false, status: Int = 3, bar: CGRect? = CGRect(x: 879, y: 124, width: 48, height: 511)) -> DisplayState {
    DisplayState(
      hasHinge: true,
      hingeStatus: status,
      regions: [DuoRuntime.RawRegion(kind: .division, frame: CGRect(x: 455.5, y: 0, width: 40, height: 669), margins: UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20), isActive: false)],
      horizontalSizeClass: .regular,
      verticalSizeClass: .regular,
      barEdge: edge,
      isRightToLeft: rtl,
      barRect: bar,
      barEnabled: true)
  }

  func testEdgeResolvesToThePhysicalSide() {
    XCTAssertEqual(DisplayState.side(ofEdge: 2, isRightToLeft: false), "right")
    XCTAssertEqual(DisplayState.side(ofEdge: 1, isRightToLeft: false), "left")
    // The bar stays on the hardware's right in right-to-left layouts, which UIKit reports as the leading edge.
    XCTAssertEqual(DisplayState.side(ofEdge: 1, isRightToLeft: true), "right")
    XCTAssertEqual(DisplayState.side(ofEdge: 2, isRightToLeft: true), "left")
    XCTAssertNil(DisplayState.side(ofEdge: 0, isRightToLeft: false))
  }

  func testPostureFollowsTheHingeStatus() {
    XCTAssertEqual(state(status: 0).posture, "unknown")
    XCTAssertEqual(state(status: 1).posture, "closed")
    XCTAssertEqual(state(status: 2).posture, "halfOpened")
    XCTAssertEqual(state(status: 3).posture, "flat")
  }

  func testEncodesTheWireFormatDartDecodes() {
    let map = state().toMap()
    XCTAssertEqual(map["posture"] as? String, "flat")
    XCTAssertEqual(map["horizontalSizeClass"] as? String, "regular")
    let bar = map["verticalBar"] as? [String: Any]
    XCTAssertEqual(bar?["side"] as? String, "right")
    XCTAssertEqual(bar?["edge"] as? String, "trailing")
    XCTAssertEqual(bar?["rect"] as? [Double], [879, 124, 48, 511])
    let region = (map["regions"] as? [[String: Any]])?.first
    XCTAssertEqual(region?["kind"] as? String, "division")
    XCTAssertEqual(region?["margins"] as? [Double], [20, 0, 20, 0])
    XCTAssertEqual(region?["isActive"] as? Bool, false)
  }

  func testNoVerticalBarWithoutAnEdgeOrARect() {
    XCTAssertTrue(state(edge: 0).toMap()["verticalBar"] is NSNull)
    XCTAssertTrue(state(bar: nil).toMap()["verticalBar"] is NSNull)
  }

  func testEqualSnapshotsAreNotResent() {
    XCTAssertEqual(state(), state())
    XCTAssertNotEqual(state(), state(status: 2))
  }

  func testTheBehaviorOverrideInstallsOncePerClassAndReadsPerInstance() {
    let controller = HostController()
    let selector = NSSelectorFromString("preferredVerticalBarBehavior")
    guard controller.responds(to: selector) else {
      // Runtimes before iOS 27.1 have no vertical bar: the override must refuse to install.
      return XCTAssertFalse(DuoRuntime.installVerticalBarBehaviorOverride(on: controller))
    }
    XCTAssertTrue(DuoRuntime.installVerticalBarBehaviorOverride(on: controller))
    XCTAssertTrue(DuoRuntime.installVerticalBarBehaviorOverride(on: controller), "a second install is a no-op that still reports success")
    DuoRuntime.setVerticalBarBehavior(1, on: controller)
    XCTAssertEqual((controller.value(forKey: "preferredVerticalBarBehavior") as? NSNumber)?.intValue, 1)
    XCTAssertEqual((HostController().value(forKey: "preferredVerticalBarBehavior") as? NSNumber)?.intValue, 0, "other instances keep automatic")
    XCTAssertFalse(DuoRuntime.installVerticalBarBehaviorOverride(on: UIViewController()), "UIViewController implements it itself, so it is left alone")
  }

  /// A guarded read returns nil for a key the object does not have, where `value(forKey:)` would raise.
  private final class Region: NSObject {
    @objc var frame = CGRect(x: 1, y: 2, width: 3, height: 4)
    @objc(isActive) var active = true
  }

  func testGuardedReadsReturnNilForMissingKeysAndFindFlagGetters() {
    let region = Region()
    XCTAssertEqual((DuoRuntime.read("frame", of: region) as? NSValue)?.cgRectValue, CGRect(x: 1, y: 2, width: 3, height: 4))
    XCTAssertEqual((DuoRuntime.read("active", of: region) as? NSNumber)?.boolValue, true)
    XCTAssertNil(DuoRuntime.read("renamedInALaterRelease", of: region))
  }
}
