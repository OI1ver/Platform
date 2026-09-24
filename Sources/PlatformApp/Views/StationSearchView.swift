import SwiftUI

struct StationSearchView: View {
    let catalog: StationCatalog
    let existing: Set<Station>
    let onSelect: (Station) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Station] {
        catalog.search(query).filter { !existing.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Add a station")
                        .font(.title3.weight(.semibold))
                    Text("Search by station name or three-letter code")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Close station search")
            }
            .padding(18)

            TextField("Search stations", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(AppTheme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .padding(.horizontal, 18)
                .accessibilityLabel("Station search")

            if results.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "No more stations" : "No matching stations",
                    systemImage: "magnifyingglass",
                    description: Text(query.isEmpty ? "Your favourites already include these suggestions." : "Try a station name or CRS code.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(results) { station in
                            Button {
                                onSelect(station)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(station.crs)
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 42)
                                    Text(station.name)
                                        .foregroundStyle(AppTheme.text)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 42)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .accessibilityLabel("Add \(station.name), \(station.crs)")
                        }
                    }
                    .padding(18)
                }
            }
        }
        .frame(width: 420, height: 520)
        .background(AppTheme.canvas)
        .foregroundStyle(AppTheme.text)
        .preferredColorScheme(.dark)
    }
}
