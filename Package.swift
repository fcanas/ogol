// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LogoLang",
    products: [
        .library( name: "LogoLang", targets: ["LogoLang"]),
        .library( name: "libLogo", targets: ["libLogo"]),
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
            dependencies: ["LogoLang", "libLogo"]),
        .target(name: "libLogo", dependencies: ["LogoLang"], resources: [.copy("CoreLib.logo")]),
        .target(name: "logo", dependencies: ["LogoLang", "libLogo"]),
        .target(name: "clogo", dependencies: ["LogoLang"])
    ]
)
