import SwiftUI

struct ServiceDetailView: View {
    @ObservedObject var store: BoardStore

    private let ink = Color(red: 244 / 255, green: 244 / 255, blue: 242 / 255)
    private let rule = Color(red: 109 / 255, green: 109 / 255, blue: 109 / 255)

    var body: some View {
        VStack(spacing: 0) {
            header
            serviceSummary
            callingPointContent
        }
        .frame(width: 488, height: 610)
        .background(Color.black)
        .foregroundStyle(ink)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                store.closeDetails()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 28, height: 28)
                    .background(Color(red: 69 / 255, green: 69 / 255, blue: 69 / 255))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Back to departures")

            VStack(alignment: .leading, spacing: 3) {
                Text(headerDestination)
                    .font(DepartureBoardFont.medium(16))
                    .tracking(-0.6)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(headerSubtitle)
                    .font(DepartureBoardFont.regular(14))
                    .tracking(-0.3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.top, 1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .frame(height: 64, alignment: .top)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(rule)
                .frame(height: 1)
                .padding(.horizontal, 12)
        }
    }

    private var serviceSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(operatorName)
                .font(DepartureBoardFont.heavy(12))
                .tracking(-0.3)
                .lineLimit(1)

            Text(routeText)
                .font(DepartureBoardFont.regular(14))
                .tracking(-0.35)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 5)
        .padding(.horizontal, 12)
        .frame(height: 44, alignment: .top)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(rule)
                .frame(height: 1)
                .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private var callingPointContent: some View {
        if store.isLoadingDetails {
            detailMessage("Loading calling points…")
        } else if let details = store.details, !details.callingPoints.isEmpty {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(details.callingPoints.enumerated()), id: \.element.id) { index, point in
                        CallingPointBoardRow(
                            point: point,
                            isFinal: index == details.callingPoints.indices.last,
                            ink: ink,
                            rule: rule
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
        } else if let issue = store.issue {
            detailMessage("\(issue.title). \(issue.message)")
        } else {
            detailMessage("No calling points are available for this service.")
        }
    }

    private func detailMessage(_ message: String) -> some View {
        Text(message)
            .font(DepartureBoardFont.regular(14))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)
    }

    private var headerDestination: String {
        RailTextSanitizer.clean(store.selectedDeparture?.destinationText ?? "Service details")
    }

    private var headerSubtitle: String {
        guard let departure = store.selectedDeparture else { return "" }
        return "\(departure.scheduledDeparture) · \(RailTextSanitizer.clean(departure.operatorName))"
    }

    private var operatorName: String {
        let value = store.details?.operatorName ?? store.selectedDeparture?.operatorName ?? ""
        return RailTextSanitizer.clean(value)
    }

    private var routeText: String {
        guard let details = store.details else { return "Loading route…" }
        let origins = details.origins.map { RailTextSanitizer.clean($0.name) }.joined(separator: " & ")
        let destinations = details.destinations.map { RailTextSanitizer.clean($0.name) }.joined(separator: " & ")
        return "\(origins) → \(destinations)"
    }
}

private struct CallingPointBoardRow: View {
    let point: CallingPoint
    let isFinal: Bool
    let ink: Color
    let rule: Color

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            stopTrack

            Text(RailTextSanitizer.clean(point.station.name))
                .font(DepartureBoardFont.regular(14))
                .tracking(-0.35)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text(ServiceDetailPresentation.liveText(for: point))
                    .font(DepartureBoardFont.heavy(12))
                    .tracking(-0.25)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Booked \(point.scheduledTime)")
                    .font(DepartureBoardFont.regular(11))
                    .tracking(-0.2)
                    .lineLimit(1)
            }
            .padding(.top, 1)
            .frame(width: 90, alignment: .trailing)
        }
        .frame(height: 44, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ServiceDetailPresentation.accessibilityLabel(for: point))
    }

    private var stopTrack: some View {
        ZStack(alignment: .topLeading) {
            if !isFinal {
                DottedStopConnector(colour: rule)
                    .frame(width: 14, height: 27)
                    .offset(y: 17)
            }

            Circle()
                .fill(ink)
                .frame(width: 14, height: 14)
        }
        .frame(width: 20, height: 44, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

private struct DottedStopConnector: View {
    let colour: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 7, y: 0))
            path.addLine(to: CGPoint(x: 7, y: size.height))
            context.stroke(
                path,
                with: .color(colour),
                style: StrokeStyle(lineWidth: 2, dash: [2, 3])
            )
        }
    }
}

enum ServiceDetailPresentation {
    static func liveText(for point: CallingPoint) -> String {
        if point.statusText?.localizedCaseInsensitiveContains("cancel") == true {
            return "Cancelled"
        }

        if let actual = clean(point.actualTime) {
            return normalizedStatus(actual)
        }
        if let expected = clean(point.expectedTime) {
            return normalizedStatus(expected)
        }
        return "On Time"
    }

    static func accessibilityLabel(for point: CallingPoint) -> String {
        "\(RailTextSanitizer.clean(point.station.name)), \(liveText(for: point)), booked \(point.scheduledTime)"
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = RailTextSanitizer.clean(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func normalizedStatus(_ value: String) -> String {
        switch value.lowercased() {
        case "on time": return "On Time"
        case "cancelled", "canceled": return "Cancelled"
        case "delayed": return "Delayed"
        default: return value
        }
    }
}
