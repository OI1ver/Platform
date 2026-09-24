import Foundation

@MainActor
final class BoardStore: ObservableObject {
    @Published private(set) var board: DepartureBoard?
    @Published private(set) var details: ServiceDetails?
    @Published private(set) var detailsByServiceID: [String: ServiceDetails] = [:]
    @Published private(set) var issue: AppIssue?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingDetails = false
    @Published private(set) var isStale = false
    @Published private(set) var selectedDeparture: Departure?

    private let api: any RailAPIProviding
    private let cache: any BoardCaching
    private var refreshTask: Task<Void, Never>?
    private var station: Station?
    private var featuredServiceID: String?
    private var refreshGeneration = 0
    private var detailGeneration = 0

    var featuredDetails: ServiceDetails? {
        guard let featuredServiceID else { return nil }
        return detailsByServiceID[featuredServiceID]
    }

    init(api: any RailAPIProviding, cache: any BoardCaching) {
        self.api = api
        self.cache = cache
    }

    func appear(station: Station?, automaticRefresh: Bool) {
        self.station = station
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            guard automaticRefresh else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await self.refresh(showSpinner: false)
            }
        }
    }

    func changeStation(to station: Station?) async {
        self.station = station
        detailGeneration += 1
        board = nil
        details = nil
        detailsByServiceID = [:]
        featuredServiceID = nil
        selectedDeparture = nil
        issue = nil
        isStale = false
        await refresh()
    }

    func disappear() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh(showSpinner: Bool = true) async {
        guard let station else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        let requestedCRS = station.crs
        if showSpinner && board == nil { isLoading = true }
        defer {
            if generation == refreshGeneration {
                isLoading = false
            }
        }

        do {
            let result = try await api.departures(for: requestedCRS, limit: 10)
            guard isCurrentRefresh(generation: generation, crs: requestedCRS) else { return }
            board = result.board
            retainDetails(for: result.board)
            issue = nil
            isStale = result.isStale
            await cache.save(result.board)
            guard isCurrentRefresh(generation: generation, crs: requestedCRS) else { return }
            await loadFeaturedDetails(for: result.board.services.first)
        } catch {
            guard !Task.isCancelled,
                  isCurrentRefresh(generation: generation, crs: requestedCRS) else { return }
            issue = Self.map(error)
            if let cached = await cache.load(crs: requestedCRS) {
                guard isCurrentRefresh(generation: generation, crs: requestedCRS) else { return }
                board = cached
                retainDetails(for: cached)
                isStale = true
                await loadFeaturedDetails(for: cached.services.first)
            }
        }
    }

    func select(_ departure: Departure) async {
        detailGeneration += 1
        let generation = detailGeneration
        selectedDeparture = departure
        details = nil
        issue = nil
        isLoadingDetails = true
        defer {
            if generation == detailGeneration {
                isLoadingDetails = false
            }
        }
        if let cached = detailsByServiceID[departure.id] {
            if isCurrentDetail(generation: generation, serviceID: departure.id) {
                details = cached
            }
            return
        }
        do {
            let result = try await api.serviceDetails(id: departure.id)
            detailsByServiceID[departure.id] = result
            guard isCurrentDetail(generation: generation, serviceID: departure.id) else { return }
            details = result
        } catch {
            guard !Task.isCancelled,
                  isCurrentDetail(generation: generation, serviceID: departure.id) else { return }
            issue = Self.map(error)
        }
    }

    func closeDetails() {
        detailGeneration += 1
        selectedDeparture = nil
        details = nil
        issue = nil
        isLoadingDetails = false
    }

    func details(for departure: Departure) -> ServiceDetails? {
        detailsByServiceID[departure.id]
    }

    func prefetchDetails(for departures: ArraySlice<Departure>) async {
        let requests = departures.filter { detailsByServiceID[$0.id] == nil }
        guard !requests.isEmpty else { return }
        let api = self.api

        await withTaskGroup(of: (String, ServiceDetails?).self) { group in
            for departure in requests {
                group.addTask {
                    do {
                        return (departure.id, try await api.serviceDetails(id: departure.id))
                    } catch {
                        return (departure.id, nil)
                    }
                }
            }

            for await (serviceID, result) in group {
                guard let result,
                      board?.services.contains(where: { $0.id == serviceID }) == true else { continue }
                detailsByServiceID[serviceID] = result
            }
        }
    }

    private func loadFeaturedDetails(for departure: Departure?) async {
        guard let departure else {
            featuredServiceID = nil
            return
        }
        featuredServiceID = departure.id
        await prefetchDetails(for: [departure][...])
    }

    private func retainDetails(for board: DepartureBoard) {
        let activeIDs = Set(board.services.map(\.id))
        detailsByServiceID = detailsByServiceID.filter { activeIDs.contains($0.key) }
    }

    private func isCurrentRefresh(generation: Int, crs: String) -> Bool {
        generation == refreshGeneration && station?.crs == crs && !Task.isCancelled
    }

    private func isCurrentDetail(generation: Int, serviceID: String) -> Bool {
        generation == detailGeneration && selectedDeparture?.id == serviceID && !Task.isCancelled
    }

    private static func map(_ error: any Error) -> AppIssue {
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost].contains(urlError.code) {
            return .offline
        }
        if let apiError = error as? APIErrorEnvelope {
            switch apiError.code {
            case "service_expired", "not_found": return .serviceExpired
            case "rate_limited": return .rateLimited(retryAfter: apiError.retryAfter)
            case "invalid_response": return .invalidResponse
            default: return .upstream
            }
        }
        return .upstream
    }
}
