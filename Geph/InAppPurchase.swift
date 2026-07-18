import Foundation
import StoreKit

var hasSubscription: Bool?
func fetchHasSubscription() {
	Task {
		guard let verificationResult = await Transaction.latest(for: productIdentifier) else {
			// The user hasn't purchased this product.
			hasSubscription = false
			return
		}
		switch verificationResult {
		case .verified(let transaction):
			// Check the expiration date to determine if the subscription is still active.
			if let expiryDate = transaction.expirationDate, Date() < expiryDate {
				// The current date is before the expiration date, so the subscription is active.
				hasSubscription = true
			} else {
				// The subscription has expired or there's no expiration date available.
				hasSubscription = false
			}
			
		case .unverified(_, _):
			// Unverified transactions are treated as if the user does not have an active subscription.
			// You might want to handle this differently based on your business model.
			hasSubscription = false
		}
	}
}

func inAppPurchase(_ geph_uid: Int) async throws {
    let product = try await getProduct()
    do {
        let uuid = encodeInt32ToUUID(Int32(geph_uid))
//      eprint("UUID = ", uuid)
        let result = try await product.purchase(options: [
            .appAccountToken(uuid)
        ])
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                
            case .unverified(let transaction, let verificationError): // failed
                eprint("Transaction verification failed: ", verificationError)
                throw verificationError
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    } catch {
        eprint("Failed to purchase: ", error);
        throw error
    }
}

let productIdentifier = "1_mo_renewing"
var product: Product?

struct IosPlusPrice: Encodable {
	let localized_price: String
	let period: String
}

func getProduct() async throws -> Product {
	if let product = product {
		return product
	}
	for attempt in 1...3 {
		let products = try await Product.products(for: [productIdentifier])
		if let fetchedProduct = products.first(where: { $0.id == productIdentifier }) {
			product = fetchedProduct
			return fetchedProduct
		}
		if attempt < 3 {
			try await Task.sleep(for: .milliseconds(500 * attempt))
		}
	}
	throw await missingProductError()
}

// "Missing Product" means the App Store answered but offered no products, which is a
// per-user condition (wrong storefront, sideloaded/re-signed app, no receipt). Embed the
// context in the error text so a user's screenshot alone identifies the cause.
func missingProductError() async -> String {
	let storefront = await Storefront.current?.countryCode ?? "no storefront"
	let receipt: String
	if let receiptURL = Bundle.main.appStoreReceiptURL {
		if FileManager.default.fileExists(atPath: receiptURL.path) {
			receipt = receiptURL.lastPathComponent
		} else {
			receipt = "no receipt file"
		}
	} else {
		receipt = "no receipt URL"
	}
	let bundleId = Bundle.main.bundleIdentifier ?? "no bundle id"
	return
		"Missing Product [\(storefront) / \(receipt) / \(bundleId) / canPay: \(AppStore.canMakePayments)]"
}

func fetchIosPlusPrice() async throws -> IosPlusPrice {
	let product = try await getProduct()
	return IosPlusPrice(localized_price: product.displayPrice, period: "month")
}

func fetchProduct() {
	Task {
		do {
			let fetchedProduct = try await getProduct()
			eprint("Fetched product!", fetchedProduct)
		} catch {
			eprint("Failed to fetch the product: ", error)
		}
	}
}

func encodeInt32ToUUID(_ value: Int32) -> UUID {
	var bytes = [UInt8](repeating: 0, count: 16)
	// Place the Int32 value into the first 4 bytes of the UUID
	withUnsafeBytes(of: value.bigEndian) { buffer in
		for (index, byte) in buffer.enumerated() {
			bytes[index] = byte
		}
	}
	return UUID(
		uuid: (
			bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8],
			bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
		))
}

func decodeUUIDToInt32(_ uuid: UUID) -> Int32 {
	let bytes = withUnsafePointer(to: uuid.uuid) { ptr -> [UInt8] in
		let ptr = ptr.withMemoryRebound(to: UInt8.self, capacity: 16) { $0 }
		return [UInt8](UnsafeBufferPointer(start: ptr, count: 16))
	}
	// Extract the first 4 bytes to reconstruct the Int32 value
	return bytes[0...3].withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
}
