// Copyright (c) 2026 Pixil Apps. Licensed under the MIT License.

import UIKit

/// One atomic snapshot of everything `dual_screen_ce/display_state` reports. Sent only when it differs from the last.
struct DisplayState: Equatable {
  var hasHinge: Bool?
  /// `UIHinge.Status` raw value: 0 unknown, 1 closed, 2 partially open, 3 fully open.
  var hingeStatus: Int
  var regions: [DuoRuntime.RawRegion]
  var horizontalSizeClass: UIUserInterfaceSizeClass
  var verticalSizeClass: UIUserInterfaceSizeClass
  /// `UIVerticalBarEdge` raw value: 0 unspecified, 1 leading, 2 trailing.
  var barEdge: Int
  var isRightToLeft: Bool
  var barRect: CGRect?
  var barEnabled: Bool

  var posture: String {
    switch hingeStatus {
    case 1: "closed"
    case 2: "halfOpened"
    case 3: "flat"
    default: "unknown"
    }
  }

  /// The physical side of a directional edge: leading is the left in left-to-right layouts.
  static func side(ofEdge edge: Int, isRightToLeft: Bool) -> String? {
    switch edge {
    case 1: isRightToLeft ? "right" : "left"
    case 2: isRightToLeft ? "left" : "right"
    default: nil
    }
  }

  static func sizeClassName(_ sizeClass: UIUserInterfaceSizeClass) -> String {
    switch sizeClass {
    case .compact: "compact"
    case .regular: "regular"
    default: "unspecified"
    }
  }

  static func encode(_ rect: CGRect) -> [Double] {
    [Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height)]
  }

  static func encode(_ insets: UIEdgeInsets) -> [Double] {
    [Double(insets.left), Double(insets.top), Double(insets.right), Double(insets.bottom)]
  }

  func toMap() -> [String: Any] {
    var verticalBar: Any = NSNull()
    if let barRect, let side = Self.side(ofEdge: barEdge, isRightToLeft: isRightToLeft) {
      verticalBar = [
        "edge": barEdge == 1 ? "leading" : "trailing",
        "side": side,
        "rect": Self.encode(barRect),
        "isEnabled": barEnabled,
      ] as [String: Any]
    }
    return [
      "hasHinge": hasHinge.map { $0 as Any } ?? NSNull(),
      "posture": posture,
      "regions": regions.map { region in
        [
          "kind": region.kind.rawValue,
          "rect": Self.encode(region.frame),
          "margins": Self.encode(region.margins),
          "isActive": region.isActive,
        ] as [String: Any]
      },
      "horizontalSizeClass": Self.sizeClassName(horizontalSizeClass),
      "verticalSizeClass": Self.sizeClassName(verticalSizeClass),
      "verticalBar": verticalBar,
    ]
  }
}
