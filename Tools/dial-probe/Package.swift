// swift-tools-version:5.10
import PackageDescription

// The embedded Info.plist gives the binary a bundle id, so MediaRemote can
// name it as the Now Playing app and TCC prompts are easier to read.
let infoPlist = Context.packageDirectory + "/Support/Info.plist"

let package = Package(
    name: "dial-probe",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "dial-probe",
            path: "Sources/dial-probe",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", infoPlist,
                ]),
            ]
        ),
    ]
)
