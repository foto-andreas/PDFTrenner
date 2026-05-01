// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PDFTrennerSwift",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PDFTrennerSwift",
            path: "PDFTrennerSwift",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)