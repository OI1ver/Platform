import SwiftUI

struct OnboardingView: View {
    @ObservedObject var preferences: PreferencesStore
    let catalog: StationCatalog

    @State private var isChoosingStation = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "train.side.front.car")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Departures at a glance")
                    .font(.title2.weight(.bold))
                Text("Choose your first station to see live platforms, delays and calling points from the menu bar.")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                isChoosingStation = true
            } label: {
                Label("Choose a station", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.canvas)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .keyboardShortcut(.defaultAction)

            Text("Live data provided by National Rail")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
        }
        .padding(28)
        .sheet(isPresented: $isChoosingStation) {
            StationSearchView(catalog: catalog, existing: Set(preferences.favourites)) {
                preferences.add($0)
            }
        }
    }
}
