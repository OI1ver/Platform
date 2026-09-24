import AppKit
import SwiftUI

struct BoardView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var store: BoardStore
    let onSelectDeparture: (Departure) -> Void

    private let ink = Color(red: 232 / 255, green: 232 / 255, blue: 232 / 255)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black

            Text(RailTextSanitizer.clean(stationName))
                .font(DepartureBoardFont.medium(14))
                .lineLimit(1)
                .frame(width: 464, alignment: .leading)
                .offset(x: 10, y: 11)

            Rectangle()
                .fill(ink)
                .frame(width: 463, height: 1)
                .offset(x: 11, y: 29)

            if let departure = featuredDeparture {
                departureContent(departure)
            } else {
                emptyContent
            }
        }
        .frame(width: 488, height: 150)
        .foregroundStyle(ink)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let departure = featuredDeparture else { return }
            onSelectDeparture(departure)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(featuredDeparture == nil ? "Use the context menu for station and app options." : "Activate for service details. Use the context menu for station and app options.")
        .accessibilityAction(named: "Refresh departures") {
            Task { await store.refresh() }
        }
    }

    @ViewBuilder
    private func departureContent(_ departure: Departure) -> some View {
        Text("1")
            .font(DepartureBoardFont.bold(14))
            .frame(width: 20, alignment: .leading)
            .offset(x: 10, y: 48)

        Text(departure.scheduledDeparture)
            .font(DepartureBoardFont.regular(14))
            .tracking(1)
            .frame(width: 68, alignment: .leading)
            .offset(x: 37, y: 48)

        Text(RailTextSanitizer.clean(departure.destinationText))
            .font(DepartureBoardFont.regular(14))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 250, alignment: .leading)
            .offset(x: 112, y: 48)

        Text(BoardPresentation.displayStatus(for: departure))
            .font(DepartureBoardFont.regular(14))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: 109, alignment: .trailing)
            .offset(x: 366, y: 48)

        InformationTicker(
            messages: BoardPresentation.informationMessages(
                for: departure,
                details: store.featuredDetails,
                board: store.board,
                activeCRS: preferences.activeStation?.crs,
                isStale: store.isStale,
                issue: store.issue
            ),
            ink: ink
        )
            .frame(width: 416, height: 18, alignment: .leading)
            .offset(x: 10, y: 78)

        CarriageDiagram(count: departure.carriageCount, ink: ink)
            .offset(x: 11, y: 111)

        PlatformIdentifier(platform: departure.platform, ink: ink)
            .offset(x: 428, y: 94)
    }

    private var emptyContent: some View {
        Group {
            Text(emptyHeadline)
                .font(DepartureBoardFont.regular(14))
                .lineLimit(1)
                .frame(width: 465, alignment: .leading)
                .offset(x: 10, y: 48)

            Text(emptyMessage)
                .font(DepartureBoardFont.heavy(12))
                .lineLimit(1)
                .frame(width: 465, alignment: .leading)
                .offset(x: 10, y: 79)
        }
    }

    private var featuredDeparture: Departure? {
        store.board?.services.first
    }

    private var stationName: String {
        store.board?.station.name ?? preferences.activeStation?.name ?? "Platform"
    }

    private var emptyHeadline: String {
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

    private var emptyMessage: String {
        store.issue?.message ?? "There are no departures in the current two-hour window."
    }

    private var accessibilitySummary: String {
        guard let departure = featuredDeparture else {
            return "\(stationName). \(emptyHeadline). \(emptyMessage)"
        }
        let platform = departure.platform.map { "Platform \($0)." } ?? "Platform not yet announced."
        return "\(stationName). First departure, \(departure.scheduledDeparture) to \(departure.destinationText). \(BoardPresentation.displayStatus(for: departure)). \(platform)"
    }
}

struct PlatformIdentifier: View {
    let platform: String?
    let ink: Color

    var body: some View {
        VStack(spacing: -1) {
            Text("Plat.")
            Text(platform ?? "-")
        }
        .font(DepartureBoardFont.medium(13))
        .multilineTextAlignment(.center)
        .frame(width: 48, height: 48)
        .overlay(Rectangle().stroke(ink, lineWidth: 1))
        .accessibilityLabel(platform.map { "Platform \($0)" } ?? "Platform not yet announced")
    }
}

struct CarriageDiagram: View {
    let count: Int?
    let ink: Color

    private var visibleCount: Int {
        CarriageLayout.visibleCount(for: count)
    }

    var body: some View {
        HStack(spacing: CarriageLayout.spacing) {
            ForEach(0..<visibleCount, id: \.self) { _ in
                Rectangle()
                    .stroke(ink, lineWidth: 1)
                    .frame(width: CarriageLayout.boxWidth(for: visibleCount), height: 21)
            }
        }
        .accessibilityLabel(count.map { "\($0) carriage train" } ?? "Carriage count not available")
    }
}

enum CarriageLayout {
    static let availableWidth: CGFloat = 416
    static let spacing: CGFloat = 4
    static let preferredBoxWidth: CGFloat = 47
    static let maximumVisibleCoaches = 24

    static func visibleCount(for count: Int?) -> Int {
        min(max(count ?? 0, 0), maximumVisibleCoaches)
    }

    static func boxWidth(for count: Int) -> CGFloat {
        guard count > 0 else { return preferredBoxWidth }
        let gaps = CGFloat(count - 1) * spacing
        return min(preferredBoxWidth, (availableWidth - gaps) / CGFloat(count))
    }
}

enum RailTextSanitizer {
    static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<br\\s*/?>", with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</p>", with: " ", options: [.caseInsensitive])
            .replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&#160;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&#xA0;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&lt;", with: "<", options: .caseInsensitive)
            .replacingOccurrences(of: "&gt;", with: ">", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "&apos;", with: "'", options: .caseInsensitive)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum BoardPresentation {
    static func displayStatus(for departure: Departure) -> String {
        switch departure.status {
        case .onTime:
            return "On Time"
        case .cancelled:
            return "Cancelled"
        case .platformChanged:
            return "Platform Chg"
        case .delayed:
            return departure.delayReason == nil && departure.expectedDeparture != departure.scheduledDeparture
                ? "Exp \(departure.expectedDeparture)"
                : "Delayed"
        case .unknown:
            return departure.expectedDeparture != departure.scheduledDeparture
                ? "Exp \(departure.expectedDeparture)"
                : departure.statusText
        }
    }

    static func informationMessages(
        for departure: Departure,
        details: ServiceDetails?,
        board: DepartureBoard?,
        activeCRS: String?,
        isStale: Bool,
        issue: AppIssue?
    ) -> [String] {
        var messages: [String] = []
        if isStale, let generatedAt = board?.generatedAt {
            append(
                "Saved information from \(generatedAt.formatted(date: .omitted, time: .shortened)). Live data is currently unavailable.",
                to: &messages
            )
        }
        append(departure.cancellationReason ?? departure.delayReason, to: &messages)

        let callingPoints = onwardCallingPoints(in: details, after: activeCRS)
        if !callingPoints.isEmpty {
            messages.append("Calling at \(callingPoints.joined(separator: ", "))")
        }

        if let count = departure.carriageCount {
            messages.append("This train has \(count) \(count == 1 ? "coach" : "coaches").")
        } else {
            messages.append("Coach information is not available for this service.")
        }
        for message in board?.messages ?? [] { append(message, to: &messages) }
        if let issue, !isStale { messages.append("\(issue.title). \(issue.message)") }
        if messages.isEmpty {
            messages.append(departure.operatorName.isEmpty
                ? departure.statusText
                : "Operated by \(departure.operatorName)")
        }
        return messages
    }

    static func priorityInformation(
        for departure: Departure,
        details: ServiceDetails?,
        activeCRS: String?
    ) -> String {
        if let reason = cleaned(departure.cancellationReason ?? departure.delayReason) {
            return reason
        }
        let callingPoints = onwardCallingPoints(in: details, after: activeCRS)
        if !callingPoints.isEmpty {
            return "Calling at \(callingPoints.joined(separator: ", "))"
        }
        if let count = departure.carriageCount {
            return "This train has \(count) \(count == 1 ? "coach" : "coaches")."
        }
        if !departure.operatorName.isEmpty {
            return "Operated by \(RailTextSanitizer.clean(departure.operatorName))"
        }
        return RailTextSanitizer.clean(departure.statusText)
    }

    static func stationNotices(
        board: DepartureBoard?,
        isStale: Bool,
        issue: AppIssue?
    ) -> [String] {
        var messages: [String] = []
        if isStale, let generatedAt = board?.generatedAt {
            messages.append(
                "Saved information from \(generatedAt.formatted(date: .omitted, time: .shortened)). Live data is currently unavailable."
            )
        } else if let issue {
            messages.append("\(issue.title). \(issue.message)")
        }
        for message in board?.messages ?? [] { append(message, to: &messages) }
        return messages.isEmpty ? ["No current station notices."] : messages
    }

    private static func onwardCallingPoints(in details: ServiceDetails?, after activeCRS: String?) -> [String] {
        guard let details else { return [] }
        let points: ArraySlice<CallingPoint>
        if let activeCRS,
           let stationIndex = details.callingPoints.firstIndex(where: { $0.station.crs == activeCRS }) {
            points = details.callingPoints.dropFirst(stationIndex + 1)
        } else {
            points = details.callingPoints[...]
        }
        return points.map { RailTextSanitizer.clean($0.station.name) }
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = RailTextSanitizer.clean(value)
        return result.isEmpty ? nil : result
    }

    private static func append(_ value: String?, to messages: inout [String]) {
        guard let cleaned = cleaned(value) else { return }
        messages.append(cleaned)
    }
}

struct InformationTicker: View {
    let messages: [String]
    let ink: Color
    var viewportWidth: CGFloat = 416
    var fontName: String = DepartureBoardFont.heavyName
    var fontSize: CGFloat = 12

    @State private var messageIndex = 0
    @State private var messageStartedAt = Date()

    var body: some View {
        ZStack(alignment: .leading) {
            MarqueeLine(
                text: safeMessages[messageIndex % safeMessages.count],
                ink: ink,
                startedAt: messageStartedAt,
                fontName: fontName,
                fontSize: fontSize
            )
            .id(messageIndex)
            .transition(.opacity)
        }
        .task(id: messages) {
            messageIndex = 0
            messageStartedAt = .now

            while !Task.isCancelled {
                let message = safeMessages[messageIndex % safeMessages.count]
                let duration = MarqueeTiming.displayDuration(for: message, viewportWidth: viewportWidth)
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: MarqueeTiming.fadeDuration)) {
                    messageIndex = (messageIndex + 1) % safeMessages.count
                    messageStartedAt = .now
                }
            }
        }
    }

    private var safeMessages: [String] {
        messages.isEmpty ? [""] : messages
    }
}

struct MarqueeLine: View {
    let text: String
    let ink: Color
    let startedAt: Date
    var fontName: String = DepartureBoardFont.heavyName
    var fontSize: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let textWidth = measuredWidth
            let shouldScroll = textWidth > proxy.size.width

            if reduceMotion || !shouldScroll {
                Text(text)
                    .font(.custom(fontName, size: fontSize))
                    .lineLimit(1)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                    .clipped()
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let cycleWidth = textWidth + MarqueeTiming.gap
                    let cycleDuration = MarqueeTiming.cycleDuration(for: text)
                    let elapsed = max(0, context.date.timeIntervalSince(startedAt))
                    let scrollingElapsed = max(0, elapsed - MarqueeTiming.initialPause)
                    let travelled = CGFloat(scrollingElapsed / cycleDuration) * cycleWidth
                    let offset = -travelled.truncatingRemainder(dividingBy: cycleWidth)

                    HStack(spacing: MarqueeTiming.gap) {
                        Text(text)
                        Text(text)
                    }
                    .font(.custom(fontName, size: fontSize))
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: offset)
                    .frame(height: proxy.size.height, alignment: .leading)
                }
            }
        }
        .foregroundStyle(ink)
        .clipped()
    }

    private var measuredWidth: CGFloat {
        MarqueeTiming.measuredWidth(for: text, fontName: fontName, fontSize: fontSize)
    }
}

enum MarqueeTiming {
    static let gap: CGFloat = 80
    static let minimumCycleDuration: TimeInterval = 8
    static let initialPause: TimeInterval = 0.5
    static let passesBeforeAdvance = 1.0
    static let staticMessageDuration: TimeInterval = 9
    static let fadeDuration: TimeInterval = 0.35

    static func cycleDuration(for text: String) -> TimeInterval {
        max(minimumCycleDuration, Double(text.count) * 0.18)
    }

    static func displayDuration(for text: String, viewportWidth: CGFloat) -> TimeInterval {
        guard measuredWidth(for: text) > viewportWidth else { return staticMessageDuration }
        return initialPause + cycleDuration(for: text) * passesBeforeAdvance
    }

    static func measuredWidth(for text: String) -> CGFloat {
        measuredWidth(for: text, fontName: DepartureBoardFont.heavyName, fontSize: 12)
    }

    static func measuredWidth(for text: String, fontName: String, fontSize: CGFloat) -> CGFloat {
        let font = NSFont(name: fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .heavy)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }
}
