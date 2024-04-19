// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "CombineExtensionsBooster",
  platforms: [
    .iOS(.v16), .macOS(.v12), .macCatalyst(.v13),
  ],
  products: [
    .library(
      name: "CombineExtensionsBooster",
      targets: ["CombineExtensionsBooster"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftBoosterPack/ConcurrencyBooster.git", branch: "main"),
    .package(url: "https://github.com/pointfreeco/combine-schedulers", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "CombineExtensionsBooster",
      dependencies: [
        .product(name: "ConcurrencyBooster", package: "ConcurrencyBooster")
      ],
      path: "Source",
      exclude: [],
      swiftSettings: []
    ),
    .testTarget(
      name: "CombineExtensionsBoosterTests",
      dependencies: [
        "CombineExtensionsBooster",
        .product(name: "CombineSchedulers", package: "combine-schedulers"),
      ],
      path: "SourceTests"
    ),
  ]
)

