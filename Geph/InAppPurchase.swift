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

func inAppPurchase() {
  NSLog("inAppPurchase!")

  guard let product = product else {
    NSLog("no product...")
    return
  }
  Task {
    do {
      let uid = defaults.value(forKey: "uid") as! Int32
      //            eprint("UID!!!!!!", uid);
      let uuid = encodeInt32ToUUID(uid)

      let result = try await product.purchase(options: [
        .appAccountToken(uuid)
      ])
      switch result {
      case .success(let verification):
        switch verification {
        case .verified(let transaction):
          // Transaction verified successfully
          // pop up wait up to 10 min modal
          eprint("TRANSACTION: ", transaction)
          await transaction.finish()
        case .unverified(let transaction, let verificationError):
          // Transaction verification failed
          print("Transaction verification failed: \(verificationError)")
          await transaction.finish()
        }
      case .userCancelled, .pending:
        break
      @unknown default:
        break
      }
    } catch {
      print("Failed to purchase: \(error)")
    }
  }
}

let productIdentifier = "1_mo_renewing"
var product: Product?

func fetchProduct() {
  Task {
    eprint("GONNNA FETCH PRODUCT")
    do {
      let products = try await Product.products(for: [productIdentifier])
      eprint("FETCHED PRODUCTS for: ", productIdentifier)
      eprint(products)
      if let fetchedProduct = products.first {
        product = fetchedProduct
        eprint("fetched product!", fetchedProduct)
      }
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
