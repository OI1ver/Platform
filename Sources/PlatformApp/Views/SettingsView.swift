import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var updates: UpdateController
    let catalog: StationCatalog

    @State private var isAddingStation = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        TabView {
            stationsTab
                .tabItem { Label("Stations", systemImage: "tram.fill") }
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 390)
        .padding(12)
        .background(AppTheme.canvas)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isAddingStation) {
            StationSearchView(catalog: catalog, existing: Set(preferences.favourites)) {
                preferences.add($0)
            }
        }
    }

    private var stationsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Favourite stations").font(.headline)
                    Text("The first station becomes the default when the active station is removed.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button("Add", systemImage: "plus") { isAddingStation = true }
            }

            List {
                ForEach(Array(preferences.favourites.enumerated()), id: \.element.id) { index, station in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(station.name)
                            Text(station.crs)
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        Spacer()
                        if station.crs == preferences.activeStation?.crs {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        Button("Move up", systemImage: "chevron.up") {
                            preferences.move(from: index, by: -1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == 0)
                        Button("Move down", systemImage: "chevron.down") {
                            preferences.move(from: index, by: 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(index == preferences.favourites.count - 1)
                        Button("Remove", systemImage: "trash") {
                            preferences.remove(station)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(preferences.favourites.count == 1)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .padding(16)
    }

    private var generalTab: some View {
        Form {
            Toggle("Refresh every 60 seconds while the board is open", isOn: $preferences.automaticRefresh)
            Toggle("Check GitHub releases for updates", isOn: $preferences.checkForUpdates)
                .onChange(of: preferences.checkForUpdates) {
                    updates.start(automaticallyChecks: preferences.checkForUpdates)
                }
            Button("Check for Updates…") { updates.checkForUpdates() }
                .disabled(!updates.isConfigured)
            Toggle("Open Platform when I log in", isOn: Binding(
                get: { launchAtLogin },
                set: setLaunchAtLogin
            ))

            if let launchError {
                Label(launchError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }

            LabeledContent("Refresh behavior") {
                Text("Only while open")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            LabeledContent("Local data") {
                Text("Favourites and latest boards")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            if !updates.isConfigured {
                Text("Update checks become available after the GitHub appcast URL and Sparkle public key are set for the repository.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "train.side.front.car")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
            Text("Platform").font(.title2.weight(.bold))
            Text("Open-source live UK train departures in your menu bar.")
                .foregroundStyle(AppTheme.secondaryText)
            Text("Live data provided by National Rail through Darwin.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Link("National Rail", destination: URL(string: "https://www.nationalrail.co.uk/")!)
            Text("MIT License · Working title and identity")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = "Launch at login is available from the packaged app."
        }
    }
}
