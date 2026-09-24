import Foundation

protocol RailAPIProviding: Sendable {
    func departures(for crs: String, limit: Int) async throws -> DepartureBoardFetch
    func serviceDetails(id: String) async throws -> ServiceDetails
}

struct RailAPIClient: RailAPIProviding {
    let baseURL: URL
    let installationID: String
    var session: URLSession = .shared

    func departures(for crs: String, limit: Int) async throws -> DepartureBoardFetch {
        let safeLimit = min(max(limit, 1), 10)
        let station = crs.uppercased()
        guard station.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else {
            throw APIErrorEnvelope(code: "invalid_request", message: "Invalid station code.", retryAfter: nil)
        }
        let result: (DepartureBoard, HTTPURLResponse) = try await request(path: "/v1/departures/\(station)", query: [
            URLQueryItem(name: "limit", value: String(safeLimit))
        ])
        return DepartureBoardFetch(
            board: result.0,
            isStale: result.1.value(forHTTPHeaderField: "X-Platform-Stale")?
                .localizedCaseInsensitiveCompare("true") == .orderedSame
        )
    }

    func serviceDetails(id: String) async throws -> ServiceDetails {
        guard !id.isEmpty,
              let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else {
            throw APIErrorEnvelope(code: "invalid_request", message: "Invalid service identifier.", retryAfter: nil)
        }
        let result: (ServiceDetails, HTTPURLResponse) = try await request(
            path: "/v1/services/\(encoded)",
            query: []
        )
        return result.0
    }

    private func request<Response: Decodable>(
        path: String,
        query: [URLQueryItem]
    ) async throws -> (Response, HTTPURLResponse) {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(installationID, forHTTPHeaderField: "X-Platform-Install-ID")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let decoder = Self.decoder

        guard 200..<300 ~= http.statusCode else {
            if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw envelope
            }
            throw URLError(.badServerResponse)
        }
        do {
            return (try decoder.decode(Response.self, from: data), http)
        } catch {
            throw APIErrorEnvelope(code: "invalid_response", message: "Invalid live data response.", retryAfter: nil)
        }
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date")
        }
        return decoder
    }
}
