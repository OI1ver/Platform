import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "train.side.front.car")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.accent)
            }
            Text("Platform").font(.title.weight(.bold))
            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text("A free, open-source menu-bar departure board for Great Britain.")
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.secondaryText)
            Divider().overlay(AppTheme.border)
            Text("Live data provided by National Rail through the Darwin Live Departure Boards service.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.secondaryText)
            Link("View National Rail", destination: URL(string: "https://www.nationalrail.co.uk/")!)
        }
        .padding(28)
        .frame(width: 380, height: 350)
        .background(AppTheme.canvas)
        .foregroundStyle(AppTheme.text)
        .preferredColorScheme(.dark)
    }
}
