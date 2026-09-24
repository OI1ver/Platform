import Foundation
import Sparkle

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var isConfigured: Bool

    private let controller: SPUStandardUpdaterController
    private var hasStarted = false

    init(bundle: Bundle = .main) {
        let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        isConfigured = feed.hasPrefix("https://")
            && !feed.contains("OWNER")
            && !key.contains("REPLACE")
            && !key.isEmpty
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func start(automaticallyChecks: Bool) {
        guard isConfigured else { return }
        if !hasStarted {
            controller.startUpdater()
            hasStarted = true
        }
        controller.updater.automaticallyChecksForUpdates = automaticallyChecks
    }

    func checkForUpdates() {
        guard isConfigured else { return }
        start(automaticallyChecks: controller.updater.automaticallyChecksForUpdates)
        controller.checkForUpdates(nil)
    }
}
