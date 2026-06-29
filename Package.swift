// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Opus2Wav",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Opus2Wav", targets: ["Opus2Wav"])
    ],
    targets: [
        .executableTarget(
            name: "Opus2Wav",
            path: "Sources/Opus2Wav",
            exclude: [
                "Resources/ffmpeg.README.md"
            ]
        ),
        .testTarget(
            name: "Opus2WavTests",
            dependencies: ["Opus2Wav"],
            path: "Tests/Opus2WavTests"
        )
    ]
)
