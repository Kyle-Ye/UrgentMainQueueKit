// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UrgentMainQueueKit",
    products: [
        .library(name: "UrgentMainQueueKit", targets: ["UrgentMainQueueKit"]),
    ],
    targets: [
        .target(name: "UrgentMainQueueKit"),
        .testTarget(
            name: "UrgentMainQueueKitTests",
            dependencies: ["UrgentMainQueueKit"]
        ),
    ]
)
