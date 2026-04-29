import SwiftUI

struct ShareCardView: View {
    let result: String
    let listName: String
    let palette: [Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Text("AutoChoice picked")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
                Text(result)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .lineLimit(3)
                    .minimumScaleFactor(0.4)
                Text("from \"\(listName)\"")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("autochoice.app")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 12)
            }
            .padding()
        }
        .frame(width: 600, height: 600)
    }
}

@MainActor
enum ShareCardRenderer {
    static func render(result: String, listName: String, palette: [Color]) -> Image? {
        let view = ShareCardView(result: result, listName: listName, palette: palette)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
