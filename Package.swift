// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuTimer",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "MenuTimerKit",
            targets: ["MenuTimerKit"]
        ),
    ],
    targets: [
        .target(
            name: "MenuTimerKit",
            path: "Sources/MenuTimerKit",
            // Sin esto los .wav no viajan con el paquete y las alarmas suenan
            // en la app standalone pero no en quien la consuma como módulo.
            resources: [.process("Resources")]
        ),
    ]
)