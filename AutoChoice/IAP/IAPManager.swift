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

    /// Hard ceiling for product lookup. Apple Review (round-3, 2.1(b),
    /// iPad Air 11" M3 / iPadOS 26.4.2 sandbox) reported the paywall
    /// "loading indefinitely". Sandbox StoreKit can stall silently;
    /// any wait beyond this and we surface a graceful empty state
    /// instead of an indefinite spinner.
    static let productsLoadTimeout: Duration = .seconds(5)

    enum LoadingState: Equatable {
        case loading
        case loaded
        case empty   // products query returned, but list empty (e.g. sandbox region with no IAP record)
        case timedOut
        case failed
    }

    var isPremium: Bool = false
    var products: [Product] = []
    var purchaseInProgress: Bool = false
    var lastError: String?
    var loadingState: LoadingState = .loading

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
        loadingState = .loading
        lastError = nil
        do {
            let fetched = try await withThrowingTaskGroup(of: [Product].self) { group in
                group.addTask {
                    try await Product.products(for: [Self.premiumProductID])
                }
                group.addTask {
                    try await Task.sleep(for: Self.productsLoadTimeout)
                    throw IAPLoadError.timedOut
                }
                guard let first = try await group.next() else {
                    throw IAPLoadError.timedOut
                }
                group.cancelAll()
                return first
            }
            products = fetched
            loadingState = fetched.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            // Caller-initiated cancel (e.g. view dismissed). Treat as empty
            // rather than failed so we don't surface a misleading error.
            loadingState = .empty
        } catch IAPLoadError.timedOut {
            loadingState = .timedOut
        } catch {
            lastError = error.localizedDescription
            loadingState = .failed
        }
    }

    private enum IAPLoadError: Error {
        case timedOut
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
