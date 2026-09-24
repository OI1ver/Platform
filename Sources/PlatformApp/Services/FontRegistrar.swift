import CoreText
import Foundation
import SwiftUI

enum DepartureBoardFont {
    static let mediumName = "Medium"
    static let boldName = "Bold"
    static let heavyName = "Heavy"
    static let regularName = "LondonUnderground"

    static func medium(_ size: CGFloat) -> Font { .custom(mediumName, size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom(boldName, size: size) }
    static func heavy(_ size: CGFloat) -> Font { .custom(heavyName, size: size) }
    static func regular(_ size: CGFloat) -> Font { .custom(regularName, size: size) }
}

enum FontRegistrar {
    static func registerBundledFonts() {
        let nested = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        let flattened = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []

        for url in Set(nested + flattened) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
