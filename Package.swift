// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToddlerDailyTracker",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .executable(name: "ToddlerDailyTracker", targets: ["ToddlerDailyTracker"])
    ],
    targets: [
        .executableTarget(
            name: "ToddlerDailyTracker",
            path: "Sources/ToddlerDailyTracker",
            exclude: ["Features/MedicationReminder/DESIGN.md"]
        ),
        .testTarget(
            name: "ToddlerDailyTrackerTests",
            dependencies: ["ToddlerDailyTracker"],
            path: "Tests/ToddlerDailyTrackerTests"
        )
    ]
)

