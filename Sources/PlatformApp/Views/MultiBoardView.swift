import AppKit
import QuartzCore
import SwiftUI

struct BoardModeContainerView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var store: BoardStore
    let catalog: StationCatalog

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    @State private var selectorVisibility: ViewSelectorVisibility = .hidden
    @State private var isAddingStation = false

    private let boardWidth: CGFloat = 488

    var body: some View {
        ZStack(alignment: .topTrailing) {
            currentBoard
                .frame(width: boardWidth, height: preferences.boardDisplayMode.boardHeight)
                .clipped()
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .topTrailing)))

            selectorAffordance
            modeShortcutButtons
        }
        .frame(width: boardWidth, height: preferences.boardDisplayMode.boardHeight)
        .fixedSize()
        .background {
            PopoverWindowSizer(
                contentSize: CGSize(width: boardWidth, height: preferences.boardDisplayMode.boardHeight),
                animateChanges: !reduceMotion,
                transparentBackground: false
            )
        }
        .background {
            SelectorPanelBridge(
                visibility: $selectorVisibility,
                selection: $preferences.boardDisplayMode
            )
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: preferences.boardDisplayMode)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: selectorVisibility)
        .contextMenu { boardMenu }
        .sheet(isPresented: $isAddingStation) {
            StationSearchView(catalog: catalog, existing: Set(preferences.favourites)) {
                preferences.add($0)
            }
        }
        .task(id: prefetchKey) {
            let departures = store.board?.services.prefix(1) ?? ArraySlice<Departure>()
            await store.prefetchDetails(for: departures)
        }
        .onDisappear {
            selectorVisibility = .hidden
        }
    }

    @ViewBuilder
    private var currentBoard: some View {
        switch preferences.boardDisplayMode {
        case .display:
            BoardView(preferences: preferences, store: store, onSelectDeparture: openDetails)
                .id(BoardDisplayMode.display)
        case .extended:
            ExtendedBoardView(preferences: preferences, store: store, onSelectDeparture: openDetails)
                .id(BoardDisplayMode.extended)
        case .list:
            ListBoardView(preferences: preferences, store: store, onSelectDeparture: openDetails)
                .id(BoardDisplayMode.list)
        }
    }

    private var selectorAffordance: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                selectorVisibility = selectorVisibility == .expanded ? .hidden : .expanded
            }
        } label: {
            Capsule()
                .fill(Color(red: 109 / 255, green: 109 / 255, blue: 109 / 255))
                .frame(width: 4, height: 28)
                .frame(width: 12, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 12, height: 44)
        .offset(x: -boardWidth + 6, y: 53)
        .accessibilityLabel(selectorVisibility == .expanded ? "Hide view selector" : "Show view selector")
        .help(selectorVisibility == .expanded ? "Hide view selector" : "Show view selector")
    }

    private var modeShortcutButtons: some View {
        HStack(spacing: 0) {
            Button("Display view") { selectMode(.display) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Extended view") { selectMode(.extended) }
                .keyboardShortcut("2", modifiers: .command)
            Button("List view") { selectMode(.list) }
                .keyboardShortcut("3", modifiers: .command)
        }
        .frame(width: 1, height: 1)
        .opacity(0.001)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var boardMenu: some View {
        ForEach(BoardDisplayMode.allCases) { mode in
            Button {
                selectMode(mode)
            } label: {
                if preferences.boardDisplayMode == mode {
                    Label(mode.label, systemImage: "checkmark")
                } else {
                    Text(mode.label)
                }
            }
            .keyboardShortcut(KeyEquivalent(Character(String(BoardDisplayMode.allCases.firstIndex(of: mode)! + 1))), modifiers: .command)
        }
        Divider()
        ForEach(preferences.favourites) { station in
            Button {
                preferences.activeCRS = station.crs
            } label: {
                if station.crs == preferences.activeStation?.crs {
                    Label(station.name, systemImage: "checkmark")
                } else {
                    Text(station.name)
                }
            }
        }
        Button("Add station…", systemImage: "plus") { isAddingStation = true }
        Divider()
        Button("Refresh", systemImage: "arrow.clockwise") {
            Task { await store.refresh() }
        }
        .keyboardShortcut("r", modifiers: .command)
        if let departure = store.board?.services.first {
            Button("Service details…", systemImage: "list.bullet") {
                openDetails(departure)
            }
        }
        Divider()
        Button("Settings…", systemImage: "gearshape") { openSettings() }
        Button("About Platform", systemImage: "info.circle") { openWindow(id: "about") }
        Divider()
        Button("Quit Platform", systemImage: "power") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    private var prefetchKey: String {
        let ids = store.board?.services.prefix(1).map(\.id).joined(separator: "|") ?? ""
        return "\(preferences.boardDisplayMode.rawValue):\(ids)"
    }

    private func selectMode(_ mode: BoardDisplayMode) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            preferences.boardDisplayMode = mode
        }
    }

    private func openDetails(_ departure: Departure) {
        selectorVisibility = .hidden
        Task { await store.select(departure) }
    }

}

enum ViewSelectorVisibility: Equatable {
    case hidden
    case expanded
}

enum SelectorPanelConfiguration {
    static let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
}

struct SelectorUpdateGate {
    private(set) var generation = 0

    mutating func advance() -> Int {
        generation += 1
        return generation
    }

    func accepts(_ candidate: Int) -> Bool {
        candidate == generation
    }
}

private struct SelectorPanelBridge: NSViewRepresentable {
    @Binding var visibility: ViewSelectorVisibility
    @Binding var selection: BoardDisplayMode

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.scheduleUpdate(
            from: view,
            visibility: $visibility,
            selection: $selection
        )
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.scheduleUpdate(
            from: nsView,
            visibility: $visibility,
            selection: $selection
        )
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.invalidateAndDismiss()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var parentWindow: NSWindow?
        private var panel: NSPanel?
        private var observers: [any NSObjectProtocol] = []
        private let animationDuration: TimeInterval = 0.18
        private var updateGate = SelectorUpdateGate()
        private var animationGeneration = 0
        private var visibility: Binding<ViewSelectorVisibility>?

        func scheduleUpdate(
            from hostView: NSView,
            visibility: Binding<ViewSelectorVisibility>,
            selection: Binding<BoardDisplayMode>
        ) {
            let generation = updateGate.advance()
            DispatchQueue.main.async { [weak self, weak hostView] in
                guard let self, self.updateGate.accepts(generation) else { return }
                self.update(
                    parentWindow: hostView?.window,
                    visibility: visibility,
                    selection: selection
                )
            }
        }

        private func update(
            parentWindow: NSWindow?,
            visibility: Binding<ViewSelectorVisibility>,
            selection: Binding<BoardDisplayMode>
        ) {
            self.visibility = visibility
            guard let parentWindow else {
                if visibility.wrappedValue == .hidden {
                    dismissPanelImmediately()
                }
                return
            }

            observe(parentWindow)
            guard visibility.wrappedValue == .expanded else {
                dismissPanelOnly()
                return
            }

            let panel = panel ?? makePanel(selection: selection)
            if let contentView = panel.contentView as? SelectorPanelContentView {
                contentView.update(selection: selection)
            }
            if panel.parent !== parentWindow {
                panel.parent?.removeChildWindow(panel)
                panel.level = parentWindow.level
                parentWindow.addChildWindow(panel, ordered: .above)
            }
            self.panel = panel
            if panel.isVisible {
                animationGeneration += 1
                panel.alphaValue = 1
                positionPanel()
            } else {
                present(panel)
            }
        }

        func invalidateAndDismiss() {
            _ = updateGate.advance()
            dismissPanelImmediately()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            visibility = nil
            parentWindow = nil
        }

        private func dismissPanelOnly() {
            guard let panel else { return }
            animationGeneration += 1
            let generation = animationGeneration
            let parent = panel.parent
            let hiddenOrigin = CGPoint(
                x: parentWindow?.frame.minX ?? panel.frame.maxX,
                y: panel.frame.minY
            )
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0
                panel.animator().setFrameOrigin(hiddenOrigin)
            } completionHandler: { [weak self, weak panel] in
                Task { @MainActor in
                    guard let self,
                          let panel,
                          self.panel === panel,
                          generation == self.animationGeneration else { return }
                    parent?.removeChildWindow(panel)
                    panel.orderOut(nil)
                    self.panel = nil
                }
            }
        }

        private func dismissPanelImmediately() {
            animationGeneration += 1
            guard let panel else { return }
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
            self.panel = nil
        }

        private func makePanel(selection: Binding<BoardDisplayMode>) -> NSPanel {
            let panel = InteractiveSelectorPanel(
                contentRect: CGRect(x: 0, y: 0, width: 32, height: 92),
                styleMask: SelectorPanelConfiguration.styleMask,
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
            panel.acceptsMouseMovedEvents = true
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = true
            panel.isReleasedWhenClosed = false
            panel.contentView = SelectorPanelContentView(selection: selection)
            return panel
        }

        private func present(_ panel: NSPanel) {
            guard let parentWindow else { return }
            let finalOrigin = panelOrigin(for: parentWindow)
            animationGeneration += 1
            panel.alphaValue = 0
            panel.setFrameOrigin(CGPoint(x: parentWindow.frame.minX, y: finalOrigin.y))
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(finalOrigin)
            }
        }

        private func observe(_ window: NSWindow) {
            guard parentWindow !== window else { return }
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            parentWindow = window
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.positionPanel() }
                },
                center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.positionPanel() }
                },
                center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.invalidateAndDismiss() }
                },
                center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.closeForParentDeactivation() }
                },
            ]
        }

        private func closeForParentDeactivation() {
            visibility?.wrappedValue = .hidden
            dismissPanelImmediately()
        }

        private func positionPanel() {
            guard let parentWindow, let panel else { return }
            panel.setFrameOrigin(panelOrigin(for: parentWindow))
        }

        private func panelOrigin(for window: NSWindow) -> CGPoint {
            // Overlap the board by one point so the selector reads as a single,
            // attached control even when the two windows land between pixels.
            CGPoint(x: window.frame.minX - 31, y: window.frame.maxY - 121)
        }
    }
}

private final class InteractiveSelectorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class SelectorPanelContentView: NSView {
    private let buttons: [SelectorModeButton]

    init(selection: Binding<BoardDisplayMode>) {
        buttons = BoardDisplayMode.allCases.map(SelectorModeButton.init(mode:))
        super.init(frame: CGRect(x: 0, y: 0, width: 32, height: 92))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        buttons.forEach(addSubview)
        update(selection: selection)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: 2, y: 60 - CGFloat(index * 29), width: 28, height: 28)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let radius: CGFloat = 18
        let fillShape = leftRoundedPath(in: bounds, radius: radius, closesRightEdge: true)
        NSColor.black.setFill()
        fillShape.fill()

        // Deliberately omit a border on the square right edge: it joins the
        // black departure board instead of appearing as a separate pill.
        let outlineBounds = CGRect(
            x: bounds.minX + 0.5,
            y: bounds.minY + 0.5,
            width: bounds.width - 0.5,
            height: bounds.height - 1
        )
        let outline = leftRoundedPath(in: outlineBounds, radius: radius, closesRightEdge: false)
        NSColor(calibratedWhite: 109 / 255, alpha: 1).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }

    private func leftRoundedPath(
        in rect: CGRect,
        radius: CGFloat,
        closesRightEdge: Bool
    ) -> NSBezierPath {
        let radius = min(radius, rect.height / 2)
        let curve = radius * 0.552_284_75
        let path = NSBezierPath()

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.curve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            controlPoint1: CGPoint(x: rect.minX + radius - curve, y: rect.maxY),
            controlPoint2: CGPoint(x: rect.minX, y: rect.maxY - radius + curve)
        )
        path.line(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.curve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            controlPoint1: CGPoint(x: rect.minX, y: rect.minY + radius - curve),
            controlPoint2: CGPoint(x: rect.minX + radius - curve, y: rect.minY)
        )
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        if closesRightEdge {
            path.close()
        }
        return path
    }

    func update(selection: Binding<BoardDisplayMode>) {
        applySelection(selection.wrappedValue)
        for button in buttons {
            button.onSelect = { [weak self] mode in
                self?.applySelection(mode)
                if selection.wrappedValue != mode {
                    selection.wrappedValue = mode
                }
            }
        }
    }

    private func applySelection(_ selection: BoardDisplayMode) {
        for button in buttons {
            button.isModeSelected = button.mode == selection
        }
    }
}

@MainActor
private final class SelectorModeButton: NSButton {
    let mode: BoardDisplayMode
    var onSelect: ((BoardDisplayMode) -> Void)?
    var isModeSelected = false {
        didSet {
            setAccessibilitySelected(isModeSelected)
            needsDisplay = true
        }
    }

    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var tracking: NSTrackingArea?

    init(mode: BoardDisplayMode) {
        self.mode = mode
        super.init(frame: .zero)
        title = ""
        isBordered = false
        focusRingType = .none
        toolTip = mode.label
        setAccessibilityRole(.button)
        setAccessibilityLabel(mode.label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            isHovered = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            isHovered = false
        }
    }

    override func mouseDown(with event: NSEvent) {
        selectMode()
    }

    override func accessibilityPerformPress() -> Bool {
        selectMode()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.white.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
        }

        let lineCount: Int
        let lineHeight: CGFloat
        switch mode {
        case .display:
            lineCount = 1
            lineHeight = 6
        case .extended:
            lineCount = 2
            lineHeight = 4
        case .list:
            lineCount = 3
            lineHeight = 4
        }
        let spacing: CGFloat = 2
        let totalHeight = CGFloat(lineCount) * lineHeight + CGFloat(lineCount - 1) * spacing
        let startY = bounds.midY - totalHeight / 2
        let colour = isModeSelected
            ? NSColor(red: 0, green: 230 / 255, blue: 122 / 255, alpha: 1)
            : NSColor(calibratedWhite: 232 / 255, alpha: 1)
        colour.setStroke()

        for index in 0..<lineCount {
            let rect = CGRect(
                x: bounds.midX - 7.5,
                y: startY + CGFloat(index) * (lineHeight + spacing),
                width: 15,
                height: lineHeight
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            path.lineWidth = 1.2
            path.stroke()
        }
    }

    private func selectMode() {
        onSelect?(mode)
    }
}

struct ExtendedBoardView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var store: BoardStore
    let onSelectDeparture: (Departure) -> Void

    private let ink = Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255)

    var body: some View {
        VStack(spacing: 0) {
            StationBoardHeader(name: stationName, height: 30, fontSize: 16, ink: ink)

            VStack(spacing: 0) {
                if services.isEmpty {
                    BoardEmptyContent(store: store, height: 192, ink: ink)
                } else {
                    ForEach(Array(services.enumerated()), id: \.element.id) { index, departure in
                        ExtendedDepartureRow(
                            number: index + 1,
                            departure: departure,
                            information: ExtendedBoardPresentation.showsInformation(for: index)
                                ? BoardPresentation.priorityInformation(
                                    for: departure,
                                    details: store.details(for: departure),
                                    activeCRS: preferences.activeStation?.crs
                                )
                                : nil,
                            ink: ink
                        ) {
                            onSelectDeparture(departure)
                        }
                    }
                    if services.count < 4 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 192)

            BoardNoticeFooter(
                messages: noticeMessages,
                style: .extended,
                ink: ink
            )
        }
        .frame(width: 488, height: 315)
        .background(Color.black)
        .foregroundStyle(ink)
    }

    private var services: ArraySlice<Departure> {
        store.board?.services.prefix(4) ?? ArraySlice<Departure>()
    }
    private var stationName: String { store.board?.station.name ?? preferences.activeStation?.name ?? "Platform" }
    private var noticeMessages: [String] {
        BoardPresentation.stationNotices(board: store.board, isStale: store.isStale, issue: store.issue)
    }
}

enum ExtendedBoardPresentation {
    static let rowHeight: CGFloat = 48
    static let featuredMainLineHeight: CGFloat = 27
    static let informationLineHeight: CGFloat = 20
    static let separatorHeight: CGFloat = 1

    static func showsInformation(for index: Int) -> Bool {
        index == 0
    }

    static func mainLineHeight(for index: Int) -> CGFloat {
        showsInformation(for: index)
            ? featuredMainLineHeight
            : rowHeight - separatorHeight
    }
}

private struct ExtendedDepartureRow: View {
    let number: Int
    let departure: Departure
    let information: String?
    let ink: Color
    let action: () -> Void

    @State private var startedAt = Date()

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(String(number))
                        .font(DepartureBoardFont.bold(15))
                        .frame(width: 28, alignment: .leading)
                    Text(departure.scheduledDeparture)
                        .font(DepartureBoardFont.regular(14))
                        .frame(width: 58, alignment: .leading)
                    Text(RailTextSanitizer.clean(departure.destinationText))
                        .font(DepartureBoardFont.regular(14))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(BoardPresentation.displayStatus(for: departure))
                        .font(DepartureBoardFont.regular(13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(width: 92, alignment: .trailing)
                    Text("Plat \(departure.platform ?? "-")")
                        .font(DepartureBoardFont.medium(11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 44, alignment: .trailing)
                }
                .frame(height: ExtendedBoardPresentation.mainLineHeight(for: number - 1))

                if let information, !information.isEmpty {
                    MarqueeLine(
                        text: information,
                        ink: ink,
                        startedAt: startedAt,
                        fontName: DepartureBoardFont.heavyName,
                        fontSize: 10.5
                    )
                    .frame(height: ExtendedBoardPresentation.informationLineHeight)
                    .accessibilityHidden(true)
                }
                Rectangle()
                    .fill(ink.opacity(0.25))
                    .frame(height: ExtendedBoardPresentation.separatorHeight)
            }
            .padding(.horizontal, 8)
            .frame(height: ExtendedBoardPresentation.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BoardAccessibility.departure(number: number, departure: departure))
        .onAppear { startedAt = .now }
    }
}

struct ListBoardView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var store: BoardStore
    let onSelectDeparture: (Departure) -> Void

    private let ink = Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255)

    var body: some View {
        VStack(spacing: 0) {
            StationBoardHeader(name: stationName, height: 34, fontSize: 14, ink: ink)
            ListColumnHeader(ink: ink)

            if let first = services.first {
                FeaturedListDeparture(
                    departure: first,
                    messages: BoardPresentation.informationMessages(
                        for: first,
                        details: store.details(for: first),
                        board: store.board,
                        activeCRS: preferences.activeStation?.crs,
                        isStale: store.isStale,
                        issue: store.issue
                    ),
                    ink: ink
                ) {
                    onSelectDeparture(first)
                }

                VStack(spacing: 0) {
                    ForEach(Array(services.dropFirst().enumerated()), id: \.element.id) { offset, departure in
                        CompactListDeparture(number: offset + 2, departure: departure, ink: ink) {
                            onSelectDeparture(departure)
                        }
                    }
                    if services.count < 9 { Spacer(minLength: 0) }
                }
                .frame(height: 232)
            } else {
                BoardEmptyContent(store: store, height: 336, ink: ink)
            }

            BoardNoticeFooter(messages: noticeMessages, style: .list, ink: ink)
        }
        .frame(width: 488, height: 610)
        .background(Color.black)
        .foregroundStyle(ink)
    }

    private var services: ArraySlice<Departure> {
        store.board?.services.prefix(9) ?? ArraySlice<Departure>()
    }
    private var stationName: String { store.board?.station.name ?? preferences.activeStation?.name ?? "Platform" }
    private var noticeMessages: [String] {
        BoardPresentation.stationNotices(board: store.board, isStale: store.isStale, issue: store.issue)
    }
}

private struct ListColumnHeader: View {
    let ink: Color

    var body: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 28, alignment: .leading)
            Text("Time").frame(width: 70, alignment: .leading)
            Text("Destination").frame(maxWidth: .infinity, alignment: .leading)
            Text("Arriving")
                .frame(width: 120, alignment: .trailing)
                .offset(x: -18)
            Text("Plat.").frame(width: 40, alignment: .trailing)
        }
        .font(DepartureBoardFont.regular(12))
        .padding(.horizontal, 8)
        .frame(height: 42)
        .overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: 1).padding(.horizontal, 8) }
    }
}

private struct FeaturedListDeparture: View {
    let departure: Departure
    let messages: [String]
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                DepartureColumns(number: 1, departure: departure, ink: ink, prominent: true)
                    .frame(height: 30)
                InformationTicker(messages: messages, ink: ink, viewportWidth: 468)
                    .frame(height: 20)
                    .padding(.horizontal, 10)
                CarriageDiagram(count: departure.carriageCount, ink: ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
                    .frame(height: 53)
            }
            .frame(height: 104)
            .overlay(alignment: .bottom) { Rectangle().fill(ink.opacity(0.25)).frame(height: 1).padding(.horizontal, 8) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BoardAccessibility.departure(number: 1, departure: departure))
    }
}

private struct CompactListDeparture: View {
    let number: Int
    let departure: Departure
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DepartureColumns(number: number, departure: departure, ink: ink, prominent: false)
                .frame(height: 29)
                .overlay(alignment: .bottom) { Rectangle().fill(ink.opacity(0.25)).frame(height: 1).padding(.horizontal, 8) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BoardAccessibility.departure(number: number, departure: departure))
    }
}

private struct DepartureColumns: View {
    let number: Int
    let departure: Departure
    let ink: Color
    let prominent: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(String(number))
                .font(DepartureBoardFont.bold(prominent ? 14 : 12))
                .frame(width: 28, alignment: .leading)
            Text(departure.scheduledDeparture)
                .frame(width: 70, alignment: .leading)
            Text(RailTextSanitizer.clean(departure.destinationText))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(BoardPresentation.displayStatus(for: departure))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 120, alignment: .trailing)
            Text(departure.platform ?? "-")
                .frame(width: 40, alignment: .trailing)
        }
        .font(DepartureBoardFont.regular(prominent ? 14 : 12))
        .padding(.horizontal, 8)
        .foregroundStyle(ink)
    }
}

private struct StationBoardHeader: View {
    let name: String
    let height: CGFloat
    let fontSize: CGFloat
    let ink: Color

    var body: some View {
        Text(RailTextSanitizer.clean(name))
            .font(DepartureBoardFont.medium(fontSize))
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 10)
            .padding(.top, 8)
            .frame(height: height)
            .overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: 1).padding(.horizontal, 10) }
    }
}

private struct BoardEmptyContent: View {
    @ObservedObject var store: BoardStore
    let height: CGFloat
    let ink: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(headline).font(DepartureBoardFont.regular(14))
            Text(message).font(DepartureBoardFont.heavy(11))
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, 20)
    }

    private var headline: String {
        if store.isLoading { return "Loading departures…" }
        switch store.issue {
        case .offline: return "Offline"
        case .upstream: return "Live data unavailable"
        case .rateLimited: return "Refresh paused"
        case .serviceExpired: return "Service expired"
        case .invalidResponse: return "Unable to read live data"
        case nil: return "No upcoming services"
        }
    }

    private var message: String { store.issue?.message ?? "There are no departures in the current two-hour window." }
}

private enum BoardFooterStyle: Equatable { case extended, list }

private struct BoardNoticeFooter: View {
    let messages: [String]
    let style: BoardFooterStyle
    let ink: Color

    var body: some View {
        VStack(spacing: 0) {
            if style == .list {
                Color.clear.frame(height: 8)
            }

            InformationTicker(
                messages: messages,
                ink: ink,
                viewportWidth: 464,
                fontName: DepartureBoardFont.heavyName,
                fontSize: style == .extended ? 10.5 : 9
            )
                .frame(height: style == .extended ? 25 : 34)
                .padding(.horizontal, 12)
                .overlay { Rectangle().stroke(ink, lineWidth: 1).padding(.horizontal, 8) }
                .accessibilityLabel("Station notice: \(messages.first ?? "No current station notices.")")

            if style == .list {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 38)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }

            BoardClock(fontSize: style == .extended ? 26 : 36, ink: ink)
                .frame(height: style == .extended ? 68 : 72)
        }
        .frame(height: style == .extended ? 93 : 198)
    }
}

private struct BoardClock: View {
    let fontSize: CGFloat
    let ink: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(BoardClockFormatter.string(from: context.date))
                .font(DepartureBoardFont.regular(fontSize))
                .tracking(1)
                .foregroundStyle(ink)
                .accessibilityLabel("Current time \(BoardClockFormatter.string(from: context.date))")
        }
    }
}

enum BoardClockFormatter {
    static func string(from date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "en_GB"))
        )
    }
}

private enum BoardAccessibility {
    static func departure(number: Int, departure: Departure) -> String {
        let platform = departure.platform.map { "platform \($0)" } ?? "platform not announced"
        return "Departure \(number), \(departure.scheduledDeparture) to \(departure.destinationText), \(BoardPresentation.displayStatus(for: departure)), \(platform)"
    }
}
