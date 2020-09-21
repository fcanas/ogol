// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ogol",
    products: [
        .library( name: "OgoLang", targets: ["OgoLang"]),
        .library( name: "LogoLang", targets: ["LogoLang"]),
        .library( name: "libOgol", targets: ["libOgol"]),
        .library(name: "ToolingSupport", targets: ["ToolingSupport"]),
        .executable(name: "ogol", targets: ["ogol"]),
        .executable(name: "logo", targets: ["logo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/fcanas/FFCParserCombinator.git", .branch("substring")),
    ],
    targets: [
        .target(name: "Execution"),
        .target(name: "libOgol", dependencies: ["OgoLang", "ToolingSupport"], resources: [.copy("CoreLib.ogol")]),
        .target(name: "ogol", dependencies: ["OgoLang", "libOgol", "ToolingSupport"]),
        .target(name: "logo", dependencies: ["LogoLang", "libOgol", "Execution", "ToolingSupport"]),
        .target(name: "OgoLang", dependencies: ["FFCParserCombinator", "Execution", "ToolingSupport"]),
        .target(name: "LogoLang", dependencies: ["FFCParserCombinator", "Execution", "ToolingSupport"]),
        .target(name: "ToolingSupport", dependencies: ["Execution"]),
        .testTarget(name: "LogoLangTests", dependencies: ["LogoLang", "libOgol", "Execution"]),
    ]
)
