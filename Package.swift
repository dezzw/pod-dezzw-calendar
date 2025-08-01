// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "pod-dezzw-calendar",
  platforms: [
    .macOS(.v13)  // Minimum macOS version
  ],
  products: [
    .executable(name: "pod-dezzw-calendar", targets: ["pod-dezzw-calendar"])
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "pod-dezzw-calendar"
    ),
    .testTarget(
      name: "CalendarPodTests",
      dependencies: ["pod-dezzw-calendar"]
    ),
  ]
)
