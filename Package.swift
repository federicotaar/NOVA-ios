// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NOVA",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NOVA", targets: ["NOVA"]),
        .library(name: "NOVAWidget", targets: ["NOVAWidget"])
    ],
    targets: [
        .target(name: "NOVA", resources: [.copy("nova.html")]),
        .target(name: "NOVAWidget")
    ],
    swiftLanguageModes: [.v5]
)
