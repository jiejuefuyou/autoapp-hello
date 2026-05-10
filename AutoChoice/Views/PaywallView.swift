import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .padding(.top, 24)

                    Text(LocalizedStringKey("AutoChoice Premium"))
                        .font(.largeTitle.bold())

                    Text(LocalizedStringKey("One-time purchase. No subscription. Unlock everything forever."))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 14) {
                        feature("infinity",                "Unlimited choices per wheel")
                        feature("paintpalette.fill",       "10+ premium themes")
                        feature("rectangle.stack.fill",    "Unlimited saved lists")
                        feature("clock.arrow.circlepath",  "Decision history")
                        feature("square.and.arrow.up",     "Share result cards")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    purchaseButton
                        .padding(.horizontal)

                    Button(LocalizedStringKey("Restore Purchase")) {
                        Task { await iap.restore() }
                    }
                    .font(.footnote)

                    if let err = iap.lastError {
                        Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal)
                    }

                    VStack(spacing: 4) {
                        Label(LocalizedStringKey("No subscription. No data collected. Ever."), systemImage: "lock.shield.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey("Payment will be charged to your Apple ID. This is a one-time purchase that unlocks all premium features for the lifetime of your Apple ID."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                }
            }
            .onChange(of: iap.isPremium) { _, newValue in
                if newValue { dismiss() }
            }
            .task { await iap.loadProducts() }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if iap.isPremium {
            Label(LocalizedStringKey("Premium unlocked"), systemImage: "checkmark.seal.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.green)
        } else if let product = iap.products.first {
            Button {
                Task { await iap.purchase() }
            } label: {
                HStack {
                    if iap.purchaseInProgress {
                        ProgressView().tint(.white)
                    }
                    if iap.purchaseInProgress {
                        Text(LocalizedStringKey("Processing…")).font(.headline)
                    } else {
                        Text("Unlock for \(product.displayPrice)").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .disabled(iap.purchaseInProgress)
        } else {
            // Apple round-3 2.1(b) fix: never let the spinner show
            // indefinitely. After IAPManager.productsLoadTimeout the
            // state transitions to .empty / .timedOut / .failed and
            // we surface a graceful, user-actionable fallback.
            unavailableFallback
        }
    }

    @ViewBuilder
    private var unavailableFallback: some View {
        switch iap.loadingState {
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text(LocalizedStringKey("Loading products…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        case .loaded, .empty, .timedOut, .failed:
            VStack(spacing: 12) {
                Text(LocalizedStringKey("Products are temporarily unavailable. You can continue using AutoChoice for free, or try again later."))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await iap.loadProducts() }
                } label: {
                    Label(LocalizedStringKey("Try again"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    dismiss()
                } label: {
                    Text(LocalizedStringKey("Continue without subscription"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func feature(_ icon: String, _ key: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 28)
            Text(key)
            Spacer()
        }
    }
}

#Preview {
    PaywallView()
        .environment(IAPManager())
}
