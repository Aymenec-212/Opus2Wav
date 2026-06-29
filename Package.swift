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
            // The Resources directory holds only the docs placeholder and the
            // (gitignored) static ffmpeg binary fetched by scripts/fetch-ffmpeg.sh.
            // Neither is a SwiftPM-managed resource — excluding the whole folder
            // keeps `swift build` from erroring on the unhandled binary file.
            exclude: [
                "Resources"
            ]
        ),
        .testTarget(
            name: "Opus2WavTests",
            dependencies: ["Opus2Wav"],
            path: "Tests/Opus2WavTests"
        )
    ]
)
