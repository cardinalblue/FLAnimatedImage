// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FLAnimatedImage",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "FLAnimatedImage",
            targets: ["FLAnimatedImage"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode", from: "1.3.2")
    ],
    targets: [
        .target(
            name: "FLAnimatedImage",
            dependencies: [
                .product(name: "libwebp", package: "libwebp-xcode")
            ],
            path: "FLAnimatedImage",
            exclude: [ "Info.plist" ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ]
        )
    ]
)
