// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NOVA",
    platforms: [.iOS(.v17)],
    products: [
        // xtool: un solo prodotto library = l'app principale
        .library(name: "NOVA", targets: ["NOVA"])
    ],
    targets: [
        .target(name: "NOVA", resources: [.copy("nova.html")])
    ],
    swiftLanguageModes: [.v5]
)
