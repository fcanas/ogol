// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LogoLang",
    products: [
        .library( name: "LogoLang", targets: ["LogoLang"]),
        .executable(name: "logo", targets: ["logo"]),
        .executable(name: "clogo", targets: ["clogo"])
    ],
    dependencies: [
        .package(url: "https://github.com/fcanas/FFCParserCombinator.git", .branch("substring")),
    ],
    targets: [
        .target(
            name: "LogoLang",
            dependencies: ["FFCParserCombinator"]),
        .testTarget(
            name: "LogoLangTests",
            dependencies: ["LogoLang"]),
        .target(name: "libLogo", dependencies: ["LogoLang"]),
        .target(name: "logo", dependencies: ["LogoLang", "libLogo"]),
        .target(name: "clogo", dependencies: ["LogoLang"])
    ]
)
