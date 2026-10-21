// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ToDoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ToDoCore", targets: ["ToDoCore"]),
    ],
    targets: [
        .target(name: "ToDoCore"),
        .testTarget(name: "ToDoCoreTests", dependencies: ["ToDoCore"]),
    ]
)
