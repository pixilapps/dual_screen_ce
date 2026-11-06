// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "dual_screen_ce",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "dual-screen-ce", targets: ["dual_screen_ce"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "dual_screen_ce",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    )
  ]
)
