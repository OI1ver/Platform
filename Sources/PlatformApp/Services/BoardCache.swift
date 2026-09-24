import Foundation

protocol BoardCaching: Sendable {
    func load(crs: String) async -> DepartureBoard?
    func save(_ board: DepartureBoard) async
}
actor FileBoardCache: BoardCaching {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.directory = support.appending(path: "Platform/Boards", directoryHint: .isDirectory)
        }
    }

    func load(crs: String) async -> DepartureBoard? {
        let url = directory.appending(path: "\(crs.uppercased()).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? RailAPIClient.decoder.decode(DepartureBoard.self, from: data)
    }

    func save(_ board: DepartureBoard) async {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(board)
            try data.write(to: directory.appending(path: "\(board.station.crs).json"), options: .atomic)
        } catch {
            // A cache failure must never hide fresh live data.
        }
    }
}
