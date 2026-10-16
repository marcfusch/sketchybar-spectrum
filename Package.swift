// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SketchySpectrum",
    platforms: [.macOS("14.2")],
    targets: [
        .executableTarget(
            name: "SketchySpectrum",
            path: "Sources/SketchySpectrum"
        ),
    ]
)
