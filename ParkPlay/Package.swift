// swift-tools-version:5.9
// Yalnızca çekirdek kodu (ayrıştırıcılar, istemciler) Xcode olmadan test etmek için.
// Uygulamayı derlemek için ParkPlay.xcodeproj dosyasını açın.
import PackageDescription

let package = Package(
    name: "ParkPlayCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "ParkPlayCore", path: "App/Core"),
        .testTarget(name: "ParkPlayCoreTests", dependencies: ["ParkPlayCore"], path: "Tests"),
    ]
)
