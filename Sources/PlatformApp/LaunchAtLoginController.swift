import AppKit
import ServiceManagement

protocol LoginItemServiceProviding: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemServiceProviding {}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    enum State: Equatable {
        case disabled
        case enabled
        case requiresApproval
        case unavailable
    }

    @Published private(set) var state: State = .disabled
    @Published private(set) var errorMessage: String?

    private let service: any LoginItemServiceProviding

    var isRequested: Bool {
        state == .enabled || state == .requiresApproval
    }

    init(service: any LoginItemServiceProviding = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        switch service.status {
        case .enabled:
            state = .enabled
        case .requiresApproval:
            state = .requiresApproval
        case .notRegistered:
            state = .disabled
        case .notFound:
            state = .unavailable
        @unknown default:
            state = .unavailable
        }
    }

    func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
