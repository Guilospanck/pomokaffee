// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pomokaffee",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Pomokaffee", path: "Sources/Pomokaffee")
    ]
)
