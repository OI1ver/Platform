import Foundation

struct Station: Codable, Hashable, Identifiable, Sendable {
    let crs: String
    let name: String

    var id: String { crs }
}

struct StationReference: Codable, Hashable, Sendable {
    let crs: String?
    let name: String
}

enum ServiceStatus: String, Codable, Sendable {
    case onTime = "on_time"
    case delayed
    case cancelled
    case platformChanged = "platform_changed"
    case unknown
}

struct Departure: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let scheduledDeparture: String
    let expectedDeparture: String
    let destinations: [StationReference]
    let platform: String?
    let carriageCount: Int?
    let operatorName: String
    let status: ServiceStatus
    let statusText: String
    let delayReason: String?
    let cancellationReason: String?

    var destinationText: String {
        destinations.map(\.name).joined(separator: " & ")
    }
}

struct DepartureBoard: Codable, Equatable, Sendable {
    let station: Station
    let generatedAt: Date
    let services: [Departure]
    let messages: [String]
}

struct DepartureBoardFetch: Equatable, Sendable {
    let board: DepartureBoard
    let isStale: Bool
}

struct CallingPoint: Codable, Hashable, Identifiable, Sendable {
    let station: StationReference
    let scheduledTime: String
    let expectedTime: String?
    let actualTime: String?
    let platform: String?
    let statusText: String?

    var id: String {
        "\(station.crs ?? station.name)-\(scheduledTime)"
    }

    var liveTime: String {
        actualTime ?? expectedTime ?? scheduledTime
    }
}

struct ServiceDetails: Codable, Equatable, Sendable {
    let id: String
    let operatorName: String
    let origins: [StationReference]
    let destinations: [StationReference]
    let callingPoints: [CallingPoint]
    let generatedAt: Date
}

struct APIErrorEnvelope: Codable, Error, Equatable, Sendable {
    let code: String
    let message: String
    let retryAfter: Int?
}

enum AppIssue: Equatable, Sendable {
    case offline
    case upstream
    case rateLimited(retryAfter: Int?)
    case serviceExpired
    case invalidResponse

    var title: String {
        switch self {
        case .offline: "You’re offline"
        case .upstream: "Live data unavailable"
        case .rateLimited: "Refresh paused"
        case .serviceExpired: "Service details expired"
        case .invalidResponse: "We couldn’t read this update"
        }
    }

    var message: String {
        switch self {
        case .offline:
            "Platform will keep showing the last saved departures."
        case .upstream:
            "National Rail data is temporarily unavailable. Try again shortly."
        case let .rateLimited(retryAfter):
            retryAfter.map { "Try again in about \($0) seconds." } ?? "Try again in a moment."
        case .serviceExpired:
            "Darwin no longer provides details for this departed service."
        case .invalidResponse:
            "The live data response was incomplete or unexpected."
        }
    }
}
