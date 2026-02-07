// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeTokenCat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeTokenCat",
            path: "ClaudeTokenCat/Sources",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "ClaudeTokenCat/Info.plist"])
            ]
        ),
    ]
)
