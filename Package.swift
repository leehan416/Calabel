// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Calabel",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Calabel", targets: ["Calabel"])],
    targets: [.executableTarget(name: "Calabel", path: "Sources/Calabel")]
)
