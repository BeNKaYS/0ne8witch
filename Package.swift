// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "0ne8witch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "0ne8witch", targets: ["0ne8witch"])
    ],
    targets: [
        .executableTarget(
            name: "0ne8witch",
            path: "Sources/OneSwitch",
            exclude: ["Resources"]
        )
    ]
)
