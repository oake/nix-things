// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AdrafinilNix",
    platforms: [.macOS("26.4")],
    products: [
        .executable(name: "Adrafinil", targets: ["Adrafinil"]),
        .executable(name: "AdrafinilDaemon", targets: ["AdrafinilDaemon"]),
        .executable(name: "AdrafinilHelper", targets: ["AdrafinilHelper"]),
        .executable(name: "AdrafinilCLI", targets: ["AdrafinilCLI"]),
    ],
    dependencies: [.package(path: "Propofol")],
    targets: [
        .target(name: "AdrafinilShared", path: "AdrafinilShared/Sources/AdrafinilShared"),
        .executableTarget(
            name: "Adrafinil",
            dependencies: ["AdrafinilShared", .product(name: "Propofol", package: "Propofol")],
            path: "Adrafinil",
            exclude: ["Adrafinil.entitlements", "Adrafinil.icon", "Assets.xcassets", "Localizable.xcstrings"]
        ),
        .executableTarget(name: "AdrafinilDaemon", dependencies: ["AdrafinilShared"], path: "AdrafinilDaemon", exclude: ["Info.plist", "LaunchAgent.plist"]),
        .executableTarget(name: "AdrafinilHelper", dependencies: ["AdrafinilShared"], path: "AdrafinilHelper", exclude: ["Info.plist", "LaunchDaemon.plist"]),
        .executableTarget(name: "AdrafinilCLI", dependencies: ["AdrafinilShared"], path: "AdrafinilCLI"),
    ],
    swiftLanguageModes: [.v6]
)
