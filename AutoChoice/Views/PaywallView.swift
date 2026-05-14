import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    @State private var showAlert: Bool = false
    @State private var alertTitle: LocalizedStringKey = ""
    @State private var alertMessage: String = ""

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

                    // v1.0.9: reordered by pain-strength (highest friction first)
                    VStack(alignment: .leading, spacing: 14) {
                        feature("infinity",                "No more 8-item limits — add as many as you want")
                        feature("rectangle.stack.fill",    "Unlimited saved lists")
                        feature("clock.arrow.circlepath",  "Full history (was 25)")
                        feature("paintpalette.fill",       "All 12 themes unlocked")
                        feature("square.and.arrow.up",     "Share result cards")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    purchaseStatusBanner
                        .padding(.horizontal)

                    purchaseButton
                        .padding(.horizontal)

                    Button(LocalizedStringKey("Restore Purchase")) {
                        Task { await iap.restore() }
                    }
                    .font(.footnote)
                    .accessibilityHint(Text(LocalizedStringKey("Restores a previous purchase")))

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
            .onChange(of: iap.purchaseState) { _, newState in
                handlePurchaseStateChange(newState)
            }
            .alert(
                Text(alertTitle),
                isPresented: $showAlert
            ) {
                Button(LocalizedStringKey("OK")) {
                    iap.resetPurchaseState()
                }
            } message: {
                Text(alertMessage)
            }
            .task { await iap.loadProducts() }
        }
    }

    /// Apple Review round-4 (2.1(b), 2026-05-11) fix: surface every
    /// purchase outcome as an inline banner directly above the purchase
    /// button so reviewers (and real users) can see exactly what happened.
    /// Combined with the .alert() below, failures are impossible to miss.
    @ViewBuilder
    private var purchaseStatusBanner: some View {
        switch iap.purchaseState {
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label(LocalizedStringKey("Purchase failed"), systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        case .cancelled:
            Label(LocalizedStringKey("Purchase canceled."), systemImage: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        case .pending:
            VStack(spacing: 6) {
                Label(LocalizedStringKey("Purchase pending"), systemImage: "clock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(LocalizedStringKey("Purchase pending. We'll complete it shortly."))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(12)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        case .idle, .purchasing, .success:
            EmptyView()
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
            VStack(spacing: 8) {
                Button {
                    Task { await iap.purchase() }
                } label: {
                    HStack {
                        if iap.purchaseInProgress {
                            ProgressView().tint(.white)
                        }
                        if iap.purchaseInProgress {
                            Text(LocalizedStringKey("Processing…")).font(.headline)
                        } else if case .failed = iap.purchaseState {
                            // After a failure, the primary CTA reads "Try again"
                            // so reviewers immediately see the retry affordance.
                            Text(LocalizedStringKey("Try again")).font(.headline)
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
                .accessibilityLabel(Text(
                    iap.purchaseInProgress
                        ? String(localized: "Processing…")
                        : String(format: String(localized: "Purchase AutoChoice Premium for %@"), product.displayPrice)
                ))
            }
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

    private func handlePurchaseStateChange(_ state: IAPManager.PurchaseState) {
        switch state {
        case .failed(let message):
            alertTitle = LocalizedStringKey("Purchase failed")
            alertMessage = message
            showAlert = true
        case .pending:
            alertTitle = LocalizedStringKey("Purchase pending")
            alertMessage = String(localized: "Purchase pending. We'll complete it shortly.")
            showAlert = true
        case .cancelled, .idle, .purchasing, .success:
            // Success path dismisses automatically via isPremium onChange.
            // Cancelled is shown inline (no modal alert needed — that would
            // re-prompt the user who just chose to cancel).
            break
        }
    }
}

#Preview {
    PaywallView()
        .environment(IAPManager())
}
