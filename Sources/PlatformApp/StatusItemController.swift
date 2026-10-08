import AppKit
import SwiftUI

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var selection: SettingsPage = .stations
}

enum SettingsPage: String, CaseIterable, Identifiable {
    case stations
    case general
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stations: "Stations"
        case .general: "General"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .stations: "tram.fill"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

enum StatusPanelLayout {
    static let screenMargin: CGFloat = 8
    static let verticalGap: CGFloat = 4

    static func frame(
        anchorRect: CGRect,
        panelSize: CGSize,
        visibleScreenFrame: CGRect
    ) -> CGRect {
        let minimumX = visibleScreenFrame.minX + screenMargin
        let maximumX = visibleScreenFrame.maxX - panelSize.width - screenMargin
        let preferredX = anchorRect.minX
        let x = min(max(preferredX, minimumX), max(minimumX, maximumX))

        let preferredY = anchorRect.minY - verticalGap - panelSize.height
        let minimumY = visibleScreenFrame.minY + screenMargin
        let y = max(minimumY, preferredY)

        return CGRect(origin: CGPoint(x: x, y: y), size: panelSize)
    }
}

@MainActor
final class StatusItemController: NSObject, NSApplicationDelegate {
    private var preferences: PreferencesStore?
    private var boardStore: BoardStore?
    private var catalog: StationCatalog?
    private var settingsNavigation: SettingsNavigation?

    private var statusItem: NSStatusItem?
    private var boardPanel: PlatformBoardPanel?
    private var outsideClickMonitor: Any?
    private var observers: [any NSObjectProtocol] = []
    private var didFinishLaunching = false
    private var settingsWindowWasRequested = false

    func configure(
        preferences: PreferencesStore,
        boardStore: BoardStore,
        catalog: StationCatalog,
        settingsNavigation: SettingsNavigation
    ) {
        self.preferences = preferences
        self.boardStore = boardStore
        self.catalog = catalog
        self.settingsNavigation = settingsNavigation
        if didFinishLaunching {
            installStatusItemIfNeeded()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        didFinishLaunching = true
        installStatusItemIfNeeded()
        suppressUnrequestedSettingsWindow()

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.positionBoardPanel() }
            }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        boardStore?.disappear()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        removeOutsideClickMonitor()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showBoard()
        return false
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil,
              preferences != nil,
              boardStore != nil,
              catalog != nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.image = AppArtwork.menuBarImage ?? NSImage(systemSymbolName: "train.side.front.car", accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.toolTip = "Platform departures"
        button.target = self
        button.action = #selector(handleStatusItemAction(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("Platform departures")
        statusItem = item
    }

    @objc private func handleStatusItemAction(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            hideBoard()
            showContextMenu(relativeTo: sender)
        } else {
            toggleBoard()
        }
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        let menu = makeContextMenu()
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: button.bounds.minY - 2), in: button)
    }

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem("Open Platform", action: #selector(showBoard), keyEquivalent: ""))
        menu.addItem(menuItem("Refresh Departures", action: #selector(refreshDepartures), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(menuItem("About Platform", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem("Restart Platform", action: #selector(restartApplication), keyEquivalent: ""))
        menu.addItem(menuItem("Quit Platform", action: #selector(quitApplication), keyEquivalent: "q"))
        return menu
    }

    private func menuItem(_ title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = true
        return item
    }

    private func toggleBoard() {
        if boardPanel?.isVisible == true {
            hideBoard()
        } else {
            showBoard()
        }
    }

    @objc private func showBoard() {
        guard let preferences, let boardStore, let catalog else { return }
        let panel = boardPanel ?? makeBoardPanel()
        panel.contentView = NSHostingView(
            rootView: RootPopoverView(
                preferences: preferences,
                store: boardStore,
                catalog: catalog,
                openSettingsPage: { [weak self] page in
                    self?.openSettings(page: page)
                }
            )
        )
        panel.setContentSize(initialBoardSize(preferences: preferences, store: boardStore))
        positionBoardPanel()
        boardStore.appear(
            station: preferences.activeStation,
            automaticRefresh: preferences.automaticRefresh
        )
        installOutsideClickMonitor()
        panel.orderFrontRegardless()
    }

    private func hideBoard() {
        guard let boardPanel, boardPanel.isVisible else { return }
        boardStore?.disappear()
        boardPanel.orderOut(nil)
        boardPanel.contentView = nil
        removeOutsideClickMonitor()
    }

    @objc private func refreshDepartures() {
        let wasVisible = boardPanel?.isVisible == true
        showBoard()
        if wasVisible {
            Task { [weak self] in await self?.boardStore?.refresh() }
        }
    }

    @objc private func showSettings() {
        openSettings(page: .general)
    }

    @objc private func showAbout() {
        openSettings(page: .about)
    }

    func openSettings(page: SettingsPage) {
        hideBoard()
        settingsWindowWasRequested = true
        settingsNavigation?.selection = page
        NSApp.activate(ignoringOtherApps: true)
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    private var settingsWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }
    }

    private func suppressUnrequestedSettingsWindow() {
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.hideUnrequestedSettingsWindow()
            try? await Task.sleep(for: .milliseconds(250))
            self?.hideUnrequestedSettingsWindow()
        }
    }

    private func hideUnrequestedSettingsWindow() {
        guard !settingsWindowWasRequested else { return }
        for window in NSApp.windows where window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" {
            window.orderOut(nil)
        }
    }

    @objc private func restartApplication() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            presentAlert(
                title: "Restart is unavailable",
                message: "Restart Platform from the packaged application."
            )
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            presentAlert(title: "Platform could not restart", message: error.localizedDescription)
        }
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func makeBoardPanel() -> PlatformBoardPanel {
        let panel = PlatformBoardPanel(
            contentRect: CGRect(origin: .zero, size: CGSize(width: 488, height: 150)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        boardPanel = panel

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.positionBoardPanel() }
            }
        )
        return panel
    }

    private func initialBoardSize(preferences: PreferencesStore, store: BoardStore) -> CGSize {
        if preferences.favourites.isEmpty || store.selectedDeparture != nil {
            return CGSize(width: 488, height: 610)
        }
        return CGSize(width: 488, height: preferences.boardDisplayMode.boardHeight)
    }

    private func positionBoardPanel() {
        guard let panel = boardPanel, panel.isVisible || panel.contentView != nil,
              let anchorRect = statusItemButtonFrame() else { return }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchorRect) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let frame = StatusPanelLayout.frame(
            anchorRect: anchorRect,
            panelSize: panel.frame.size,
            visibleScreenFrame: screen.visibleFrame
        )
        panel.setFrame(frame, display: true)
    }

    private func statusItemButtonFrame() -> CGRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            let pointerLocation = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                guard let self, self.shouldDismissBoard(at: pointerLocation) else { return }
                self.hideBoard()
            }
        }
    }

    private func shouldDismissBoard(at point: CGPoint) -> Bool {
        if let boardPanel {
            let interactiveWindows = [boardPanel] + (boardPanel.childWindows ?? [])
            if interactiveWindows.contains(where: { $0.frame.contains(point) }) {
                return false
            }
        }
        if statusItemButtonFrame()?.contains(point) == true {
            return false
        }
        return true
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

private final class PlatformBoardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
