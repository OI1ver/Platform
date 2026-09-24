import Foundation

struct StationCatalog: Sendable {
    let stations: [Station]

    static let bundled: StationCatalog = {
        guard let url = Bundle.module.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stations = try? JSONDecoder().decode([Station].self, from: data)
        else {
            return StationCatalog(stations: [])
        }
        return StationCatalog(stations: stations)
    }()

    func search(_ query: String, limit: Int = 40) -> [Station] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return Array(stations.prefix(limit)) }

        return stations
            .lazy
            .filter {
                $0.crs.localizedCaseInsensitiveContains(term)
                    || $0.name.localizedStandardContains(term)
            }
            .prefix(limit)
            .map { $0 }
    }

    func contains(crs: String) -> Bool {
        stations.contains { $0.crs == crs.uppercased() }
    }
}
