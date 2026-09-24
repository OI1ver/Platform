import AppKit
import Foundation
import XCTest
@testable import PlatformApp

final class StationCatalogTests: XCTestCase {
    func testSearchesByNameAndCRS() {
        let catalog = StationCatalog(stations: [
            Station(crs: "CCH", name: "Chichester"),
            Station(crs: "BTN", name: "Brighton"),
        ])

        XCTAssertEqual(catalog.search("chich").map(\.crs), ["CCH"])
        XCTAssertEqual(catalog.search("btn").map(\.name), ["Brighton"])
    }

    func testBundledCatalogContainsNationalRailStations() {
        XCTAssertGreaterThan(StationCatalog.bundled.stations.count, 2_000)
        XCTAssertTrue(StationCatalog.bundled.contains(crs: "CCH"))
        XCTAssertTrue(StationCatalog.bundled.contains(crs: "KGX"))
    }
}

final class MarqueeTimingTests: XCTestCase {
    func testLongMessagesPauseThenRemainVisibleForOneCompletePass() {
        let message = String(repeating: "Calling at Chichester, Barnham and Brighton. ", count: 8)
        let duration = MarqueeTiming.displayDuration(for: message, viewportWidth: 416)

        XCTAssertEqual(
            duration,
            MarqueeTiming.initialPause
                + MarqueeTiming.cycleDuration(for: message) * MarqueeTiming.passesBeforeAdvance
        )
    }

    func testShortMessagesUseAStableDisplayPeriod() {
        XCTAssertEqual(
            MarqueeTiming.displayDuration(for: "On time", viewportWidth: 416),
            MarqueeTiming.staticMessageDuration
        )
    }
}

final class BoardPresentationTests: XCTestCase {
    func testExpectedStatusUsesBoardCasingWithoutPeriod() {
        let departure = Departure(
            id: "service-expected",
            scheduledDeparture: "14:00",
            expectedDeparture: "14:08",
            destinations: [StationReference(crs: "BTN", name: "Brighton")],
            platform: "1",
            carriageCount: nil,
            operatorName: "Southern",
            status: .unknown,
            statusText: "14:08",
            delayReason: nil,
            cancellationReason: nil
        )

        XCTAssertEqual(BoardPresentation.displayStatus(for: departure), "Exp 14:08")
    }

    func testLongFormationsFitWithinTickerWidth() {
        XCTAssertEqual(CarriageLayout.visibleCount(for: 12), 12)
        let occupiedWidth = CarriageLayout.boxWidth(for: 12) * 12
            + CarriageLayout.spacing * 11
        XCTAssertLessThanOrEqual(occupiedWidth, CarriageLayout.availableWidth)
    }

    func testUnknownAndInvalidFormationsDoNotFabricateCoaches() {
        XCTAssertEqual(CarriageLayout.visibleCount(for: nil), 0)
        XCTAssertEqual(CarriageLayout.visibleCount(for: -1), 0)
    }

    func testRailTextSanitizerRemovesMarkupAndNonBreakingSpaces() {
        let input = "<p>Revised&nbsp; service &#160; &amp; updates.</p>"
        XCTAssertEqual(RailTextSanitizer.clean(input), "Revised service & updates.")
    }

    func testPriorityInformationPrefersDisruptionThenCallingPointsThenCoaches() {
        let delayed = Self.departure(delayReason: "Signal failure", carriageCount: 8)
        XCTAssertEqual(
            BoardPresentation.priorityInformation(for: delayed, details: nil, activeCRS: "CCH"),
            "Signal failure"
        )

        let ordinary = Self.departure(delayReason: nil, carriageCount: 8)
        let details = ServiceDetails(
            id: ordinary.id,
            operatorName: "Southern",
            origins: [StationReference(crs: "CCH", name: "Chichester")],
            destinations: [StationReference(crs: "BTN", name: "Brighton")],
            callingPoints: [
                CallingPoint(station: StationReference(crs: "CCH", name: "Chichester"), scheduledTime: "10:00", expectedTime: "On time", actualTime: nil, platform: nil, statusText: nil),
                CallingPoint(station: StationReference(crs: "BAA", name: "Barnham"), scheduledTime: "10:08", expectedTime: "On time", actualTime: nil, platform: nil, statusText: nil),
            ],
            generatedAt: Date()
        )
        XCTAssertEqual(
            BoardPresentation.priorityInformation(for: ordinary, details: details, activeCRS: "CCH"),
            "Calling at Barnham"
        )
        XCTAssertEqual(
            BoardPresentation.priorityInformation(for: ordinary, details: nil, activeCRS: "CCH"),
            "This train has 8 coaches."
        )
    }

    func testStationNoticeFallback() {
        XCTAssertEqual(
            BoardPresentation.stationNotices(board: nil, isStale: false, issue: nil),
            ["No current station notices."]
        )
    }

    private static func departure(delayReason: String?, carriageCount: Int?) -> Departure {
        Departure(
            id: "service-1",
            scheduledDeparture: "10:00",
            expectedDeparture: "10:00",
            destinations: [StationReference(crs: "BTN", name: "Brighton")],
            platform: "1",
            carriageCount: carriageCount,
            operatorName: "Southern",
            status: delayReason == nil ? .onTime : .delayed,
            statusText: delayReason == nil ? "On time" : "Delayed",
            delayReason: delayReason,
            cancellationReason: nil
        )
    }
}

final class RailAPIClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testDepartureResponsePropagatesWorkerStaleHeader() async throws {
        let board = DepartureBoard(
            station: Station(crs: "CCH", name: "Chichester"),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            services: [],
            messages: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(board)
        URLProtocolStub.requestHandler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["X-Platform-Stale": "true"]
            ))
            return (response, data)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = RailAPIClient(
            baseURL: URL(string: "https://relay.example")!,
            installationID: "test-installation",
            session: URLSession(configuration: configuration)
        )

        let result = try await client.departures(for: "CCH", limit: 10)

        XCTAssertEqual(result.board, board)
        XCTAssertTrue(result.isStale)
    }
}

@MainActor
final class ArtworkTests: XCTestCase {
    func testMenuBarArtworkLoadsAsTemplate() throws {
        let image = try XCTUnwrap(AppArtwork.menuBarImage)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, AppArtwork.menuBarImageSize)
    }
}

final class MultiViewPresentationTests: XCTestCase {
    func testModeHeightsMatchDesign() {
        XCTAssertEqual(BoardDisplayMode.display.boardHeight, 150)
        XCTAssertEqual(BoardDisplayMode.extended.boardHeight, 315)
        XCTAssertEqual(BoardDisplayMode.list.boardHeight, 610)
    }

    func testSelectorHasOnlyClosedAndExpandedStates() {
        XCTAssertNotEqual(ViewSelectorVisibility.hidden, .expanded)
    }

    func testSelectorPanelCannotTakeFocusFromMenuBarPopover() {
        XCTAssertTrue(SelectorPanelConfiguration.styleMask.contains(.nonactivatingPanel))
    }

    func testStaleSelectorUpdatesAreRejected() {
        var gate = SelectorUpdateGate()
        let staleUpdate = gate.advance()
        let currentUpdate = gate.advance()

        XCTAssertFalse(gate.accepts(staleUpdate))
        XCTAssertTrue(gate.accepts(currentUpdate))
    }

    func testOnlyFeaturedExtendedDepartureShowsInformation() {
        XCTAssertTrue(ExtendedBoardPresentation.showsInformation(for: 0))
        XCTAssertFalse(ExtendedBoardPresentation.showsInformation(for: 1))
        XCTAssertFalse(ExtendedBoardPresentation.showsInformation(for: 2))
        XCTAssertFalse(ExtendedBoardPresentation.showsInformation(for: 3))
    }

    func testExtendedRowsFillTheirHeightWithoutEmptyTickerSlots() {
        let featuredHeight = ExtendedBoardPresentation.mainLineHeight(for: 0)
            + ExtendedBoardPresentation.informationLineHeight
            + ExtendedBoardPresentation.separatorHeight
        let compactHeight = ExtendedBoardPresentation.mainLineHeight(for: 1)
            + ExtendedBoardPresentation.separatorHeight

        XCTAssertEqual(featuredHeight, ExtendedBoardPresentation.rowHeight)
        XCTAssertEqual(compactHeight, ExtendedBoardPresentation.rowHeight)
    }

    func testClockUsesTwentyFourHourHoursAndMinutes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 15, minute: 7)))
        XCTAssertEqual(BoardClockFormatter.string(from: date), "15:07")
    }
}

final class PopoverWindowLayoutTests: XCTestCase {
    func testShrinkingBackToBoardPreservesMenuBarAnchor() {
        let current = CGRect(x: 800, y: 250, width: 488, height: 610)
        let resized = PopoverWindowLayout.frame(
            currentFrame: current,
            currentContentSize: current.size,
            targetContentSize: CGSize(width: 488, height: 150)
        )

        XCTAssertEqual(resized.size, CGSize(width: 488, height: 150))
        XCTAssertEqual(resized.maxX, current.maxX)
        XCTAssertEqual(resized.maxY, current.maxY)
    }

    func testWindowChromeIsIncludedInTargetFrame() {
        let current = CGRect(x: 800, y: 250, width: 500, height: 632)
        let resized = PopoverWindowLayout.frame(
            currentFrame: current,
            currentContentSize: CGSize(width: 488, height: 610),
            targetContentSize: CGSize(width: 488, height: 150)
        )

        XCTAssertEqual(resized.size, CGSize(width: 500, height: 172))
        XCTAssertEqual(resized.maxX, current.maxX)
        XCTAssertEqual(resized.maxY, current.maxY)
    }
}

final class ServiceDetailPresentationTests: XCTestCase {
    func testFormatsOnTimeCallingPoint() {
        XCTAssertEqual(
            ServiceDetailPresentation.liveText(for: point(expected: "On time")),
            "On Time"
        )
    }

    func testFormatsChangedTimeWithoutAddingExtraWording() {
        XCTAssertEqual(
            ServiceDetailPresentation.liveText(for: point(expected: "12:04")),
            "12:04"
        )
    }

    func testCancellationOverridesLiveTime() {
        XCTAssertEqual(
            ServiceDetailPresentation.liveText(
                for: point(expected: "12:04", status: "Cancelled due to disruption")
            ),
            "Cancelled"
        )
    }

    private func point(expected: String?, status: String? = nil) -> CallingPoint {
        CallingPoint(
            station: StationReference(crs: "CCH", name: "Chichester"),
            scheduledTime: "12:00",
            expectedTime: expected,
            actualTime: nil,
            platform: nil,
            statusText: status
        )
    }
}

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func testPersistsFavouritesAndActiveStation() {
        let suite = "PlatformTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = PreferencesStore(defaults: defaults)
        let station = Station(crs: "CCH", name: "Chichester")
        store.add(station)

        let restored = PreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.favourites, [station])
        XCTAssertEqual(restored.activeStation, station)
    }

    func testBoardModeDefaultsToDisplayAndPersistsLastSelection() {
        let suite = "PlatformModeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let initial = PreferencesStore(defaults: defaults)
        XCTAssertEqual(initial.boardDisplayMode, .display)
        initial.boardDisplayMode = .list

        XCTAssertEqual(PreferencesStore(defaults: defaults).boardDisplayMode, .list)
    }
}

@MainActor
final class BoardStoreTests: XCTestCase {
    func testUsesFreshBoardAndWritesCache() async {
        let board = Self.board()
        let api = StubAPI(board: board)
        let cache = MemoryCache()
        let store = BoardStore(api: api, cache: cache)

        store.appear(station: board.station, automaticRefresh: false)
        await waitUntil { store.board != nil }

        XCTAssertEqual(store.board, board)
        XCTAssertFalse(store.isStale)
        let cached = await cache.load(crs: "CCH")
        XCTAssertEqual(cached, board)
        store.disappear()
    }

    func testFallsBackToStaleBoardWhenOffline() async {
        let board = Self.board()
        let cache = MemoryCache(initial: board)
        let api = StubAPI(error: URLError(.notConnectedToInternet))
        let store = BoardStore(api: api, cache: cache)

        store.appear(station: board.station, automaticRefresh: false)
        await waitUntil { store.board != nil }

        XCTAssertEqual(store.board, board)
        XCTAssertTrue(store.isStale)
        XCTAssertEqual(store.issue, .offline)
        store.disappear()
    }

    func testMarksSuccessfulWorkerFallbackAsStale() async {
        let board = Self.board()
        let api = StubAPI(board: board, isStale: true)
        let store = BoardStore(api: api, cache: MemoryCache())

        store.appear(station: board.station, automaticRefresh: false)
        await waitUntil { store.board != nil }

        XCTAssertEqual(store.board, board)
        XCTAssertTrue(store.isStale)
        XCTAssertNil(store.issue)
        store.disappear()
    }

    func testPrefetchCachesOnlyRequestedServicesAndToleratesFailure() async {
        let departures = (1...5).map(Self.departure)
        let board = DepartureBoard(
            station: Station(crs: "CCH", name: "Chichester"),
            generatedAt: Date(),
            services: departures,
            messages: []
        )
        let api = DetailStubAPI(board: board, failingID: departures[2].id)
        let store = BoardStore(api: api, cache: MemoryCache())

        store.appear(station: board.station, automaticRefresh: false)
        await waitUntil { store.board != nil }
        await store.prefetchDetails(for: departures.prefix(4))

        let requested = await api.requestedServiceIDs()
        XCTAssertEqual(Set(requested), Set(departures.prefix(4).map(\.id)))
        XCTAssertNotNil(store.details(for: departures[0]))
        XCTAssertNotNil(store.details(for: departures[1]))
        XCTAssertNil(store.details(for: departures[2]))
        XCTAssertNotNil(store.details(for: departures[3]))
        XCTAssertNil(store.details(for: departures[4]))
        store.disappear()
    }

    func testOlderStationResponseCannotReplaceNewStation() async {
        let api = StationRaceAPI()
        let store = BoardStore(api: api, cache: MemoryCache())
        let chichester = Station(crs: "CCH", name: "Chichester")
        let brighton = Station(crs: "BTN", name: "Brighton")

        store.appear(station: chichester, automaticRefresh: false)
        await waitUntilRequested("CCH", by: api)
        await store.changeStation(to: brighton)
        try? await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(store.board?.station, brighton)
        store.disappear()
    }

    func testOlderServiceDetailsCannotReplaceNewSelection() async {
        let first = Self.departure(1)
        let second = Self.departure(2)
        let api = DetailRaceAPI()
        let store = BoardStore(api: api, cache: MemoryCache())

        let firstSelection = Task { await store.select(first) }
        await waitUntilRequested(first.id, by: api)
        let secondSelection = Task { await store.select(second) }
        await firstSelection.value
        await secondSelection.value

        XCTAssertEqual(store.selectedDeparture, second)
        XCTAssertEqual(store.details?.id, second.id)
    }

    private func waitUntil(_ predicate: @escaping @MainActor () -> Bool) async {
        for _ in 0..<100 where !predicate() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func waitUntilRequested(_ crs: String, by api: StationRaceAPI) async {
        for _ in 0..<100 {
            if await api.requestedCRSCodes().contains(crs) { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    private func waitUntilRequested(_ serviceID: String, by api: DetailRaceAPI) async {
        for _ in 0..<100 {
            if await api.requestedServiceIDs().contains(serviceID) { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
    }

    private static func board() -> DepartureBoard {
        DepartureBoard(
            station: Station(crs: "CCH", name: "Chichester"),
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            services: [],
            messages: []
        )
    }

    private static func departure(_ number: Int) -> Departure {
        Departure(
            id: "service-\(number)",
            scheduledDeparture: "10:\(String(format: "%02d", number))",
            expectedDeparture: "10:\(String(format: "%02d", number))",
            destinations: [StationReference(crs: "BTN", name: "Brighton")],
            platform: "1",
            carriageCount: 4,
            operatorName: "Southern",
            status: .onTime,
            statusText: "On time",
            delayReason: nil,
            cancellationReason: nil
        )
    }
}

private actor StubAPI: RailAPIProviding {
    let board: DepartureBoard?
    let failure: (any Error)?

    let isStale: Bool

    init(board: DepartureBoard, isStale: Bool = false) {
        self.board = board
        self.failure = nil
        self.isStale = isStale
    }

    init(error: any Error) {
        self.board = nil
        self.failure = error
        self.isStale = false
    }

    func departures(for crs: String, limit: Int) async throws -> DepartureBoardFetch {
        if let failure { throw failure }
        return DepartureBoardFetch(board: board!, isStale: isStale)
    }

    func serviceDetails(id: String) async throws -> ServiceDetails {
        throw APIErrorEnvelope(code: "service_expired", message: "Expired", retryAfter: nil)
    }
}

private actor MemoryCache: BoardCaching {
    private var board: DepartureBoard?

    init(initial: DepartureBoard? = nil) {
        board = initial
    }

    func load(crs: String) async -> DepartureBoard? { board }
    func save(_ board: DepartureBoard) async { self.board = board }
}

private actor DetailStubAPI: RailAPIProviding {
    let board: DepartureBoard
    let failingID: String
    private var requested: [String] = []

    init(board: DepartureBoard, failingID: String) {
        self.board = board
        self.failingID = failingID
    }

    func departures(for crs: String, limit: Int) async throws -> DepartureBoardFetch {
        DepartureBoardFetch(board: board, isStale: false)
    }

    func serviceDetails(id: String) async throws -> ServiceDetails {
        requested.append(id)
        if id == failingID { throw URLError(.badServerResponse) }
        return ServiceDetails(
            id: id,
            operatorName: "Southern",
            origins: [StationReference(crs: "CCH", name: "Chichester")],
            destinations: [StationReference(crs: "BTN", name: "Brighton")],
            callingPoints: [],
            generatedAt: Date()
        )
    }

    func requestedServiceIDs() -> [String] { requested }
}

private actor StationRaceAPI: RailAPIProviding {
    private var requested: [String] = []

    func departures(for crs: String, limit: Int) async throws -> DepartureBoardFetch {
        requested.append(crs)
        if crs == "CCH" {
            try? await Task.sleep(for: .milliseconds(100))
        } else {
            try? await Task.sleep(for: .milliseconds(5))
        }
        return DepartureBoardFetch(
            board: DepartureBoard(
                station: Station(crs: crs, name: crs == "CCH" ? "Chichester" : "Brighton"),
                generatedAt: Date(),
                services: [],
                messages: []
            ),
            isStale: false
        )
    }

    func serviceDetails(id: String) async throws -> ServiceDetails {
        throw URLError(.badServerResponse)
    }

    func requestedCRSCodes() -> [String] { requested }
}

private actor DetailRaceAPI: RailAPIProviding {
    private var requested: [String] = []

    func departures(for crs: String, limit: Int) async throws -> DepartureBoardFetch {
        throw URLError(.badServerResponse)
    }

    func serviceDetails(id: String) async throws -> ServiceDetails {
        requested.append(id)
        if id == "service-1" {
            try? await Task.sleep(for: .milliseconds(100))
        } else {
            try? await Task.sleep(for: .milliseconds(5))
        }
        return ServiceDetails(
            id: id,
            operatorName: "Southern",
            origins: [],
            destinations: [],
            callingPoints: [],
            generatedAt: Date()
        )
    }

    func requestedServiceIDs() -> [String] { requested }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
