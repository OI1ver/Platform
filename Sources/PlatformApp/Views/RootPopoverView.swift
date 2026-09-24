import SwiftUI

struct RootPopoverView: View {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var store: BoardStore
    let catalog: StationCatalog

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if preferences.favourites.isEmpty {
                OnboardingView(preferences: preferences, catalog: catalog)
                    .frame(width: 488, height: 610)
                    .fixedSize()
                    .background(AppTheme.canvas)
                    .background(
                        PopoverWindowSizer(
                            contentSize: CGSize(width: 488, height: 610),
                            animateChanges: !reduceMotion
                        )
                    )
            } else if store.selectedDeparture != nil {
                ServiceDetailView(store: store)
                    .frame(width: 488, height: 610)
                    .fixedSize()
                    .background(
                        PopoverWindowSizer(
                            contentSize: CGSize(width: 488, height: 610),
                            animateChanges: !reduceMotion,
                            transparentBackground: true
                        )
                    )
            } else {
                BoardModeContainerView(preferences: preferences, store: store, catalog: catalog)
            }
        }
        .foregroundStyle(AppTheme.text)
        .preferredColorScheme(.dark)
        .onAppear {
            store.appear(station: preferences.activeStation, automaticRefresh: preferences.automaticRefresh)
        }
        .onDisappear {
            store.disappear()
        }
        .onChange(of: preferences.activeCRS) {
            Task { await store.changeStation(to: preferences.activeStation) }
        }
        .onChange(of: preferences.automaticRefresh) {
            store.appear(station: preferences.activeStation, automaticRefresh: preferences.automaticRefresh)
        }
    }

}
