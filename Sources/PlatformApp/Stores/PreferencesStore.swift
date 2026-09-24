import Foundation

enum BoardDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case display
    case extended
    case list

    var id: String { rawValue }

    var label: String {
        switch self {
        case .display: "Display view"
        case .extended: "Extended view"
        case .list: "List view"
        }
    }

    var boardHeight: CGFloat {
        switch self {
        case .display: 150
        case .extended: 315
        case .list: 610
        }
    }
}

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var favourites: [Station] { didSet { persistFavourites() } }
    @Published var activeCRS: String? { didSet { defaults.set(activeCRS, forKey: Keys.activeCRS) } }
    @Published var automaticRefresh: Bool { didSet { defaults.set(automaticRefresh, forKey: Keys.automaticRefresh) } }
    @Published var checkForUpdates: Bool { didSet { defaults.set(checkForUpdates, forKey: Keys.checkForUpdates) } }
    @Published var boardDisplayMode: BoardDisplayMode {
        didSet { defaults.set(boardDisplayMode.rawValue, forKey: Keys.boardDisplayMode) }
    }

    private let defaults: UserDefaults

    var activeStation: Station? {
        favourites.first { $0.crs == activeCRS } ?? favourites.first
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.favourites),
           let decoded = try? JSONDecoder().decode([Station].self, from: data) {
            favourites = decoded
        } else {
            favourites = []
        }
        activeCRS = defaults.string(forKey: Keys.activeCRS)
        automaticRefresh = defaults.object(forKey: Keys.automaticRefresh) as? Bool ?? true
        checkForUpdates = defaults.object(forKey: Keys.checkForUpdates) as? Bool ?? true
        boardDisplayMode = defaults.string(forKey: Keys.boardDisplayMode)
            .flatMap(BoardDisplayMode.init(rawValue:)) ?? .display
    }

    func add(_ station: Station) {
        guard !favourites.contains(station) else {
            activeCRS = station.crs
            return
        }
        favourites.append(station)
        activeCRS = station.crs
    }

    func remove(_ station: Station) {
        favourites.removeAll { $0 == station }
        if activeCRS == station.crs { activeCRS = favourites.first?.crs }
    }

    func move(from index: Int, by offset: Int) {
        let destination = index + offset
        guard favourites.indices.contains(index), favourites.indices.contains(destination) else { return }
        favourites.swapAt(index, destination)
    }

    private func persistFavourites() {
        if let data = try? JSONEncoder().encode(favourites) {
            defaults.set(data, forKey: Keys.favourites)
        }
    }

    private enum Keys {
        static let favourites = "favourite-stations"
        static let activeCRS = "active-station-crs"
        static let automaticRefresh = "automatic-refresh"
        static let checkForUpdates = "check-for-updates"
        static let boardDisplayMode = "board-display-mode"
    }
}
