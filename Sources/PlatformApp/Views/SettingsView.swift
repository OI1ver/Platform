import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var updates: UpdateController
    let catalog: StationCatalog
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject var launchAtLogin: LaunchAtLoginController

    @State private var isAddingStation = false

    var body: some View {
        VStack(spacing: 0) {
            settingsNavigation
            Divider().overlay(AppTheme.border)
            selectedPage
        }
        .frame(width: 520, height: 390)
        .background(AppTheme.canvas)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isAddingStation) {
            StationSearchView(catalog: catalog, existing: Set(preferences.favourites)) {
                preferences.add($0)
            }
        }
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }

    private var settingsNavigation: some View {
        HStack(spacing: 14) {
            ForEach(SettingsPage.allCases) { page in
                Button {
                    navigation.selection = page
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: page.symbol)
                            .font(.system(size: 25, weight: .medium))
                        Text(page.title)
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(navigation.selection == page ? Color.accentColor : AppTheme.secondaryText)
                    .frame(width: 92, height: 66)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(navigation.selection == page ? Color.white.opacity(0.09) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(page.title)
                .accessibilityAddTraits(navigation.selection == page ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch navigation.selection {
        case .stations:
            stationsTab
        case .general:
            generalTab
        case .about:
            aboutTab
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
                get: { launchAtLogin.isRequested },
                set: launchAtLogin.setEnabled
            ))

            if launchAtLogin.state == .requiresApproval {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Approval is required in System Settings before Platform can open at login.", systemImage: "exclamationmark.triangle.fill")
                    Button("Open Login Items Settings") {
                        launchAtLogin.openLoginItemSettings()
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.warning)
            } else if launchAtLogin.state == .unavailable {
                Label("Launch at login is available from the packaged Platform application.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }

            if let launchError = launchAtLogin.errorMessage {
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
            platformIcon(size: 74)
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

    @ViewBuilder
    private func platformIcon(size: CGFloat) -> some View {
        if let icon = AppArtwork.appIconImage {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
                .accessibilityLabel("Platform")
        } else {
            Image(systemName: "train.side.front.car")
                .font(.system(size: size * 0.58))
                .foregroundStyle(AppTheme.accent)
        }
    }
}
