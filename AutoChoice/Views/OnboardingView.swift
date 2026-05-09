import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasSeenOnboarding: Bool
    @State private var page = 0

    private let pages: [Page] = [
        Page(icon: "list.bullet.rectangle", titleKey: "Stop arguing", subtitleKey: "Type the options you can't decide between."),
        Page(icon: "dial.high", titleKey: "Spin the wheel", subtitleKey: "One tap. Chance picks an answer for you."),
        Page(icon: "lock.shield", titleKey: "Stays on your phone", subtitleKey: "No account, no network, no data collection. Ever.")
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                    pageView(p).tag(idx)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page == pages.count - 1 ? LocalizedStringKey("Get started") : LocalizedStringKey("Next")) {
                if page == pages.count - 1 {
                    hasSeenOnboarding = true
                    dismiss()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
            .padding()
        }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: p.icon)
                .font(.system(size: 88))
                .foregroundStyle(.tint)
            Text(p.titleKey)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(p.subtitleKey)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    struct Page {
        let icon: String
        let titleKey: LocalizedStringKey
        let subtitleKey: LocalizedStringKey
    }
}
