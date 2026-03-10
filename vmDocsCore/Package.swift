// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "vmDocsCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "vmDocsCore",
            targets: ["vmDocsCore"]
        ),
    ],
    dependencies: [
        // HTML Parsing
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),

        // Vector Database - SQLite with vector extension
        .package(url: "https://github.com/jkrukowski/SQLiteVec", from: "0.0.9"),

        // Markdown Rendering
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.3.0"),

        // Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "vmDocsCore",
            dependencies: [
                "SwiftSoup",
                "SQLiteVec",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources"
        ),
        // Tests are in the main project directory
    ]
)
