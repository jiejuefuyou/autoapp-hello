import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class IAPManager {
    // Must match the IAP product ID configured in App Store Connect.
    // ASC API V1 GET /v1/apps/6765667062/inAppPurchasesV2 confirms:
    //   productID = com.jiejuefuyou.autochoice.premium  (id 6766868984)
    // The Apple Review email mentioning "autochoice_premium_unlock" was a
    // reviewer paraphrase; the only real product ID on the AutoChoice app
    // is com.jiejuefuyou.autochoice.premium.
    // Real 2.1(b) root cause was IAP item not attached to the review
    // submission via reviewSubmissionItems (handled separately via CDP
    // 2-stage flow per memory state_apple_review_iap_completeness_rejection).
    static let premiumProductID = "com.jiejuefuyou.autochoice.premium"

    var isPremium: Bool = false
    var products: [Product] = []
    var purchaseInProgress: Bool = false
    var lastError: String?

    private nonisolated(unsafe) var listenerTask: Task<Void, Never>?

    init() {
        listenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let t) = update else { continue }
                await t.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    deinit {
        listenerTask?.cancel()
    }

    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.premiumProductID])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product = products.first(where: { $0.id == Self.premiumProductID }) else {
            await loadProducts()
            return
        }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                }
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.premiumProductID,
               t.revocationDate == nil {
                entitled = true
            }
        }
        isPremium = entitled
    }
}
