// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Instra",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "Instra",
            targets: ["Instra"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Instra",
            path: "Sources/Instra"
        ),
    ]
)
