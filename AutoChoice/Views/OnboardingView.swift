import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasSeenOnboarding: Bool
    @State private var page = 0

    private let pages: [Page] = [
        Page(icon: "list.bullet.rectangle", title: "Stop arguing", subtitle: "Type the options you can't decide between."),
        Page(icon: "dial.high", title: "Spin the wheel", subtitle: "One tap. Chance picks an answer for you."),
        Page(icon: "lock.shield", title: "Stays on your phone", subtitle: "No account, no network, no data collection. Ever.")
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

            Button(page == pages.count - 1 ? "Get started" : "Next") {
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
            Text(p.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(p.subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    struct Page {
        let icon: String
        let title: String
        let subtitle: String
    }
}
