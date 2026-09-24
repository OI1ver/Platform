import AppKit
import SwiftUI

@main
struct PlatformApp: App {
    @StateObject private var preferences: PreferencesStore
    @StateObject private var boardStore: BoardStore
    @StateObject private var updateController: UpdateController
    private let catalog = StationCatalog.bundled

    init() {
        FontRegistrar.registerBundledFonts()
        NSApplication.shared.setActivationPolicy(.accessory)

        let preferences = PreferencesStore()
        let configuredURL = ProcessInfo.processInfo.environment["PLATFORM_API_BASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "PlatformAPIBaseURL") as? String
            ?? "http://127.0.0.1:8787"
        let baseURL = URL(string: configuredURL) ?? URL(string: "http://127.0.0.1:8787")!
        let api = RailAPIClient(
            baseURL: baseURL,
            installationID: InstallationIDProvider().value()
        )
        let updates = UpdateController()
        updates.start(automaticallyChecks: preferences.checkForUpdates)

        _preferences = StateObject(wrappedValue: preferences)
        _boardStore = StateObject(wrappedValue: BoardStore(api: api, cache: FileBoardCache()))
        _updateController = StateObject(wrappedValue: updates)
    }

    var body: some Scene {
        MenuBarExtra {
            RootPopoverView(preferences: preferences, store: boardStore, catalog: catalog)
        } label: {
            Group {
                if let image = AppArtwork.menuBarImage {
                    Image(nsImage: image)
                } else {
                    Image(systemName: "train.side.front.car")
                }
            }
            .accessibilityLabel("Platform departures")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(preferences: preferences, updates: updateController, catalog: catalog)
        }

        Window("About Platform", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
enum AppArtwork {
    static let menuBarImageSize = NSSize(width: 14, height: 18)

    static let menuBarImage: NSImage? = {
        let nested = Bundle.module.url(
            forResource: "PlatformBarIcon",
            withExtension: "png",
            subdirectory: "Artwork"
        )
        let flattened = Bundle.module.url(forResource: "PlatformBarIcon", withExtension: "png")
        guard let url = nested ?? flattened,
              let source = NSImage(contentsOf: url),
              source.size.width > 0,
              source.size.height > 0 else { return nil }

        let image = NSImage(size: menuBarImageSize, flipped: false) { bounds in
            let scale = min(
                bounds.width / source.size.width,
                bounds.height / source.size.height
            )
            let drawSize = NSSize(
                width: source.size.width * scale,
                height: source.size.height * scale
            )
            let drawRect = NSRect(
                x: bounds.midX - drawSize.width / 2,
                y: bounds.midY - drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            source.draw(
                in: drawRect,
                from: NSRect(origin: .zero, size: source.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
        image.isTemplate = true
        return image
    }()
}
