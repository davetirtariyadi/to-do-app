// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Todo",
    platforms: [.macOS(.v14)],
    targets: [
        // Model, persistence and date logic — no UI, so it can be unit tested.
        .target(name: "TodoCore", path: "Sources/TodoCore"),
        // The menu bar app and floating window.
        .executableTarget(name: "Todo", dependencies: ["TodoCore"], path: "Sources/Todo"),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore"], path: "Tests/TodoCoreTests"),
    ]
)
