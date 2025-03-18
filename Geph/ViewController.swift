import NetworkExtension
import StoreKit
import UIKit
import WebKit

class ViewController: UIViewController {

  // MARK: - Properties
  var webView: WKWebView!
  var hasSubscription: Bool?

  // MARK: - Lifecycle Methods
  override func viewDidLoad() {
    super.viewDidLoad()
    setupWebView()
  }

  // MARK: - VPN Configuration
  func getManager() async throws -> NETunnelProviderManager {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    if managers.isEmpty {
      let manager = NETunnelProviderManager()
      manager.localizedDescription = "geph-daemon"
      let proto = NETunnelProviderProtocol()
      // WARNING: This must match the bundle identifier of the app extension containing packet tunnel provider.
      proto.providerBundleIdentifier = "geph.io.daemon"
      proto.serverAddress = "geph"
      manager.protocolConfiguration = proto
      try await manager.loadFromPreferences()
      manager.isEnabled = true
      try await manager.saveToPreferences()
      try await manager.loadFromPreferences()
      return manager
    } else {
      let man = managers[0]
      man.isEnabled = true
      try await man.saveToPreferences()
      return man
    }
  }

  // MARK: - In-App Purchase
  func inapp_purchase() {
    // Implement in-app purchase logic
  }

  func showSubscriptionExistsAlert() {
    // Show alert that subscription already exists
  }

  // MARK: - Blocking Function Helper
  func callBlockingSyncFunc(_ block: @escaping () throws -> String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let result = try block()
          continuation.resume(returning: result)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
