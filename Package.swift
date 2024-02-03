// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "REPLACE",
  platforms: [
    .iOS(.v16), .macOS(.v12), .macCatalyst(.v13),
  ],
  products: [
    .library(
      name: "REPLACE",
      targets: ["REPLACE"]
    ),
  ],
  targets: [
    .target(
      name: "REPLACE",
      path: "REPLACE",
      exclude: [],
      swiftSettings: []
    ),
    .testTarget(
      name: "REPLACE_TESTS",
      dependencies: ["REPLACE"],
      path: "REPLACE_TESTS"
    ),
  ]
)

