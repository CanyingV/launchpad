// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Launchpad",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Launchpad", targets: ["Launchpad"])],
    targets: [.executableTarget(name: "Launchpad", path: "Sources/Launchpad")]
)
